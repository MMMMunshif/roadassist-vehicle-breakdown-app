import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, getDocs, collectionGroup, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-roadassist', firestore: {host: '127.0.0.1', port: Number(process.env.FIRESTORE_TEST_PORT ?? 8089),
    rules: readFileSync(process.env.ROADASSIST_RULES_FILE ?? new URL('../../firestore.rules', import.meta.url), 'utf8')}});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();
    await setDoc(doc(db,'adminAccess/admin'),{enabled:true});
    await setDoc(doc(db,'users/admin'),{role:'driver'});
    await setDoc(doc(db,'users/driver'),{role:'driver'});
    await setDoc(doc(db,'users/other'),{role:'driver'});
    await setDoc(doc(db,'users/provider'),{role:'provider'});
    await setDoc(doc(db,'providerApplications/provider'),application());
    await setDoc(doc(db,'accountModeration/provider'),{status:'active',verification:'verified',verificationRevision:1,validUntil:Timestamp.fromMillis(Date.now()+86400000),verificationChecks:['identity','face','capability','contact'],flagged:false,reason:'Previously approved provider documents.',updatedBy:'admin',updatedAt:Timestamp.fromMillis(Date.now()-1000),lastAuditId:'seed'});
    await setDoc(doc(db,'providerDirectory/provider'),{online:true,displayName:'Mechanic',services:['General Mechanic'],vehicleTypes:['Sedan / Hatchback'],verified:true,verificationExpiresAt:(await getDoc(doc(db,'accountModeration/provider'))).data().validUntil});
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
  const db = env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertSucceeds(setDoc(doc(db,'users/driver/vehicles/v1'),{make:'Toyota',model:'Aqua',year:2017,
    vehicleType:'Sedan / Hatchback',registration:'CAB-1234',fuelType:'Hybrid',transmission:'Automatic',archived:false,
    createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(getDoc(doc(env.authenticatedContext('other', {email_verified:true}).firestore(),'users/driver/vehicles/v1')));
});
test('provider can submit an itemized offer but cannot assign a new-flow job', async () => {
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await assertSucceeds(setDoc(doc(db,'requests/r1/quotes/provider'),offer()));
  await assertFails(updateDoc(doc(db,'requests/r1'),{providerId:'provider',status:'accepted'}));
  await assertFails(setDoc(doc(db,'requests/r1/quotes/provider'),{...offer(),total:1}));
});
test('quote approval atomically reserves a provider and prevents a competing selection', async () => {
  await assertSucceeds(approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1'));
  await assertFails(approval(env.authenticatedContext('other', {email_verified:true}).firestore(),'r2'));
  await assertFails(updateDoc(doc(env.authenticatedContext('provider', {email_verified:true}).firestore(),'requests/r1/quotes/provider'),{total:9999}));
});
test('driver cannot approve an offer without reserving its provider', async () => {
  const db = env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertFails(updateDoc(doc(db,'requests/r1'),{providerId:'provider',status:'accepted',selectedQuoteId:'provider',
    serviceFee:1000,dispatchFee:500,extraFee:0,estimatedCost:1500,quoteApprovedAt:serverTimestamp()}));
});
test('driver cancellation releases the selected provider', async () => {
  const db = env.authenticatedContext('driver', {email_verified:true}).firestore();
  await approval(db,'r1');
  const batch = writeBatch(db);
  batch.update(doc(db,'requests/r1'),{status:'cancelled',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()});
  batch.update(doc(db,'providerDirectory/provider'),{activeRequestId:null});
  await assertSucceeds(batch.commit());
});
test('provider cannot silently increase an approved final charge', async () => {
  await approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1');
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{status:'arrived'}));
  await assertFails(updateDoc(doc(env.authenticatedContext('provider', {email_verified:true}).firestore(),'requests/r1'),{status:'completed',finalCost:2000,completedAt:serverTimestamp()}));
});
test('approved direct-service job progresses and releases its provider', async () => {
  await approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1');
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{providerMessagesSeenAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{providerLatitude:6.9,providerLongitude:79.9,providerLocationUpdatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{serviceNotes:'Tyre repair complete',servicePhotoData:['photo'],documentationUpdatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{status:'en_route',en_routeAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{status:'arrived',arrivedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'requests/r1'),{status:'completed',finalCost:1500,completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{completionState:'pending',finalCost:1500,completionSubmittedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'requests/r1'),{serviceNotes:'Changed evidence after submission',documentationUpdatedAt:serverTimestamp()}));
  const driver = env.authenticatedContext('driver', {email_verified:true}).firestore();
  const batch = writeBatch(driver);
  batch.update(doc(driver,'requests/r1'),{status:'completed',completionState:'confirmed',driverCompletedAt:serverTimestamp(),completedAt:serverTimestamp(),updatedAt:serverTimestamp()});
  batch.update(doc(driver,'providerDirectory/provider'),{activeRequestId:null});
  await assertSucceeds(batch.commit());
});
test('inspection-only job requires repair approval and revisions are immutable', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1/quotes/provider'),{quoteType:'inspection'}));
  const driver = env.authenticatedContext('driver', {email_verified:true}).firestore();
  const provider = env.authenticatedContext('provider', {email_verified:true}).firestore();
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
  await assertSucceeds(updateDoc(doc(provider,'requests/r1'),{serviceNotes:'Valve replaced and tested',servicePhotoData:['photo'],documentationUpdatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(provider,'requests/r1'),{completionState:'pending',finalCost:2500,completionSubmittedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('new requests support saved vehicle snapshots without a synthetic price', async () => {
  const db = env.authenticatedContext('driver', {email_verified:true}).firestore();
  await setDoc(doc(db,'users/driver/vehicles/v1'),{make:'Toyota',model:'Aqua',year:2017,
    vehicleType:'Sedan / Hatchback',registration:'CAB-1234',fuelType:'Hybrid',transmission:'Automatic',archived:false,
    createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
  await assertSucceeds(setDoc(doc(db,'requests/new'),{driverId:'driver',driverName:'Driver',driverPhone:'',providerId:null,
    preferredProviderId:'',preferredProviderName:'',rejectedBy:[],status:'searching',workflowVersion:2,arrivalVerificationRequired:true,
    issue:'Flat Tyre',issues:['Flat Tyre'],vehicleType:'Sedan / Hatchback',modelYear:'Toyota Aqua 2017',registration:'CAB-1234',
    vehicleId:'v1',vehicleSnapshot:{make:'Toyota',model:'Aqua',year:2017,photoData:'saved-photo'},partsPreference:'genuine',description:'',notes:'',priority:'normal',
    vehiclePhotoUrls:[],photoAnnotations:[],locationLabel:'Colombo',landmark:'',locationAccuracyMeters:null,
    latitude:6.9,longitude:79.9,serviceFee:0,dispatchFee:0,estimatedCost:0,createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('an active provider cannot clear their reservation or delete the directory entry', async () => {
  await approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1');
  await assertFails(updateDoc(doc(env.authenticatedContext('provider', {email_verified:true}).firestore(),'providerDirectory/provider'),{activeRequestId:null}));
});
test('payment declarations are participant-only and do not alter invoice amounts', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{status:'completed',providerId:'provider',finalCost:1500}));
  const driver = env.authenticatedContext('driver', {email_verified:true}).firestore();
  const provider = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await assertFails(updateDoc(doc(provider,'requests/r1'),{providerConfirmedPayment:true,paymentConfirmedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(driver,'requests/r1'),{driverReportedPayment:true,paymentMethod:'cash',paymentReportedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(driver,'requests/r1'),{providerConfirmedPayment:true,paymentConfirmedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(provider,'requests/r1'),{providerConfirmedPayment:true,paymentConfirmedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(driver,'requests/r1'),{driverReportedPayment:true,paymentMethod:'external',paymentReportedAt:serverTimestamp()}));
});

test('price increases require reason and evidence and cannot replace a pending revision', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'arrived',estimatedCost:1500}));
  const provider = env.authenticatedContext('provider', {email_verified:true}).firestore();
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
  const provider = env.authenticatedContext('provider', {email_verified:true}).firestore();
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
  const driver = env.authenticatedContext('driver', {email_verified:true}).firestore();
  const provider = env.authenticatedContext('provider', {email_verified:true}).firestore();
  const other = env.authenticatedContext('other', {email_verified:true}).firestore();
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
  const db=env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertFails(setDoc(doc(db,'requests/r1/disputes/case'), {driverId:'driver',providerId:'provider',status:'open'}));
});
function administrator(verified=true) { return env.authenticatedContext('admin',{admin:true,email_verified:verified}).firestore(); }
async function accountAction(db, target, changes={}, auditId='a1') {
  const before=(await getDoc(doc(db,`accountModeration/${target}`))).data() ?? {};
  const after={status:'active',verification:'pending',flagged:false,...before,...changes,reason:'Reviewed by the project administrator.',updatedBy:'admin',updatedAt:serverTimestamp(),lastAuditId:auditId};
  const batch=writeBatch(db);
  batch.set(doc(db,`accountModeration/${target}`),after);
  batch.set(doc(db,`adminAudit/${auditId}`),{kind:'account',target,actor:'admin',reason:after.reason,before,after,createdAt:serverTimestamp()});
  return batch.commit();
}
test('verified admin claims allow management reads, profile fields cannot grant access',async()=>{
  await assertSucceeds(getDoc(doc(administrator(),'users/driver')));
  await assertSucceeds(getDoc(doc(administrator(),'requests/r2')));
  await assertFails(getDoc(doc(administrator(false),'users/driver')));
  await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'users/driver'),{role:'driver',admin:true}));
  await assertFails(getDoc(doc(env.authenticatedContext('driver', {email_verified:true}).firestore(),'users/other')));
});
test('moderation needs an atomic immutable audit and blocks suspended accounts',async()=>{
  const admin=administrator();
  await assertFails(setDoc(doc(admin,'accountModeration/driver'),{status:'suspended'}));
  await assertSucceeds(accountAction(admin,'driver',{status:'suspended'}));
  const driver=env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertSucceeds(getDoc(doc(driver,'accountModeration/driver')));
  await assertFails(getDoc(doc(driver,'requests/r1')));
  await assertFails(updateDoc(doc(driver,'accountModeration/driver'),{status:'active'}));
  await assertFails(updateDoc(doc(admin,'adminAudit/a1'),{reason:'Changed history'}));
  await assertSucceeds(accountAction(admin,'driver',{status:'active'},'a2'));
  await assertSucceeds(getDoc(doc(driver,'requests/r1')));
});
test('admin cannot fabricate actor or suspend self',async()=>{
  await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'users/admin'),{role:'driver'}));
  await assertFails(accountAction(administrator(),'admin',{status:'suspended'}));
  await assertFails(setDoc(doc(administrator(),'adminAudit/fake'),{kind:'account',target:'driver',actor:'other',reason:'Forged record',before:{},after:{},createdAt:serverTimestamp()}));
});
test('complaint decisions require audit and are visible only to participants and admins',async()=>{
  await env.withSecurityRulesDisabled(async c=>{
    await updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'completed'});
    await setDoc(doc(c.firestore(),'requests/r1/disputes/case'),{status:'open'});
  });
  const admin=administrator();
  const after={status:'under_review',priority:'high',assignedTo:'admin',decision:'Reviewing both participants evidence.',updatedAt:serverTimestamp(),lastAuditId:'case-audit'};
  await assertFails(setDoc(doc(admin,'complaintReviews/r1'),after));
  const batch=writeBatch(admin);
  batch.set(doc(admin,'complaintReviews/r1'),after);
  batch.set(doc(admin,'adminAudit/case-audit'),{kind:'complaint',target:'r1',actor:'admin',reason:after.decision,before:{},after,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(env.authenticatedContext('driver', {email_verified:true}).firestore(),'complaintReviews/r1')));
  await assertFails(getDoc(doc(env.authenticatedContext('other', {email_verified:true}).firestore(),'complaintReviews/r1')));
  await assertFails(updateDoc(doc(env.authenticatedContext('provider', {email_verified:true}).firestore(),'complaintReviews/r1'),{status:'resolved'}));
});
test('admin can list complaints but cannot forge evidence or self-promote through signup',async()=>{
  await env.withSecurityRulesDisabled(async c=>{
    await updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'completed'});
    await setDoc(doc(c.firestore(),'requests/r1/disputes/case'),{status:'open'});
  });
  await assertSucceeds(getDocs(collectionGroup(administrator(),'disputes')));
  await assertFails(updateDoc(doc(administrator(),'requests/r1/disputes/case'),{description:'Admin rewrote evidence'}));
  await assertFails(setDoc(doc(env.authenticatedContext('new').firestore(),'users/new'),{role:'admin'}));
});
test('suspended providers cannot be selected or operate their directory',async()=>{
  await accountAction(administrator(),'provider',{status:'suspended'});
  await assertFails(approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1'));
  await assertFails(updateDoc(doc(env.authenticatedContext('provider', {email_verified:true}).firestore(),'providerDirectory/provider'),{online:true}));
});
test('admin registry cannot be edited by clients and revocation immediately blocks admin reads',async()=>{
  const admin=administrator();
  await assertFails(setDoc(doc(admin,'adminAccess/admin'),{enabled:true}));
  await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'adminAccess/admin'),{enabled:false}));
  await assertFails(getDoc(doc(admin,'users/driver')));
});
test('private notes are append-only, authored and hidden from normal users',async()=>{
  const admin=administrator();
  await assertSucceeds(setDoc(doc(admin,'adminNotes/n1'),{kind:'account',target:'driver',text:'Private follow-up note for account review.',actor:'admin',createdAt:serverTimestamp()}));
  await assertFails(getDoc(doc(env.authenticatedContext('driver', {email_verified:true}).firestore(),'adminNotes/n1')));
  await assertFails(updateDoc(doc(admin,'adminNotes/n1'),{text:'Rewritten note'}));
});
test('provider suspension and directory deactivation commit with the matching audit',async()=>{
  const admin=administrator();
  const after={status:'suspended',verification:'rejected',flagged:true,reason:'Profile verification rejected after review.',updatedBy:'admin',updatedAt:serverTimestamp(),lastAuditId:'disable-provider'};
  const batch=writeBatch(admin);
  batch.set(doc(admin,'accountModeration/provider'),after);
  batch.update(doc(admin,'providerDirectory/provider'),{online:false,updatedAt:serverTimestamp()});
  batch.set(doc(admin,'adminAudit/disable-provider'),{kind:'account',target:'provider',actor:'admin',reason:after.reason,before:(await getDoc(doc(admin,'accountModeration/provider'))).data(),after,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  const directory=await assertSucceeds(getDoc(doc(admin,'providerDirectory/provider')));
  if (directory.data().online!==false) throw new Error('Provider still online');
});
function application(revision = 1) {
  return {legalName: 'Test Provider', nicNumber: '199012345678', address: 'Test business address', businessName: 'Test mechanic', emergencyPhone: '+94771234567', experienceYears: 5,
    services: ['General Mechanic'], vehicleTypes: ['Sedan / Hatchback'], documents: Object.fromEntries(['nicFront','nicBack','selfie','serviceProof'].map(k => [k, 'valid-test-photo-contents-longer-than-twenty'])),
    professionalDetails:professionalDetails(), revision, submittedAt: serverTimestamp(), termsAccepted: true, consentVersion: 1};
}
const providerToken = {email_verified: true};
test('pending providers can submit privately but cannot read jobs or publish availability', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await setDoc(doc(c.firestore(), 'users/pending'), {role: 'provider', online: false});
  });
  const pending = env.authenticatedContext('pending', providerToken).firestore();
  await assertSucceeds(setDoc(doc(pending, 'providerApplications/pending'), application()));
  await assertSucceeds(getDoc(doc(pending, 'providerApplications/pending')));
  await assertFails(getDoc(doc(env.authenticatedContext('driver', {email_verified:true}).firestore(), 'providerApplications/pending')));
  await assertFails(getDoc(doc(pending, 'requests/r1')));
  await assertFails(setDoc(doc(pending, 'providerDirectory/pending'), {online: true}));
  await assertFails(setDoc(doc(pending, 'accountModeration/pending'), {verification: 'verified'}));
  await assertFails(updateDoc(doc(pending, 'providerApplications/pending'), {legalName: 'Changed without review', revision: 2, submittedAt: serverTimestamp()}));
});
test('verification rejects unverified email, incomplete identity, extra fields and missing towing proof', async () => {
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'users/pending'), {role: 'provider'}));
  const pending = env.authenticatedContext('pending', providerToken).firestore();
  await assertFails(setDoc(doc(env.authenticatedContext('pending').firestore(), 'providerApplications/pending'), application()));
  await assertFails(setDoc(doc(pending, 'providerApplications/pending'), {...application(), documents: {nicFront: 'x'}}));
  await assertFails(setDoc(doc(pending, 'providerApplications/pending'), {...application(), services: ['Vehicle Towing']}));
  await assertFails(setDoc(doc(pending, 'providerApplications/pending'), {...application(), approved: true}));
});
test('provider approval requires current documents, checklist and expiry with an atomic audit', async () => {
  const admin = administrator();
  await assertFails(accountAction(admin, 'provider', {verification: 'verified', verificationChecks: ['identity']}, 'bad-checks'));
  await assertFails(accountAction(admin, 'provider', {verification: 'verified', verificationRevision: 999}, 'bad-revision'));
  await assertSucceeds(accountAction(admin, 'provider', {verification: 'verified', verificationRevision: 1, verificationChecks: ['identity','face','capability','contact'], validUntil: Timestamp.fromMillis(Date.now() + 86400000)}, 'good-approval'));
});
test('document corrections allow resubmission and revoke business access until fresh approval', async () => {
  const admin = administrator();
  await assertSucceeds(accountAction(admin, 'provider', {verification: 'pending'}, 'corrections'));
  const provider = env.authenticatedContext('provider', providerToken).firestore();
  await assertSucceeds(setDoc(doc(provider, 'providerApplications/provider'), application(2)));
  await assertFails(getDoc(doc(provider, 'requests/r1')));
  await assertFails(setDoc(doc(provider, 'requests/r1/quotes/provider'), offer()));
  await assertFails(approval(env.authenticatedContext('driver', {email_verified:true}).firestore(), 'r1'));
});
test('expired or email-unverified providers cannot take assistance jobs', async () => {
  await assertFails(getDoc(doc(env.authenticatedContext('provider').firestore(), 'requests/r1')));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'accountModeration/provider'), {validUntil: Timestamp.fromMillis(Date.now() - 1000)}));
  await assertFails(setDoc(doc(env.authenticatedContext('provider', providerToken).firestore(), 'requests/r1/quotes/provider'), offer()));
  await assertFails(approval(env.authenticatedContext('driver', {email_verified:true}).firestore(), 'r1'));
});
test('support cannot access identity documents or approve providers; reviewer cannot suspend drivers', async () => {
  const admin = administrator();
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'adminAccess/admin'), {role: 'support'}));
  await assertFails(getDoc(doc(admin, 'providerApplications/provider')));
  await assertFails(accountAction(admin, 'provider', {verification: 'verified'}, 'support-approve'));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'adminAccess/admin'), {role: 'reviewer'}));
  await assertSucceeds(getDoc(doc(admin, 'providerApplications/provider')));
  await assertFails(accountAction(admin, 'driver', {status: 'suspended'}, 'reviewer-driver'));
});
test('settings require super-admin and matching immutable audit; client mail receipts are denied', async () => {
  const db = administrator();
  const after = {maintenance: true, notice: 'Service maintenance', coverage: 'Test region', enabledServices: ['Flat Tyre'], reason: 'Scheduled maintenance requested.', updatedAt: serverTimestamp(), updatedBy: 'admin', lastAuditId: 'settings-1'};
  await assertFails(setDoc(doc(db, 'appSettings/operations'), after));
  const batch = writeBatch(db);
  batch.set(doc(db, 'appSettings/operations'), after);
  batch.set(doc(db, 'adminAudit/settings-1'), {kind: 'settings', target: 'operations', actor: 'admin', reason: after.reason, before: {}, after, createdAt: serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(db, 'providerApprovalEmails/fake'), {status: 'sent'}));
  await assertFails(updateDoc(doc(db, 'adminAudit/settings-1'), {reason: 'Changed settings audit.'}));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'adminAccess/admin'), {role: 'support'}));
  await assertFails(updateDoc(doc(db, 'appSettings/operations'), {maintenance: false}));
});

