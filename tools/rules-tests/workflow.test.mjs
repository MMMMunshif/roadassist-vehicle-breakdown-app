import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, writeBatch, serverTimestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-roadassist', firestore: {host: '127.0.0.1', port: Number(process.env.FIRESTORE_TEST_PORT ?? 8089),
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();
    await setDoc(doc(db,'users/driver'),{role:'driver'});
    await setDoc(doc(db,'users/other'),{role:'driver'});
    await setDoc(doc(db,'users/provider'),{role:'provider'});
    await setDoc(doc(db,'providerDirectory/provider'),{online:true,displayName:'Mechanic'});
    for (const [id,driverId] of [['r1','driver'],['r2','other']]) {
      await setDoc(doc(db,`requests/${id}`),{driverId, providerId:null, status:'searching', workflowVersion:2,
        preferredProviderId:'', rejectedBy:[], estimatedCost:0,serviceFee:0,dispatchFee:0});
      await setDoc(doc(db,`requests/${id}/quotes/provider`),offer());
    }
  });
});
function offer() { return {providerId:'provider',providerName:'Mechanic',providerPhone:'',quoteType:'direct',
  serviceFee:1000,travelFee:500,extraFee:0,total:1500,notes:'Tyre repair only',providerDistanceKm:3,createdAt:serverTimestamp()}; }
