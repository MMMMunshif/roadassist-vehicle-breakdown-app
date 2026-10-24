import assert from 'node:assert/strict';
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore,FieldValue,Timestamp} from 'firebase-admin/firestore';
import {createGuestHandler} from '../../api/guest-assistance.mjs';
import {createBillingHandler} from '../../api/visit-billing.mjs';
const project='demo-roadassist-guest';
assert(process.env.FIRESTORE_EMULATOR_HOST&&process.env.FIREBASE_AUTH_EMULATOR_HOST,'Emulators required');
initializeApp({projectId:project});const auth=getAuth(),db=getFirestore();
const base=`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`;
async function post(path,body){const response=await fetch(`${base}/identitytoolkit.googleapis.com/v1/${path}?key=emulator-key`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const data=await response.json();assert.equal(response.status,200,JSON.stringify(data));return data;}
async function phone(number){const start=await post('accounts:sendVerificationCode',{phoneNumber:number});const codes=await(await fetch(`${base}/emulator/v1/projects/${project}/verificationCodes`)).json();const code=codes.verificationCodes.find(c=>c.sessionInfo===start.sessionInfo);assert(code);return post('accounts:signInWithPhoneNumber',{sessionInfo:start.sessionInfo,code:code.code});}
const admin={auth,db,FieldValue,Timestamp};const guest=createGuestHandler({loadAdmin:async()=>admin,enabled:()=>true});const billing=createBillingHandler({loadAdmin:async()=>admin});
async function call(handler,token,action,body={},expected=200){const res={setHeader(){},status(code){this.code=code;return this;},json(data){this.body=data;return this;},end(){}};await handler({method:'POST',headers:{authorization:`Bearer ${token}`},body:{action,...body}},res);assert.equal(res.code,expected,`${action}: ${JSON.stringify(res.body)}`);return res.body;}
const identity=await phone('+94771234567'),token=identity.idToken,uid=identity.localId;
const created=await call(guest,token,'bootstrap',{name:'Guest test driver'});assert.equal(created.requestId,null);
await auth.createUser({uid:'provider',email:'provider@example.test',emailVerified:true,password:'EmulatorOnly123!'});
const provider=(await post('accounts:signInWithPassword',{email:'provider@example.test',password:'EmulatorOnly123!',returnSecureToken:true})).idToken;
await Promise.all([
 db.doc('users/provider').set({role:'provider',displayName:'Provider test',phone:'+94777654321'}),
 db.doc('accountModeration/provider').set({status:'active',verification:'verified',verificationRevision:1,validUntil:Timestamp.fromMillis(Date.now()+86400000)}),
 db.doc('providerApplications/provider').set({revision:1,professionalDetails:{workHistory:'Test',qualification:'Test',tools:'Test',businessPhone:'+94777654321'}}),
 db.doc('providerDirectory/provider').set({displayName:'Provider test',online:true,available24Hours:true,services:['Flat Tyre'],vehicleTypes:['Sedan / Hatchback'],latitude:7.4,longitude:81.84,locationUpdatedAt:Timestamp.now()}),
]);
const draft={issue:'Flat Tyre',vehicleType:'Sedan / Hatchback',registration:'TEST-1234',latitude:7.4,longitude:81.84};
assert.equal((await call(guest,token,'providers',draft)).providers.length,1);
const quote=await call(guest,token,'prepare',{providerId:'provider',latitude:7.4,longitude:81.84});
const input={...draft,submissionId:'guest-job',providerId:'provider',quoteId:quote.quoteId};
await call(guest,token,'create',input);await call(guest,token,'create',input);
await call(guest,token,'create',{...input,submissionId:'duplicate-job'},409);
await call(billing,provider,'accept',{requestId:'guest-job'});
await db.doc('requests/guest-job').update({status:'arrived'});
await call(guest,token,'arrive',{requestId:'guest-job'});
await call(guest,token,'message',{requestId:'guest-job',text:'I am next to the shop.'});
const work={requestId:'guest-job',inspectionFee:300,labourFee:1500,summary:'Tyre repaired and approved valve replaced.',items:[{label:'Valve',reason:'Damaged valve replacement',amount:500}]};
await call(billing,provider,'estimate',work);
await call(guest,token,'decide_estimate',{requestId:'guest-job',revision:1,approve:true});
await call(billing,provider,'bill',work);
await call(guest,token,'checkout',{requestId:'guest-job',checkoutMethod:'demo_card',expectedFinalCost:2400},403);
await call(guest,token,'checkout',{requestId:'guest-job',checkoutMethod:'cash',expectedFinalCost:2400});
let job=(await call(guest,token,'read',{requestId:'guest-job'})).job;
assert.equal(job.driverReportedPayment,true);assert.notEqual(job.providerConfirmedPayment,true);
await db.doc('requests/guest-job').update({providerConfirmedPayment:true});
job=(await call(guest,token,'read',{requestId:'guest-job'})).job;assert.equal(job.providerConfirmedPayment,true);
const recovered=await phone('+94771234567');assert.equal(recovered.localId,uid);
assert.equal((await call(guest,recovered.idToken,'bootstrap',{})).requestId,'guest-job');
const outsider=await phone('+94771234568');await call(guest,outsider.idToken,'bootstrap',{name:'Other test driver'});
await call(guest,outsider.idToken,'read',{requestId:'guest-job'},403);
// A phone guest cannot use member Firestore access to read another profile.
const denied=await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents/users/provider`,{headers:{Authorization:`Bearer ${token}`}});
assert.equal(denied.status,403);
// Linking an email manually must not turn a guest profile into member Firestore access.
await auth.updateUser(uid,{email:'guestproof@example.test',emailVerified:true,password:'EmulatorOnly456!'});
const linked=(await post('accounts:signInWithPassword',{email:'guestproof@example.test',password:'EmulatorOnly456!',returnSecureToken:true})).idToken;
const stillDenied=await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents/requests/guest-job`,{headers:{Authorization:`Bearer ${linked}`}});
assert.equal(stillDenied.status,403);
console.log(JSON.stringify({checks:'emulated SMS proof, guest request, provider acceptance, arrival, message, parts approval, bill, pending cash receipt, receipt confirmation, OTP recovery, isolation and direct Firestore denial passed',production_data_used:false,real_sms_sent:false}));
await db.terminate();