test('approved directory publication binds expiry and services to reviewed documents', async () => {
  const db = env.authenticatedContext('provider', providerToken).firestore();
  const original = (await getDoc(doc(db, 'providerDirectory/provider'))).data();
  await assertSucceeds(setDoc(doc(db, 'providerDirectory/provider'), {...original, updatedAt: serverTimestamp()}));
  await assertFails(setDoc(doc(db, 'providerDirectory/provider'), {...original, verificationExpiresAt: Timestamp.fromMillis(Date.now() + 365 * 86400000)}));
  await assertFails(setDoc(doc(db, 'providerDirectory/provider'), {...original, services: ['Vehicle Towing']}));
});
test('maintenance and disabled services reject new requests while existing jobs remain readable', async () => {
  const db = env.authenticatedContext('driver', {email_verified:true}).firestore();
  const request = {driverId: 'driver', driverName: 'Driver', driverPhone: '+94771234567', providerId: null, preferredProviderId: '', preferredProviderName: '', rejectedBy: [],
    status: 'searching', workflowVersion: 2, arrivalVerificationRequired:true, issue: 'Flat Tyre', issues: ['Flat Tyre'], vehicleType: 'Sedan / Hatchback', modelYear: 'Toyota Aqua 2018', registration: 'WP-1234',
    description: '', notes: '', priority: 'normal', vehiclePhotoUrls: [], photoAnnotations: [], locationLabel: 'Test location', landmark: '', locationAccuracyMeters: null,
    latitude: 6.9, longitude: 79.9, serviceFee: 0, dispatchFee: 0, estimatedCost: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(db, 'requests/new-a'), request));
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'appSettings/operations'), {maintenance: true, enabledServices: ['Flat Tyre']}));
  await assertFails(setDoc(doc(db, 'requests/new-b'), request));
  await assertSucceeds(getDoc(doc(db, 'requests/r1')));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'appSettings/operations'), {maintenance: false, enabledServices: ['General Mechanic']}));
  await assertFails(setDoc(doc(db, 'requests/new-c'), request));
});
test('complaint deadlines and reopen decisions are audited and provider reviewers cannot decide cases', async () => {
  const admin = administrator();
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'requests/r1/disputes/case'), {driverId: 'driver', providerId: 'provider', status: 'open'}));
  async function review(status, auditId) {
    const ref = doc(admin, 'complaintReviews/r1'), before = (await getDoc(ref)).data() ?? {};
    const after = {status, priority: 'urgent', assignedTo: 'admin', dueAt: Timestamp.fromMillis(Date.now()+86400000), decision: 'Evidence reviewed; follow up with both participants.', updatedAt: serverTimestamp(), lastAuditId: auditId};
    const b = writeBatch(admin);
    b.set(ref, after); b.set(doc(admin, `adminAudit/${auditId}`), {kind: 'complaint', target: 'r1', actor: 'admin', reason: after.decision, before, after, createdAt: serverTimestamp()});
    return b.commit();
  }
  await assertSucceeds(review('resolved', 'close-case'));
  await assertSucceeds(review('under_review', 'reopen-case'));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'adminAccess/admin'), {role: 'reviewer'}));
  await assertFails(review('dismissed', 'reviewer-case'));
});