function approval(db,id,quoteType = 'direct') {
  const batch = writeBatch(db);
  batch.update(doc(db,`requests/${id}`),{providerId:'provider',providerName:'Mechanic',providerPhone:'',status:'accepted',
    selectedQuoteId:'provider',approvedQuoteType:quoteType,serviceFee:1000,dispatchFee:500,extraFee:0,estimatedCost:1500,quoteNotes:'Tyre repair only',
    providerDistanceKm:3,quoteApprovedAt:serverTimestamp(),acceptedAt:serverTimestamp(),updatedAt:serverTimestamp()});
  batch.update(doc(db,'providerDirectory/provider'),{activeRequestId:id});
  return batch.commit();
}
test('driver vehicle records are owner-only', async () => {
  const db = env.authenticatedContext('driver').firestore();
  await assertSucceeds(setDoc(doc(db,'users/driver/vehicles/v1'),{make:'Toyota',model:'Aqua',year:2017,
    vehicleType:'Sedan / Hatchback',registration:'CAB-1234',fuelType:'Hybrid',transmission:'Automatic',archived:false,
    createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'users/driver/vehicles/v1')));
});
test('provider can submit an itemized offer but cannot assign a new-flow job', async () => {
  const db = env.authenticatedContext('provider').firestore();
  await assertSucceeds(setDoc(doc(db,'requests/r1/quotes/provider'),offer()));
  await assertFails(updateDoc(doc(db,'requests/r1'),{providerId:'provider',status:'accepted'}));
  await assertFails(setDoc(doc(db,'requests/r1/quotes/provider'),{...offer(),total:1}));
});
test('quote approval atomically reserves a provider and prevents a competing selection', async () => {
  await assertSucceeds(approval(env.authenticatedContext('driver').firestore(),'r1'));
  await assertFails(approval(env.authenticatedContext('other').firestore(),'r2'));
  await assertFails(updateDoc(doc(env.authenticatedContext('provider').firestore(),'requests/r1/quotes/provider'),{total:9999}));
});
test('driver cannot approve an offer without reserving its provider', async () => {
  const db = env.authenticatedContext('driver').firestore();
  await assertFails(updateDoc(doc(db,'requests/r1'),{providerId:'provider',status:'accepted',selectedQuoteId:'provider',
    serviceFee:1000,dispatchFee:500,extraFee:0,estimatedCost:1500,quoteApprovedAt:serverTimestamp()}));
});
test('driver cancellation releases the selected provider', async () => {
  const db = env.authenticatedContext('driver').firestore();
  await approval(db,'r1');
  const batch = writeBatch(db);
  batch.update(doc(db,'requests/r1'),{status:'cancelled',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()});
  batch.update(doc(db,'providerDirectory/provider'),{activeRequestId:null});
  await assertSucceeds(batch.commit());
});
test('provider cannot silently increase an approved final charge', async () => {
  await approval(env.authenticatedContext('driver').firestore(),'r1');
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{status:'arrived'}));
  await assertFails(updateDoc(doc(env.authenticatedContext('provider').firestore(),'requests/r1'),{status:'completed',finalCost:2000,completedAt:serverTimestamp()}));
});
test('approved direct-service job progresses and releases its provider', async () => {
  await approval(env.authenticatedContext('driver').firestore(),'r1');
  const db = env.authenticatedContext('provider').firestore();
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{providerMessagesSeenAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{providerLatitude:6.9,providerLongitude:79.9,providerLocationUpdatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{serviceNotes:'Tyre repair',servicePhotoData:[],documentationUpdatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{status:'en_route',en_routeAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{status:'arrived',arrivedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  const batch = writeBatch(db);
  batch.update(doc(db,'requests/r1'),{status:'completed',finalCost:1500,completedAt:serverTimestamp(),updatedAt:serverTimestamp()});
  batch.update(doc(db,'providerDirectory/provider'),{activeRequestId:null});
  await assertSucceeds(batch.commit());
});
test('inspection-only job requires repair approval and revisions are immutable', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1/quotes/provider'),{quoteType:'inspection'}));
  const driver = env.authenticatedContext('driver').firestore();
  const provider = env.authenticatedContext('provider').firestore();
  await approval(driver,'r1','inspection');
  await updateDoc(doc(provider,'requests/r1'),{status:'en_route',en_routeAt:serverTimestamp()});
  await updateDoc(doc(provider,'requests/r1'),{status:'arrived',arrivedAt:serverTimestamp()});
  await assertFails(updateDoc(doc(provider,'requests/r1'),{status:'completed',finalCost:1500}));
  const proposal = writeBatch(provider);
  proposal.set(doc(provider,'requests/r1/repairQuotes/change-1'),{providerId:'provider',previousTotal:1500,
    serviceFee:1800,travelFee:500,extraFee:200,total:2500,changeReason:'Damaged valve discovered during inspection',evidencePhotoData:['test-photo'],diagnosisAndWork:'Replace damaged valve; includes inspection',createdAt:serverTimestamp()});
  proposal.update(doc(provider,'requests/r1'),{pendingRepairId:'change-1',updatedAt:serverTimestamp()});
  await assertSucceeds(proposal.commit());
  await assertFails(updateDoc(doc(provider,'requests/r1'),{status:'completed',finalCost:1500}));
  const decision = writeBatch(driver);
  decision.set(doc(driver,'requests/r1/repairDecisions/change-1'),{driverId:'driver',decision:'approved',createdAt:serverTimestamp()});
  decision.update(doc(driver,'requests/r1'),{pendingRepairId:null,lastRepairDecisionId:'change-1',lastRepairDecision:'approved',
    repairDecisionAt:serverTimestamp(),updatedAt:serverTimestamp(),approvedRepairId:'change-1',estimatedCost:2500,
    serviceFee:1800,dispatchFee:500,extraFee:200,providerDiagnosis:'Replace damaged valve; includes inspection'});
  await assertSucceeds(decision.commit());
  await assertFails(updateDoc(doc(driver,'requests/r1/repairDecisions/change-1'),{decision:'rejected'}));
  await assertFails(updateDoc(doc(provider,'requests/r1/repairQuotes/change-1'),{total:3500}));
  await assertSucceeds(updateDoc(doc(provider,'requests/r1'),{status:'completed',finalCost:2500,completedAt:serverTimestamp()}));
});
test('new requests support saved vehicle snapshots without a synthetic price', async () => {
  const db = env.authenticatedContext('driver').firestore();
  await setDoc(doc(db,'users/driver/vehicles/v1'),{make:'Toyota',model:'Aqua',year:2017,
    vehicleType:'Sedan / Hatchback',registration:'CAB-1234',fuelType:'Hybrid',transmission:'Automatic',archived:false,
    createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
  await assertSucceeds(setDoc(doc(db,'requests/new'),{driverId:'driver',driverName:'Driver',driverPhone:'',providerId:null,
    preferredProviderId:'',preferredProviderName:'',rejectedBy:[],status:'searching',workflowVersion:2,
    issue:'Flat Tyre',issues:['Flat Tyre'],vehicleType:'Sedan / Hatchback',modelYear:'Toyota Aqua 2017',registration:'CAB-1234',
    vehicleId:'v1',vehicleSnapshot:{make:'Toyota',model:'Aqua',year:2017},partsPreference:'genuine',description:'',notes:'',priority:'normal',
    vehiclePhotoUrls:[],photoAnnotations:[],locationLabel:'Colombo',landmark:'',locationAccuracyMeters:null,
    latitude:6.9,longitude:79.9,serviceFee:0,dispatchFee:0,estimatedCost:0,createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('an active provider cannot clear their reservation or delete the directory entry', async () => {
  await approval(env.authenticatedContext('driver').firestore(),'r1');
  await assertFails(updateDoc(doc(env.authenticatedContext('provider').firestore(),'providerDirectory/provider'),{activeRequestId:null}));
});
test('payment declarations are participant-only and do not alter invoice amounts', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{status:'completed',providerId:'provider',finalCost:1500}));
  const driver = env.authenticatedContext('driver').firestore();
  const provider = env.authenticatedContext('provider').firestore();
  await assertFails(updateDoc(doc(provider,'requests/r1'),{providerConfirmedPayment:true,paymentConfirmedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(driver,'requests/r1'),{driverReportedPayment:true,paymentMethod:'cash',paymentReportedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(driver,'requests/r1'),{providerConfirmedPayment:true,paymentConfirmedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(provider,'requests/r1'),{providerConfirmedPayment:true,paymentConfirmedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(driver,'requests/r1'),{driverReportedPayment:true,paymentMethod:'external',paymentReportedAt:serverTimestamp()}));
});

test('price increases require reason and evidence and cannot replace a pending revision', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'arrived',estimatedCost:1500}));
  const provider = env.authenticatedContext('provider').firestore();
  const revision = {providerId:'provider',previousTotal:1500,serviceFee:1500,travelFee:500,extraFee:0,total:2000,
    diagnosisAndWork:'Replace damaged valve',changeReason:'Valve damaged and requires replacement',evidencePhotoData:['photo'],createdAt:serverTimestamp()};
  const propose = (id, changes = {}) => {
    const batch = writeBatch(provider);
    batch.set(doc(provider,`requests/r1/repairQuotes/${id}`),{...revision,...changes});
    batch.update(doc(provider,'requests/r1'),{pendingRepairId:id,updatedAt:serverTimestamp()});
    return batch.commit();
  };
  await assertFails(propose('no-reason',{changeReason:''}));
  await assertFails(propose('no-photo',{evidencePhotoData:[]}));
  await assertFails(propose('too-many',{evidencePhotoData:['a','b','c']}));
  await assertFails(propose('too-large',{evidencePhotoData:['x'.repeat(210001)]}));
  await assertSucceeds(propose('valid'));
  await assertFails(propose('overwrite-pending'));
  await assertFails(updateDoc(doc(provider,'requests/r1/repairQuotes/valid'),{changeReason:'Different reason'}));
});
test('completed invoices cannot receive a new repair price proposal', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'completed',finalCost:1500}));
  const provider = env.authenticatedContext('provider').firestore();
  const batch = writeBatch(provider);
  batch.set(doc(provider,'requests/r1/repairQuotes/late'),{providerId:'provider',previousTotal:1500,serviceFee:2000,travelFee:0,extraFee:0,total:2000,
    diagnosisAndWork:'Extra work',changeReason:'Additional work claimed after completion',evidencePhotoData:['photo'],createdAt:serverTimestamp()});
  batch.update(doc(provider,'requests/r1'),{pendingRepairId:'late',updatedAt:serverTimestamp()});
  await assertFails(batch.commit());
});
test('dispute evidence, participant access and resolution are protected', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'completed',estimatedCost:1500,finalCost:1500});
  });
  const driver = env.authenticatedContext('driver').firestore();
  const provider = env.authenticatedContext('provider').firestore();
  const other = env.authenticatedContext('other').firestore();
  const path='requests/r1/disputes/case';
  const report={driverId:'driver',providerId:'provider',reason:'extra_charge',description:'Requested an unapproved extra fee.',photos:['evidence'],status:'open',providerResponse:'',resolution:'',approvedTotal:1500,finalTotal:1500,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertFails(setDoc(doc(provider,path), report));
  await assertFails(setDoc(doc(driver,path), {...report,photos:['x'.repeat(210001)]}));
  await assertFails(setDoc(doc(driver,path), {...report,finalTotal:9999}));
  await assertSucceeds(setDoc(doc(driver,path), report));
  await assertSucceeds(getDoc(doc(provider,path)));
  await assertFails(getDoc(doc(other,path)));
  await assertFails(updateDoc(doc(provider,path), {status:'resolved',resolution:'Driver confirmed the problem is resolved.',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(provider,path), {description:'Changed evidence',updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(provider,path), {providerResponse:'We will correct the issue tomorrow.',status:'under_review',updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(driver,path), {status:'resolved',resolution:'Driver confirmed the problem is resolved.',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(provider,path), {providerResponse:'A changed response after closing',status:'under_review',updatedAt:serverTimestamp()}));
});

test('disputes cannot be opened for unfinished jobs', async () => {
  const db=env.authenticatedContext('driver').firestore();
  await assertFails(setDoc(doc(db,'requests/r1/disputes/case'), {driverId:'driver',providerId:'provider',status:'open'}));
});