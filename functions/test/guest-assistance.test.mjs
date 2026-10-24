import test from 'node:test';import assert from 'node:assert/strict';
import {createGuestHandler} from '../../api/guest-assistance.mjs';
import {createBillingHandler} from '../../api/visit-billing.mjs';
import {phoneActor,guestDraft} from '../guest-policy.mjs';
process.env.GUEST_REQUESTS_ENABLED='true';
function fixture(){
 const docs=new Map(), now=Date.now(),ts=n=>({toMillis:()=>n});let seq=0;
 let actor={uid:'guest',phone_number:'+94771234567',firebase:{sign_in_provider:'phone'},email_verified:false};
 function ref(path){return {path,id:path.split('/').at(-1),get:async()=>snap(path),collection:n=>collection(`${path}/${n}`)};}
 function snap(path){return {exists:docs.has(path),data:()=>docs.get(path),id:path.split('/').at(-1),ref:ref(path)};}
 function collection(path){const query={doc:id=>ref(`${path}/${id??`auto${++seq}`}`),where:(key,op,v)=>({...query,get:async()=>({docs:[...docs.keys()].filter(k=>k.startsWith(path+'/')&&k.split('/').length===path.split('/').length+1&&docs.get(k)[key]===v).map(snap)})}),orderBy:()=>query,limit:()=>query,get:async()=>({docs:[...docs.keys()].filter(k=>k.startsWith(path+'/')&&k.split('/').length===path.split('/').length+1).map(snap)})};return query;}
 const db={doc:ref,collection,runTransaction:async fn=>{const writes=[];const result=await fn({get:async r=>snap(r.path),set:(r,d)=>writes.push(()=>docs.set(r.path,d)),update:(r,d)=>writes.push(()=>docs.set(r.path,{...docs.get(r.path),...d}))});writes.forEach(w=>w());return result;}};
 const admin={db,auth:{verifyIdToken:async()=>actor,createCustomToken:async(uid,claims)=>`token:${uid}:${claims.guestSession}`},Timestamp:{now:()=>ts(Date.now()),fromMillis:ts},FieldValue:{serverTimestamp:()=>ts(Date.now()),delete:()=>null}};
 const handler=createGuestHandler({loadAdmin:async()=>admin,enabled:()=>true});const billing=createBillingHandler({loadAdmin:async()=>admin});
 async function call(action,body={},use=handler){const res={code:0,setHeader(){},status(n){this.code=n;return this;},json(v){this.body=v;return this;},end(){return this;}};await use({method:'POST',headers:{authorization:'Bearer proof'},body:{action,...body}},res);return res;}
 const draft={issue:'Flat Tyre',vehicleType:'Sedan / Hatchback',registration:'CAB-1234',latitude:7.4,longitude:81.84};
 function provider(){docs.set('providerDirectory/provider',{online:true,available24Hours:true,locationUpdatedAt:ts(Date.now()),latitude:7.401,longitude:81.84,services:['Flat Tyre'],vehicleTypes:['Sedan / Hatchback'],displayName:'Provider'});docs.set('accountModeration/provider',{status:'active',verification:'verified',validUntil:ts(now+86400000),verificationRevision:1});docs.set('providerApplications/provider',{revision:1});}
 async function bootstrap(){assert.equal((await call('bootstrap',{name:'Guest Driver',phone:'+94771234567'})).code,200);}
 async function create(){await bootstrap();provider();const q=await call('prepare',{providerId:'provider',latitude:draft.latitude,longitude:draft.longitude});assert.equal(q.code,200,q.body?.message);const body={...draft,submissionId:'job',providerId:'provider',quoteId:q.body.quoteId};const result=await call('create',body);assert.equal(result.code,200,result.body?.message);return body;}
 return {docs,call,draft,create,bootstrap,provider,billing,setActor:v=>actor=v};
}
test('only an SMS-provider phone proof is a guest identity',()=>{
 assert.equal(phoneActor({phone_number:'+94771234567',firebase:{sign_in_provider:'password'}}),false);
 assert.equal(phoneActor({phone_number:'+94771234567',firebase:{sign_in_provider:'phone'}}),true);
 assert.throws(()=>guestDraft({issue:'Admin',vehicleType:'SUV',latitude:0,longitude:0,registration:'ABC'}));
});
test('feature is closed without activation',async()=>{
 const h=createGuestHandler({enabled:()=>false,loadAdmin:async()=>{throw Error('must not load')}}),res={setHeader(){},status(c){this.code=c;return this},json(v){this.body=v},end(){}};
 await h({method:'GET'},res);assert.equal(res.body.enabled,false);
 await h({method:'POST'},res);assert.equal(res.code,503);
});
test('bootstrap cannot overwrite a member account or trust a body phone',async()=>{
 const f=fixture();f.docs.set('users/guest',{role:'provider',displayName:'Member'});
 assert.equal((await f.call('bootstrap',{name:'Other',phone:'+94779999999'})).code,409);
 assert.equal(f.docs.get('users/guest').role,'provider');
 f.docs.clear();await f.bootstrap();assert.equal(f.docs.get('users/guest').phone,'+94771234567');assert.equal(f.docs.get('users/guest').role,'guest');
});
test('create is idempotent, scoped and blocks a second active request',async()=>{
 const f=fixture(),input=await f.create();
 assert.equal((await f.call('create',input)).code,200);
 assert.equal((await f.call('create',{...input,submissionId:'other'})).code,409);
 assert.equal((await f.call('read',{requestId:'other'})).code,403);
 assert.equal((await f.call('read',{requestId:'job'})).code,200);
 f.docs.set('guestSessions/guest',{enabled:true,phone:'+94779999999',currentRequestId:'job'});
 assert.equal((await f.call('read',{requestId:'job'})).code,403);
});
test('phone impostors and suspended guests cannot recover or use requests',async()=>{
 const f=fixture();await f.create();f.setActor({uid:'guest',phone_number:'+94771234567',firebase:{sign_in_provider:'password'},email_verified:true});
 assert.equal((await f.call('read',{requestId:'job'})).code,403);
 f.setActor({uid:'guest',phone_number:'+94771234567',firebase:{sign_in_provider:'phone'}});f.docs.set('accountModeration/guest',{status:'suspended'});
 assert.equal((await f.call('bootstrap',{name:'Guest'})).code,403);
});
test('no signed fee can be reused for another location or owner',async()=>{
 const f=fixture();await f.bootstrap();f.provider();const q=await f.call('prepare',{providerId:'provider',latitude:7.4,longitude:81.84});
 assert.equal((await f.call('create',{...f.draft,submissionId:'job',providerId:'provider',quoteId:q.body.quoteId,latitude:8})).code,409);
 assert.equal(f.docs.has('requests/job'),false);
});
test('guest cannot accept provider jobs, pay by demo card, or access another bill',async()=>{
 const f=fixture();await f.create();
 assert.equal((await f.call('accept',{requestId:'job'},f.billing)).code,403);
 assert.equal((await f.call('checkout',{requestId:'job',checkoutMethod:'demo_card',expectedFinalCost:100},f.billing)).code,403);
 assert.equal((await f.call('correct',{requestId:'other',reason:'Correct this charge please.'},f.billing)).code,403);
});
test('arrival and cancellation follow service state',async()=>{
 const f=fixture();await f.create();assert.equal((await f.call('arrive',{requestId:'job'})).code,409);
 Object.assign(f.docs.get('requests/job'),{status:'arrived',providerId:'provider'});
 assert.equal((await f.call('arrive',{requestId:'job'})).code,200);
 assert.equal(f.docs.get('requests/job').arrivalConfirmedBy,'guest');
 assert.equal((await f.call('cancel',{requestId:'job',reason:'No longer needed now.'})).code,409);
});
test('cash checkout keeps receipt pending and supports provider receipt later',async()=>{
 const f=fixture();await f.create();Object.assign(f.docs.get('requests/job'),{status:'arrived',providerId:'provider',arrivalConfirmedBy:'guest',finalCost:1900,completionState:'pending'});
 const r=await f.call('checkout',{requestId:'job',checkoutMethod:'cash',expectedFinalCost:1900},f.billing);assert.equal(r.code,200,r.body?.message);
 assert.equal(f.docs.get('requests/job').driverReportedPayment,true);assert.notEqual(f.docs.get('requests/job').providerConfirmedPayment,true);
 assert.equal((await f.call('bootstrap',{name:'Guest'})).body.requestId,'job');
});