function professionalDetails() {
  return {providerType:'independent',businessPhone:'+94771234567',businessRegistration:'',
    workHistory:'Five years repairing engines and brakes in a local workshop.',qualification:'Practical mechanic training',trainingInstitute:'Local workshop',qualificationYear:2020,
    specializations:'Toyota engines and electrical systems',coverageAreas:'Colombo',radiusKm:15,startTime:'08:00',endTime:'18:00',towRegistration:'',towCapacityKg:0,insuranceDetails:'',
    available24Hours:false,languages:['Tamil'],workDays:['Mon','Tue'],tools:['Hand tools']};
}
test('professional details are required and invalid schedules or work experience are rejected', async () => {
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(),'users/new-provider'),{role:'provider'}));
  const db=env.authenticatedContext('new-provider',{email_verified:true}).firestore();
  const a=application(); delete a.professionalDetails;
  await assertFails(setDoc(doc(db,'providerApplications/new-provider'),a));
  await assertFails(setDoc(doc(db,'providerApplications/new-provider'),{...application(),professionalDetails:{...professionalDetails(),workHistory:'Short'}}));
  await assertFails(setDoc(doc(db,'providerApplications/new-provider'),{...application(),professionalDetails:{...professionalDetails(),startTime:'25:99'}}));
  await assertSucceeds(setDoc(doc(db,'providerApplications/new-provider'),application()));
});
test('registered businesses and towing require matching documents and recovery capability', async () => {
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(),'users/new-provider'),{role:'provider'}));
  const db=env.authenticatedContext('new-provider',{email_verified:true}).firestore();
  const p={...professionalDetails(),providerType:'business',businessRegistration:'BR-123',towRegistration:'WP-1234',towCapacityKg:3500,tools:['Recovery truck','Safety equipment']};
  const a={...application(),services:['Vehicle Towing'],professionalDetails:p};
  await assertFails(setDoc(doc(db,'providerApplications/new-provider'),a));
  a.documents={...a.documents,recoveryProof:'test-recovery-photo-with-sufficient-length',businessProof:'test-business-photo-with-sufficient-length'};
  await assertSucceeds(setDoc(doc(db,'providerApplications/new-provider'),a));
});

