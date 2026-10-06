import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, getDocs, collectionGroup, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';

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
  const db = env.authenticatedContext('driver').firestore();
  await assertSucceeds(setDoc(doc(db,'users/driver/vehicles/v1'),{make:'Toyota',model:'Aqua',year:2017,
    vehicleType:'Sedan / Hatchback',registration:'CAB-1234',fuelType:'Hybrid',transmission:'Automatic',archived:false,
    createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'users/driver/vehicles/v1')));
});
test('provider can submit an itemized offer but cannot assign a new-flow job', async () => {
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
  await assertSucceeds(setDoc(doc(db,'requests/r1/quotes/provider'),offer()));
  await assertFails(updateDoc(doc(db,'requests/r1'),{providerId:'provider',status:'accepted'}));
  await assertFails(setDoc(doc(db,'requests/r1/quotes/provider'),{...offer(),total:1}));
});
test('quote approval atomically reserves a provider and prevents a competing selection', async () => {
  await assertSucceeds(approval(env.authenticatedContext('driver').firestore(),'r1'));
  await assertFails(approval(env.authenticatedContext('other').firestore(),'r2'));
  await assertFails(updateDoc(doc(env.authenticatedContext('provider', {email_verified:true}).firestore(),'requests/r1/quotes/provider'),{total:9999}));
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
  await assertFails(updateDoc(doc(env.authenticatedContext('provider', {email_verified:true}).firestore(),'requests/r1'),{status:'completed',finalCost:2000,completedAt:serverTimestamp()}));
});
test('approved direct-service job progresses and releases its provider', async () => {
  await approval(env.authenticatedContext('driver').firestore(),'r1');
  const db = env.authenticatedContext('provider', {email_verified:true}).firestore();
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
  await assertFails(updateDoc(doc(env.authenticatedContext('provider', {email_verified:true}).firestore(),'providerDirectory/provider'),{activeRequestId:null}));
});
test('payment declarations are participant-only and do not alter invoice amounts', async () => {
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'requests/r1'),{status:'completed',providerId:'provider',finalCost:1500}));
  const driver = env.authenticatedContext('driver').firestore();
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
  const driver = env.authenticatedContext('driver').firestore();
  const provider = env.authenticatedContext('provider', {email_verified:true}).firestore();
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
  await assertFails(getDoc(doc(env.authenticatedContext('driver').firestore(),'users/other')));
});
test('moderation needs an atomic immutable audit and blocks suspended accounts',async()=>{
  const admin=administrator();
  await assertFails(setDoc(doc(admin,'accountModeration/driver'),{status:'suspended'}));
  await assertSucceeds(accountAction(admin,'driver',{status:'suspended'}));
  const driver=env.authenticatedContext('driver').firestore();
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
  await assertSucceeds(getDoc(doc(env.authenticatedContext('driver').firestore(),'complaintReviews/r1')));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'complaintReviews/r1')));
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
  await assertFails(approval(env.authenticatedContext('driver').firestore(),'r1'));
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
  await assertFails(getDoc(doc(env.authenticatedContext('driver').firestore(),'adminNotes/n1')));
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
  await assertFails(getDoc(doc(env.authenticatedContext('driver').firestore(), 'providerApplications/pending')));
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
  await assertFails(approval(env.authenticatedContext('driver').firestore(), 'r1'));
});
test('expired or email-unverified providers cannot take assistance jobs', async () => {
  await assertFails(getDoc(doc(env.authenticatedContext('provider').firestore(), 'requests/r1')));
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(), 'accountModeration/provider'), {validUntil: Timestamp.fromMillis(Date.now() - 1000)}));
  await assertFails(setDoc(doc(env.authenticatedContext('provider', providerToken).firestore(), 'requests/r1/quotes/provider'), offer()));
  await assertFails(approval(env.authenticatedContext('driver').firestore(), 'r1'));
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
  const db = env.authenticatedContext('driver').firestore();
  const request = {driverId: 'driver', driverName: 'Driver', driverPhone: '+94771234567', providerId: null, preferredProviderId: '', preferredProviderName: '', rejectedBy: [],
    status: 'searching', workflowVersion: 2, issue: 'Flat Tyre', issues: ['Flat Tyre'], vehicleType: 'Sedan / Hatchback', modelYear: 'Toyota Aqua 2018', registration: 'WP-1234',
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