test('maintenance pauses new guest requests without creating a document',async()=>{
 const f=fixture();await f.bootstrap();f.provider();const q=await f.call('prepare',{providerId:'provider',latitude:7.4,longitude:81.84});
 f.docs.set('appSettings/operations',{maintenance:true});
 assert.equal((await f.call('create',{...f.draft,submissionId:'job',providerId:'provider',quoteId:q.body.quoteId})).code,409);
 assert.equal(f.docs.has('requests/job'),false);
});

test('verified member accounts are not reclassified as guests by a linked phone',async()=>{
 const f=fixture();f.provider();f.docs.set('users/guest',{role:'driver',displayName:'Member',phone:'+94771234567'});
 f.setActor({uid:'guest',email:'member@example.test',email_verified:true,phone_number:'+94771234567',firebase:{sign_in_provider:'phone'}});
 assert.equal((await f.call('prepare',{providerId:'provider',latitude:7.4,longitude:81.84},f.billing)).code,200);
});

test('anonymous guest uses unverified contact and a secret recovery capability',async()=>{
 const f=fixture();f.setActor({uid:'guest',firebase:{sign_in_provider:'anonymous'}});
 assert.equal((await f.call('bootstrap',{name:'Driver'})).code,400);
 const b=await f.call('bootstrap',{name:'Driver',phone:'+94771234567'});
 assert.equal(b.code,200);assert.match(b.body.recoveryCode,/^gs_[a-f0-9]{64}$/);
 assert.equal(f.docs.get('users/guest').phoneVerified,false);
 const second=await f.call('bootstrap');assert.equal(second.body.recoveryCode,undefined);
 f.setActor({uid:'other',firebase:{sign_in_provider:'anonymous'}});
 assert.equal((await f.call('read',{requestId:'job'})).code,403);
 assert.equal((await f.call('recover',{recoveryCode:'+94771234567'})).code,403);
 assert.equal((await f.call('recover',{recoveryCode:'gs_'+'0'.repeat(64)})).code,403);
 const recovered=await f.call('recover',{recoveryCode:b.body.recoveryCode});
 assert.equal(recovered.code,200);assert.equal(recovered.body.token,'token:guest:true');
 f.docs.set('accountModeration/guest',{status:'suspended'});
 assert.equal((await f.call('recover',{recoveryCode:b.body.recoveryCode})).code,403);
});

test('anonymous requests keep billing and contact scoped to the guest',async()=>{
 const f=fixture();f.setActor({uid:'guest',firebase:{sign_in_provider:'anonymous'}});
 await f.create();const job=f.docs.get('requests/job');
 assert.equal(job.driverPhone,'+94771234567');assert.equal(job.driverPhoneVerified,false);
 assert.equal((await f.call('read',{requestId:'job'})).code,200);
 assert.equal((await f.call('accept',{requestId:'job'},f.billing)).code,403);
 assert.equal((await f.call('checkout',{requestId:'job',checkoutMethod:'demo_card'},f.billing)).code,403);
 f.setActor({uid:'guest',firebase:{sign_in_provider:'custom'},guestSession:true});
 assert.equal((await f.call('read',{requestId:'job'})).code,200);
 f.setActor({uid:'guest',firebase:{sign_in_provider:'custom'}});
 assert.equal((await f.call('read',{requestId:'job'})).code,403);
});