test('simplified provider application accepts omitted optional answers without invented details', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'users/simple-provider'),{role:'provider'});
  });
  const db=env.authenticatedContext('simple-provider',{email_verified:true}).firestore();
  const basic={...professionalDetails(),workHistory:'',qualification:'',trainingInstitute:'',qualificationYear:0,specializations:'',coverageAreas:'',startTime:'',endTime:'',languages:[],workDays:[],tools:[]};
  await assertSucceeds(setDoc(doc(db,'providerApplications/simple-provider'),{...application(),businessName:'',emergencyPhone:'',professionalDetails:basic}));
});
test('provider withdrawal requires reason and atomic release and preserves charges', async()=> {
  await env.withSecurityRulesDisabled(async c=> {
    await updateDoc(doc(c.firestore(),'requests/r1'),{status:'accepted',providerId:'provider',acceptedAt:Timestamp.now(),estimatedCost:1800});
    await updateDoc(doc(c.firestore(),'providerDirectory/provider'),{activeRequestId:'r1'});
  });
  const db=env.authenticatedContext('provider',{email_verified:true}).firestore();
  const change={status:'cancelled',cancelledBy:'provider',cancellationType:'provider_withdrawal',cancellationReason:'Vehicle equipment broke down.',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertFails(updateDoc(doc(db,'requests/r1'),change));
  const batch=writeBatch(db); batch.update(doc(db,'requests/r1'),change); batch.update(doc(db,'providerDirectory/provider'),{activeRequestId:null});
  await assertSucceeds(batch.commit());
  const saved=(await getDoc(doc(db,'requests/r1'))).data();
  if(saved.estimatedCost!==1800) throw new Error('Approved price was changed');
});
test('departure timeout rejects premature cancellation and allows driver recovery after ten minutes', async()=> {
  await env.withSecurityRulesDisabled(async c=> {
    await updateDoc(doc(c.firestore(),'requests/r1'),{status:'accepted',providerId:'provider',acceptedAt:Timestamp.now()});
    await updateDoc(doc(c.firestore(),'providerDirectory/provider'),{activeRequestId:'r1'});
  });
  const db=env.authenticatedContext('driver', {email_verified:true}).firestore();
  const change={status:'cancelled',cancelledBy:'driver',cancellationType:'departure_timeout',cancellationReason:'Provider has not departed or replied.',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()};
  function cancel(){ const b=writeBatch(db);b.update(doc(db,'requests/r1'),change);b.update(doc(db,'providerDirectory/provider'),{activeRequestId:null});return b.commit(); }
  await assertFails(cancel());
  await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'requests/r1'),{acceptedAt:Timestamp.fromMillis(Date.now()-11*60000)}));
  await assertSucceeds(cancel());
});
test('providers cannot abandon arrived jobs or cancel another provider assignment',async()=> {
  await env.withSecurityRulesDisabled(async c=> {
    await updateDoc(doc(c.firestore(),'requests/r1'),{status:'arrived',providerId:'provider'});
    await updateDoc(doc(c.firestore(),'providerDirectory/provider'),{activeRequestId:'r1'});
  });
  const db=env.authenticatedContext('provider',{email_verified:true}).firestore();
  const change={status:'cancelled',cancelledBy:'provider',cancellationType:'provider_withdrawal',cancellationReason:'Cannot attend this job anymore.',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()};
  const b=writeBatch(db);b.update(doc(db,'requests/r1'),change);b.update(doc(db,'providerDirectory/provider'),{activeRequestId:null});await assertFails(b.commit());
  await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'requests/r1'),{status:'accepted',providerId:'someone-else'}));
  await assertFails(updateDoc(doc(db,'requests/r1'),change));
});
test('completion requires evidence and drivers cannot confirm without a submission', async()=> {
  await env.withSecurityRulesDisabled(async c=>{
    await updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'arrived',estimatedCost:1500,serviceNotes:'',servicePhotoData:[]});
    await updateDoc(doc(c.firestore(),'providerDirectory/provider'),{activeRequestId:'r1'});
  });
  const provider=env.authenticatedContext('provider',{email_verified:true}).firestore(),driver=env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertFails(updateDoc(doc(provider,'requests/r1'),{completionState:'pending',finalCost:1500,completionSubmittedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(driver,'requests/r1'),{status:'completed',completionState:'confirmed',driverCompletedAt:serverTimestamp(),completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('completion complaint evidence blocks closure until admin review is resolved',async()=> {
  await env.withSecurityRulesDisabled(async c=> {
    await updateDoc(doc(c.firestore(),'requests/r1'),{status:'arrived',providerId:'provider',completionState:'pending',estimatedCost:1500,finalCost:1500});
    await updateDoc(doc(c.firestore(),'providerDirectory/provider'),{activeRequestId:'r1'});
  });
  const db=env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertSucceeds(setDoc(doc(db,'requests/r1/disputes/case'),{driverId:'driver',providerId:'provider',reason:'incomplete_service',description:'The vehicle still cannot start after repair.',photos:['evidence'],status:'open',providerResponse:'',resolution:'',approvedTotal:1500,finalTotal:1500,createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  function confirm(){ const b=writeBatch(db);b.update(doc(db,'requests/r1'),{status:'completed',completionState:'confirmed',driverCompletedAt:serverTimestamp(),completedAt:serverTimestamp(),updatedAt:serverTimestamp()});b.update(doc(db,'providerDirectory/provider'),{activeRequestId:null});return b.commit(); }
  await assertFails(confirm());
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'complaintReviews/r1'),{status:'resolved'}));
  await assertSucceeds(confirm());
});
test('new arrival verification is driver-only and blocks repair completion until confirmed',async()=> {
  await env.withSecurityRulesDisabled(async c=>{
    await updateDoc(doc(c.firestore(),'requests/r1'),{status:'arrived',providerId:'provider',arrivalVerificationRequired:true,estimatedCost:1500,serviceNotes:'Work complete and tested',servicePhotoData:['photo']});
    await updateDoc(doc(c.firestore(),'providerDirectory/provider'),{activeRequestId:'r1'});
  });
  const driver=env.authenticatedContext('driver', {email_verified:true}).firestore(),provider=env.authenticatedContext('provider',{email_verified:true}).firestore();
  const completion={completionState:'pending',completionSubmittedAt:serverTimestamp(),finalCost:1500,updatedAt:serverTimestamp()};
  await assertFails(updateDoc(doc(provider,'requests/r1'),completion));
  const confirmation={arrivalConfirmedBy:'driver',arrivalConfirmedAt:serverTimestamp(),arrivalConfirmationMethod:'manual_driver',arrivalConfirmationReason:'GPS unavailable but provider met me.',arrivalDistanceMeters:null,updatedAt:serverTimestamp()};
  await assertFails(updateDoc(doc(provider,'requests/r1'),confirmation));
  await assertFails(updateDoc(doc(env.authenticatedContext('other', {email_verified:true}).firestore(),'requests/r1'),confirmation));
  await assertFails(updateDoc(doc(driver,'requests/r1'),{...confirmation,arrivalConfirmationReason:''}));
  await assertSucceeds(updateDoc(doc(driver,'requests/r1'),confirmation));
  await assertFails(updateDoc(doc(driver,'requests/r1'),{...confirmation,arrivalConfirmationReason:'Rewrite existing confirmation'}));
  await assertSucceeds(updateDoc(doc(provider,'requests/r1'),completion));
});
test('driver cannot confirm arrival before provider reports arrival',async()=> {
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'requests/r1'),{status:'en_route',providerId:'provider',arrivalVerificationRequired:true}));
  const db=env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertFails(updateDoc(doc(db,'requests/r1'),{arrivalConfirmedBy:'driver',arrivalConfirmedAt:serverTimestamp(),arrivalConfirmationMethod:'gps_nearby_driver',arrivalConfirmationReason:'',arrivalDistanceMeters:10,updatedAt:serverTimestamp()}));
});
test('pause and closed working hours prevent quotes and driver reservation',async()=> {
  const provider=env.authenticatedContext('provider',{email_verified:true}).firestore();
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'providerDirectory/provider'),{requestsPaused:true}));
  await assertFails(setDoc(doc(provider,'requests/r1/quotes/provider'),offer()));
  await assertFails(approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1'));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'providerDirectory/provider'),{requestsPaused:false,scheduleConfigured:true,available24Hours:false,workStartMinute:0,workEndMinute:0}));
  await assertFails(setDoc(doc(provider,'requests/r1/quotes/provider'),offer()));
  await assertFails(approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1'));
  await assertSucceeds(updateDoc(doc(provider,'providerDirectory/provider'),{hoursOverrideUntil:Timestamp.fromMillis(Date.now()+2*3600000),updatedAt:serverTimestamp()}));
  await assertSucceeds(setDoc(doc(provider,'requests/r1/quotes/provider'),offer()));
  await assertSucceeds(approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1'));
});
test('availability override is bounded and 24-hour providers can quote with a closed schedule',async()=> {
  const provider=env.authenticatedContext('provider',{email_verified:true}).firestore();
  await assertFails(updateDoc(doc(provider,'providerDirectory/provider'),{hoursOverrideUntil:Timestamp.fromMillis(Date.now()+4*3600000)}));
  await assertSucceeds(updateDoc(doc(provider,'providerDirectory/provider'),{scheduleConfigured:true,workStartMinute:0,workEndMinute:0,available24Hours:true}));
  await assertSucceeds(setDoc(doc(provider,'requests/r1/quotes/provider'),offer()));
});
test('warranty offers are validated and immutable after acceptance', async () => {
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  const ref = doc(db,'requests/r1/quotes/provider');
  const warranty = {...offer(),warrantyDays:30,warrantyTerms:'Repaired puncture only; new tyre damage excluded.'};
  await assertFails(setDoc(ref,{...warranty,warrantyDays:366}));
  await assertFails(setDoc(ref,{...warranty,warrantyTerms:''}));
  await assertFails(setDoc(ref,{...warranty,quoteType:'inspection'}));
  await assertSucceeds(setDoc(ref,warranty));
  await assertSucceeds(approval(env.authenticatedContext('driver', {email_verified:true}).firestore(),'r1'));
  await assertFails(updateDoc(ref,{warrantyDays:0,warrantyTerms:''}));
});
test('repeated problem reports require completed service and photo evidence',async()=> {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'completed',estimatedCost:1500,finalCost:1500}));
  const db=env.authenticatedContext('driver', {email_verified:true}).firestore();
  const ref=doc(db,'requests/r1/disputes/case');
  const report={driverId:'driver',providerId:'provider',reason:'same_problem',description:'The same repaired puncture is leaking again.',photos:[],status:'open',providerResponse:'',resolution:'',approvedTotal:1500,finalTotal:1500,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertFails(setDoc(ref,report));
  await assertSucceeds(setDoc(ref,{...report,photos:['photo']}));
  await assertFails(updateDoc(doc(env.authenticatedContext('provider',{email_verified:true}).firestore(),'requests/r1'),{finalCost:2000}));
});

test('saved vehicle photos are bounded and stay owner-only',async()=> {
  const db=env.authenticatedContext('driver', {email_verified:true}).firestore();
  const vehicle={make:'Toyota',model:'Aqua',year:2018,vehicleType:'Sedan / Hatchback',registration:'CAB-1234',fuelType:'Hybrid',transmission:'Automatic',photoData:'photo',archived:false,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  const ref=doc(db,'users/driver/vehicles/photo');
  await assertSucceeds(setDoc(ref,vehicle));
  await assertFails(getDoc(doc(env.authenticatedContext('provider',{email_verified:true}).firestore(),'users/driver/vehicles/photo')));
  await assertFails(updateDoc(ref,{photoData:'x'.repeat(210001),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref,{photoData:'',updatedAt:serverTimestamp()}));
});

test('unverified drivers cannot access vehicles or assistance requests', async () => {
  const db = env.authenticatedContext('driver', {email_verified:false}).firestore();
  await assertFails(getDoc(doc(db,'requests/r1')));
  await assertFails(setDoc(doc(db,'users/driver/vehicles/v1'),{make:'Toyota',model:'Aqua',year:2017,
    vehicleType:'Sedan / Hatchback',registration:'CAB-1234',fuelType:'Hybrid',transmission:'Automatic',archived:false,
    createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});

test('owner may add provider role but cannot grant admin or remove driver role', async () => {
  const db = env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertSucceeds(updateDoc(doc(db,'users/driver'),{roles:['driver','provider'],roleEmailRequired:['provider'],lastRole:'provider',online:false}));
  await assertFails(updateDoc(doc(db,'users/driver'),{roles:['driver','provider','admin']}));
  await assertFails(updateDoc(doc(db,'users/driver'),{roles:['provider']}));
  await assertFails(updateDoc(doc(db,'users/driver'),{role:'provider'}));
  await assertFails(updateDoc(doc(db,'users/driver'),{online:true}));
  await assertFails(setDoc(doc(db,'requests/r1/quotes/driver'),{...offer(),providerId:'driver'}));
});

test('profile updates validate name, phone and authenticated email', async () => {
  const db = env.authenticatedContext('driver', {email_verified:true,email:'driver@example.com'}).firestore();
  await assertFails(updateDoc(doc(db,'users/driver'),{displayName:'A'}));
  await assertFails(updateDoc(doc(db,'users/driver'),{phone:'123'}));
  await assertFails(updateDoc(doc(db,'users/driver'),{email:'other@example.com'}));
  await assertSucceeds(updateDoc(doc(db,'users/driver'),{displayName:'Driver Name',phone:'+94771234567',email:'driver@example.com'}));
});

test('dual-role provider retains driver access and cannot quote own job', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await updateDoc(doc(c.firestore(),'users/provider'),{roles:['provider','driver'],lastRole:'driver'});
    await updateDoc(doc(c.firestore(),'requests/r1'),{driverId:'provider'});
  });
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await assertSucceeds(getDoc(doc(db,'requests/r1')));
  await assertFails(setDoc(doc(db,'requests/r1/quotes/provider'),offer()));
  await assertSucceeds(setDoc(doc(db,'users/provider/vehicles/v1'),{make:'Toyota',model:'Aqua',year:2017,
    vehicleType:'Sedan / Hatchback',registration:'CAB-1234',fuelType:'Hybrid',transmission:'Automatic',archived:false,
    createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});


test('new unverified account profile is allowed but malformed registration is rejected', async () => {
  const db = env.authenticatedContext('new-account', {email:'new@example.com',email_verified:false}).firestore();
  const profile = {email:'new@example.com',displayName:'New Driver',phone:'+94771234567',role:'driver',roles:['driver'],lastRole:'driver',online:false,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertFails(setDoc(doc(db,'users/new-account'),{...profile,phone:'123'}));
  await assertFails(setDoc(doc(db,'users/new-account'),{...profile,roles:['driver','admin']}));
  await assertSucceeds(setDoc(doc(db,'users/new-account'),profile));
  await assertFails(getDoc(doc(db,'requests/r1')));
});

test('driver-first dual-role account may submit provider documents while approval remains required', async () => {
  const db = env.authenticatedContext('driver', {email_verified:true}).firestore();
  await assertSucceeds(updateDoc(doc(db,'users/driver'),{roles:['driver','provider'],roleEmailRequired:['provider'],lastRole:'provider',online:false}));
  await assertFails(setDoc(doc(db,'providerApplications/driver'),application()));
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(),'roleEmailVerifications/driver'),{provider:{email:''}}));
  await assertSucceeds(setDoc(doc(db,'providerApplications/driver'),application()));
  await assertFails(setDoc(doc(db,'requests/r2/quotes/driver'),{...offer(),providerId:'driver'}));
  await assertSucceeds(getDoc(doc(db,'requests/r1')));
});


test('pending provider may withdraw only their application; documents are retained and approval blocked', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await updateDoc(doc(c.firestore(),'accountModeration/provider'), {verification:'pending'});
  });
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await assertFails(updateDoc(doc(env.authenticatedContext('other', {email_verified:true}).firestore(),'providerApplications/provider'), {applicationStatus:'withdrawn',withdrawnAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'providerApplications/provider'), {applicationStatus:'withdrawn',withdrawnAt:serverTimestamp(),documents:{}}));
  await assertSucceeds(updateDoc(doc(db,'providerApplications/provider'), {applicationStatus:'withdrawn',withdrawnAt:serverTimestamp()}));
  const saved = (await getDoc(doc(db,'providerApplications/provider'))).data();
  if (!saved.documents.selfie) throw new Error('Selfie must be retained');
  await assertSucceeds(setDoc(doc(db,'providerApplications/provider'), {...application(),revision:2}));
});

test('approved provider cannot withdraw an already approved application', async () => {
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await assertFails(updateDoc(doc(db,'providerApplications/provider'), {applicationStatus:'withdrawn',withdrawnAt:serverTimestamp()}));
});

test('additional services require a selected matching category and bounded description', async () => {
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await env.withSecurityRulesDisabled(async c => {
    await updateDoc(doc(c.firestore(),'providerApplications/provider'), {applicationStatus:'withdrawn'});
  });
  const item = {name:'Fuel delivery',description:'Emergency fuel delivery for stranded cars.',category:'General Mechanic'};
  await assertFails(setDoc(doc(db,'providerApplications/provider'), {...application(), revision:2,customServices:[{...item,category:'Unreviewed category'}]}));
  await assertFails(setDoc(doc(db,'providerApplications/provider'), {...application(), revision:2,customServices:[{...item,description:'x'}]}));
  await assertSucceeds(setDoc(doc(db,'providerApplications/provider'), {...application(), revision:2,customServices:[item]}));
});


test('withdrawn application never grants provider permissions even with stale verified moderation', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await updateDoc(doc(c.firestore(),'providerApplications/provider'), {applicationStatus:'withdrawn'});
  });
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await assertFails(setDoc(doc(db,'requests/r1/quotes/provider'),offer()));
});

async function seedCompletion() {
  await env.withSecurityRulesDisabled(async c => {
    await updateDoc(doc(c.firestore(),'requests/r1'),{status:'arrived',providerId:'provider',completionState:'pending',
      estimatedCost:1500,finalCost:1500,serviceNotes:'Repair complete and checked',servicePhotoData:['photo']});
    await updateDoc(doc(c.firestore(),'providerDirectory/provider'),{activeRequestId:'r1'});
  });
}
function discountRequest(db, total=1200) {
  const batch=writeBatch(db);
  batch.set(doc(db,'requests/r1/completionDiscounts/d1'),{driverId:'driver',providerId:'provider',previousTotal:1500,
    requestedTotal:total,reason:'Please agree to this cash discount.',status:'pending',createdAt:serverTimestamp()});
  batch.update(doc(db,'requests/r1'),{pendingDiscountId:'d1',updatedAt:serverTimestamp()});
  return batch.commit();
}
function discountAnswer(db, accept=true) {
  const batch=writeBatch(db);
  batch.update(doc(db,'requests/r1/completionDiscounts/d1'),{status:accept?'accepted':'declined',decidedBy:'provider',decidedAt:serverTimestamp()});
  batch.update(doc(db,'requests/r1'),{pendingDiscountId:null,finalCost:accept?1200:1500,updatedAt:serverTimestamp()});
  return batch.commit();
}
test('discount is mutually agreed, cannot increase price and keeps an immutable record',async()=>{
  await seedCompletion();
  const driver=env.authenticatedContext('driver',{email_verified:true}).firestore();
  const provider=env.authenticatedContext('provider',{email_verified:true}).firestore();
  await assertFails(discountRequest(provider));
  await assertFails(discountRequest(driver,1800));
  await assertSucceeds(discountRequest(driver));
  await assertFails(discountAnswer(driver));
  await assertFails(updateDoc(doc(provider,'requests/r1'),{finalCost:1200,pendingDiscountId:null,updatedAt:serverTimestamp()}));
  const close=writeBatch(driver);
  close.update(doc(driver,'requests/r1'),{status:'completed',completionState:'confirmed',driverCompletedAt:serverTimestamp(),completedAt:serverTimestamp(),updatedAt:serverTimestamp()});
  close.update(doc(driver,'providerDirectory/provider'),{activeRequestId:null});
  await assertFails(close.commit());
  await assertSucceeds(discountAnswer(provider));
  await assertFails(updateDoc(doc(provider,'requests/r1/completionDiscounts/d1'),{requestedTotal:1300}));
  await assertFails(updateDoc(doc(provider,'requests/r1'),{finalCost:1700,updatedAt:serverTimestamp()}));
  const complete=writeBatch(driver);
  complete.update(doc(driver,'requests/r1'),{status:'completed',completionState:'confirmed',driverCompletedAt:serverTimestamp(),completedAt:serverTimestamp(),updatedAt:serverTimestamp()});
  complete.update(doc(driver,'providerDirectory/provider'),{activeRequestId:null});
  await assertSucceeds(complete.commit());
});
test('declining a discount preserves the original final price',async()=>{
  await seedCompletion();
  const driver=env.authenticatedContext('driver',{email_verified:true}).firestore();
  const provider=env.authenticatedContext('provider',{email_verified:true}).firestore();
  await discountRequest(driver);
  await assertSucceeds(discountAnswer(provider,false));
  if((await getDoc(doc(driver,'requests/r1'))).data().finalCost!==1500) throw new Error('Price changed on decline');
});
test('completed report is validated and locked after submission',async()=>{
  await seedCompletion();
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'requests/r1'),{completionState:''}));
  const provider=env.authenticatedContext('provider',{email_verified:true}).firestore();
  const report={problem:'The tyre valve was leaking',repairs:'Replaced valve and checked pressure',parts:'1 tyre valve',advice:'Recheck pressure tomorrow'};
  const submit={completionState:'pending',finalCost:1500,completionSubmittedAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertFails(updateDoc(doc(provider,'requests/r1'),{...submit,completionReport:{...report,problem:''}}));
  await assertSucceeds(updateDoc(doc(provider,'requests/r1'),{...submit,completionReport:report}));
  await assertFails(updateDoc(doc(provider,'requests/r1'),{completionReport:{...report,parts:'Something else'},updatedAt:serverTimestamp()}));
});


test('selective corrections bind revision and lock unselected fields and documents', async () => {
  const admin = administrator();
  const request = {revision:1,documents:['selfie','nicBack'],requestedAt:serverTimestamp()};
  await assertFails(accountAction(admin,'provider',{verification:'pending',correctionRequest:{...request,revision:99}},'stale-correction'));
  await assertFails(accountAction(admin,'provider',{verification:'pending',correctionRequest:{...request,documents:['unknown']}},'unknown-correction'));
  await assertSucceeds(accountAction(admin,'provider',{verification:'pending',correctionRequest:request},'selective-correction'));
  await assertFails(accountAction(admin,'provider',{verification:'verified',correctionRequest:request},'early-approval'));
  const provider = env.authenticatedContext('provider',providerToken).firestore();
  const saved = (await getDoc(doc(provider,'providerApplications/provider'))).data();
  const corrected = {...saved, revision:2,submittedAt:serverTimestamp(),documents:{...saved.documents,selfie:'new-valid-face-photo-contents-longer-than-twenty',nicBack:'new-valid-back-photo-contents-longer-than-twenty'}};
  await assertFails(setDoc(doc(provider,'providerApplications/provider'),{...corrected,legalName:'Tampered Name'}));
  await assertFails(setDoc(doc(provider,'providerApplications/provider'),{...corrected,documents:{...corrected.documents,nicFront:'tampered-front-photo-contents-longer-than-twenty'}}));
  await assertFails(setDoc(doc(provider,'providerApplications/provider'),{...corrected,documents:{...corrected.documents,selfie:saved.documents.selfie}}));
  await assertSucceeds(setDoc(doc(provider,'providerApplications/provider'),corrected));
  await assertFails(setDoc(doc(provider,'providerApplications/provider'),{...corrected,revision:3}));
  const before=(await getDoc(doc(admin,'accountModeration/provider'))).data();
  const after={...before,verification:'verified',verificationRevision:2,reason:'Corrected identity documents have been reviewed.',updatedBy:'admin',updatedAt:serverTimestamp(),lastAuditId:'after-correction'};
  delete after.correctionRequest;
  const batch=writeBatch(admin);
  batch.set(doc(admin,'accountModeration/provider'),after);
  batch.set(doc(admin,'adminAudit/after-correction'),{kind:'account',target:'provider',actor:'admin',reason:after.reason,before,after,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
});

test('private job start challenge cannot be read or written by either participant', async()=>{
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'jobStartChallenges/r1'),{digest:'secret',salt:'private',expiresAtMs:Date.now()+600000}));
  for (const uid of ['driver','provider','other']) {
    const db=env.authenticatedContext(uid,{email_verified:true}).firestore();
    await assertFails(getDoc(doc(db,'jobStartChallenges/r1')));
    await assertFails(setDoc(doc(db,'jobStartChallenges/r1'),{code:'123456'}));
  }
});
test('code-required jobs cannot bypass start verification through direct arrival confirmation', async()=>{
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'arrived',jobStartCodeRequired:true,arrivalVerificationRequired:true}));
  const db=env.authenticatedContext('driver',{email_verified:true}).firestore();
  await assertFails(updateDoc(doc(db,'requests/r1'),{arrivalConfirmedBy:'driver',arrivalConfirmedAt:serverTimestamp(),arrivalConfirmationMethod:'manual_driver',arrivalConfirmationReason:'Physically met this provider.',arrivalDistanceMeters:null,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'requests/r1'),{jobStartCodeVerifiedAt:serverTimestamp()}));
});
test('cancellation records a bounded driver reason and cannot hide pending completion', async()=>{
  const db=env.authenticatedContext('driver',{email_verified:true}).firestore();
  const changes={status:'cancelled',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp(),cancelledBy:'driver',cancellationType:'driver_cancellation',cancellationReason:'A family member provided assistance.'};
  await assertFails(updateDoc(doc(db,'requests/r1'),{...changes,cancellationReason:'x'}));
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),changes));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'requests/r1'),{status:'arrived',completionState:'pending'}));
  await assertFails(updateDoc(doc(db,'requests/r1'),changes));
});
test('completed job rating is immutable after the first rating', async()=>{
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'requests/r1'),{status:'completed',providerId:'provider'}));
  const db=env.authenticatedContext('driver',{email_verified:true}).firestore();
  await assertSucceeds(updateDoc(doc(db,'requests/r1'),{driverRating:5,ratedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'requests/r1'),{driverRating:1,ratedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('complaint history is participant-readable, admin-paired and immutable',async()=>{
  await env.withSecurityRulesDisabled(async c=>{
    await updateDoc(doc(c.firestore(),'requests/r1'),{providerId:'provider',status:'completed'});
    await setDoc(doc(c.firestore(),'requests/r1/disputes/case'),{status:'open'});
  });
  const admin=administrator(), id='history-audit';
  const after={status:'under_review',priority:'high',assignedTo:'admin',decision:'Reviewing evidence with both participants.',updatedAt:serverTimestamp(),lastAuditId:id};
  const batch=writeBatch(admin);
  batch.set(doc(admin,'complaintReviews/r1'),after);
  batch.set(doc(admin,`adminAudit/${id}`),{kind:'complaint',target:'r1',actor:'admin',reason:after.decision,before:{},after,createdAt:serverTimestamp()});
  batch.set(doc(admin,`complaintReviews/r1/history/${id}`),{status:after.status,decision:after.decision,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  const driver=env.authenticatedContext('driver',{email_verified:true}).firestore();
  await assertSucceeds(getDoc(doc(driver,`complaintReviews/r1/history/${id}`)));
  await assertFails(getDoc(doc(env.authenticatedContext('other',{email_verified:true}).firestore(),`complaintReviews/r1/history/${id}`)));
  await assertFails(updateDoc(doc(admin,`complaintReviews/r1/history/${id}`),{decision:'Changed history'}));
  await assertFails(setDoc(doc(driver,'complaintReviews/r1/history/forged'),{status:'resolved',decision:'Forged support review',createdAt:serverTimestamp()}));
});


test('new role requires server confirmation and clients cannot forge or clear it', async () => {
  const db = env.authenticatedContext('driver', {email_verified:true,email:'driver@example.com'}).firestore();
  await assertFails(updateDoc(doc(db,'users/driver'),{roles:['driver','provider'],lastRole:'provider'}));
  await assertSucceeds(updateDoc(doc(db,'users/driver'),{roles:['driver','provider'],roleEmailRequired:['provider'],lastRole:'provider',online:false}));
  await assertFails(updateDoc(doc(db,'users/driver'),{roleEmailRequired:[]}));
  await assertFails(setDoc(doc(db,'roleEmailVerifications/driver'),{provider:{email:'driver@example.com'}}));
  await assertFails(getDoc(doc(db,'roleEmailChallenges/private-token')));
  await assertFails(setDoc(doc(db,'providerApplications/driver'),application()));
  await assertSucceeds(getDoc(doc(db,'requests/r1'))); // Existing driver role remains usable.
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(),'roleEmailVerifications/driver'),{provider:{email:'wrong@example.com'}}));
  await assertFails(setDoc(doc(db,'providerApplications/driver'),application()));
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(),'roleEmailVerifications/driver'),{provider:{email:'driver@example.com'}}));
  await assertSucceeds(setDoc(doc(db,'providerApplications/driver'),application()));
});

test('role identities protect contact email, enrollment and identity metadata', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await setDoc(doc(c.firestore(),'users/isolated'),{role:'driver',roles:['driver'],lastRole:'driver',
      authIdentity:'role-v1',email:'same@example.com',displayName:'Driver Name',phone:'+94771234567',online:false});
  });
  const db=env.authenticatedContext('isolated',{email_verified:true,email:'internal@roles.roadassist.invalid'}).firestore();
  const ref=doc(db,'users/isolated');
  await assertSucceeds(updateDoc(ref,{displayName:'Updated Driver',updatedAt:serverTimestamp()}));
  for (const change of [{email:'attacker@example.com'},{authIdentity:'legacy'},{roles:['driver','provider']},
    {lastRole:'provider'},{roleEmailRequired:['provider']}]) await assertFails(updateDoc(ref,change));
  await assertFails(getDoc(doc(db,'roleAuthLimits/private')));
});
