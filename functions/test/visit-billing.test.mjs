import test from 'node:test';
import assert from 'node:assert/strict';
import {visitFee,distanceKm,finalBill} from '../visit-billing-policy.mjs';
import {createBillingHandler} from '../../api/visit-billing.mjs';
const ts=ms=>({toMillis:()=>ms});
function fixture() {
  const now=Date.now();
  const docs=new Map([
    ['users/driver',{role:'driver',displayName:'Driver'}],['users/provider',{role:'provider',displayName:'Mechanic',phone:'+94771234567'}],
    ['providerApplications/provider',{revision:1,applicationStatus:'submitted'}],
    ['accountModeration/provider',{status:'active',verification:'verified',verificationRevision:1,validUntil:ts(now+86400000)}],
    ['providerDirectory/provider',{online:true,services:['General Mechanic'],vehicleTypes:['Sedan / Hatchback'],serviceRadius:'20 km',latitude:7.39,longitude:81.84,locationUpdatedAt:ts(now)}],
  ]);
  let seq=0;
  const ref=path=>({path,id:path.split('/').at(-1),collection:name=>({doc:id=>ref(`${path}/${name}/${id??++seq}`)})});
  const db={doc:ref,collection:name=>({doc:id=>ref(`${name}/${id??++seq}`)}),runTransaction:async fn=>{
    const writes=[];let wrote=false;
    const result=await fn({get:async r=>{assert.equal(wrote,false,'read after write');return {exists:docs.has(r.path),data:()=>docs.get(r.path)};},set:(r,d)=>{wrote=true;writes.push(()=>docs.set(r.path,d));},update:(r,d)=>{wrote=true;writes.push(()=>{assert.ok(docs.has(r.path));docs.set(r.path,{...docs.get(r.path),...d});});}});
    writes.forEach(w=>w());return result;
  }};
  let actor={uid:'driver',email:'driver@example.com',email_verified:true};
  const handler=createBillingHandler({loadAdmin:async()=>({db,auth:{verifyIdToken:async()=>actor},FieldValue:{serverTimestamp:()=>ts(Date.now())},Timestamp:{fromMillis:ts}})});
  async function call(action,values={},uid='driver') {
    actor={...actor,uid,email:`${uid}@example.com`};
    const res={setHeader(){},status(code){this.code=code;return this;},json(body){this.body=body;return this;},end(){return this;}};
    await handler({method:'POST',headers:{authorization:'Bearer test'},body:{action,...values}},res);return res;
  }
  async function request() {
    const prepared=await call('prepare',{providerId:'provider',latitude:7.40,longitude:81.84});assert.equal(prepared.code,200);
    docs.set('requests/job',{workflowVersion:3,driverId:'driver',preferredProviderId:'provider',providerId:null,status:'searching',issues:['General Mechanic'],vehicleType:'Sedan / Hatchback',latitude:7.40,longitude:81.84,dispatchFee:prepared.body.visitFee,estimatedCost:prepared.body.visitFee,visitFeeQuoteId:prepared.body.quoteId,createdAt:ts(Date.now()),arrivalVerificationRequired:true});
    return prepared.body;
  }
  async function arrived(){await request();assert.equal((await call('accept',{requestId:'job'},'provider')).code,200);Object.assign(docs.get('requests/job'),{status:'arrived',arrivalConfirmedBy:'driver'});}
  return {docs,call,request,arrived,setVerified:v=>{actor.email_verified=v;}};
}
const bill={requestId:'job',inspectionFee:200,labourFee:500,summary:'Battery tested and replaced successfully.',items:[{label:'Battery',reason:'Old battery failed the load test',amount:8000}]};
test('visit tariff covers first kilometre and rounds additional kilometres up',()=>{for(const [km,fee] of [[0,100],[0.99,100],[1,100],[1.01,120],[2,120],[2.01,140],[10,280]])assert.equal(visitFee(km),fee);for(const km of [-1,NaN,Infinity,501])assert.throws(()=>visitFee(km));assert.equal(distanceKm({latitude:7,longitude:81},{latitude:7,longitude:81}),0);assert.throws(()=>distanceKm({latitude:91,longitude:0},{latitude:0,longitude:0}));});
test('bill arithmetic preserves locked visit fee and validates parts reasons',()=>{assert.equal(finalBill({dispatchFee:120},bill).finalCost,8820);for(const bad of [{inspectionFee:-1},{labourFee:1.2},{items:[{label:'Battery',reason:'',amount:500}]},{items:Array(11).fill(bill.items[0])},{summary:'short'},{items:[{...bill.items[0],amount:10000001}]}])assert.throws(()=>finalBill({dispatchFee:120},{...bill,...bad}));});
test('request accepted directly at locked automatic fee; repeat accept is safe',async()=>{const f=fixture();const quote=await f.request();f.docs.get('providerDirectory/provider').latitude=7.42;assert.equal((await f.call('accept',{requestId:'job'},'provider')).code,200);const job=f.docs.get('requests/job');assert.equal(job.dispatchFee,quote.visitFee);assert.equal(job.status,'accepted');assert.equal(f.docs.get('providerDirectory/provider').online,true);assert.equal(f.docs.get('providerDirectory/provider').activeRequestId,'job');assert.equal((await f.call('accept',{requestId:'job'},'provider')).code,200);});
test('fee tampering and changed request coordinates cannot be accepted',async()=>{for(const change of [{dispatchFee:1},{latitude:0},{preferredProviderId:'wrong'}]){const f=fixture();await f.request();Object.assign(f.docs.get('requests/job'),change);assert.equal((await f.call('accept',{requestId:'job'},'provider')).code,409);assert.equal(f.docs.get('requests/job').status,'searching');}});
test('busy, offline and expired provider approval block acceptance',async()=>{for(const change of [{online:false},{activeRequestId:'other'},{locationUpdatedAt:ts(Date.now()-121000)}]){const f=fixture();await f.request();Object.assign(f.docs.get('providerDirectory/provider'),change);assert.equal((await f.call('accept',{requestId:'job'},'provider')).code,409);}const f=fixture();await f.request();f.docs.get('accountModeration/provider').status='suspended';assert.equal((await f.call('accept',{requestId:'job'},'provider')).code,403);});
test('driver cannot send a bill and provider cannot bill before arrival confirmation',async()=>{const f=fixture();await f.arrived();assert.equal((await f.call('bill',bill)).code,403);delete f.docs.get('requests/job').arrivalConfirmedBy;assert.equal((await f.call('bill',bill,'provider')).code,409);assert.equal(f.docs.has('requests/job/billRevisions/1'),false);});
test('one itemized final bill, driver correction, then revised bill preserves audit',async()=>{const f=fixture();await f.arrived();const visit=f.docs.get('requests/job').dispatchFee;assert.equal((await f.call('bill',bill,'provider')).code,200);assert.equal(f.docs.get('requests/job').finalCost,visit+8700);assert.equal(f.docs.get('requests/job').completionState,'pending');assert.equal(f.docs.get('requests/job').driverReportedPayment,undefined);assert.equal((await f.call('bill',bill,'provider')).code,409);assert.equal((await f.call('correct',{requestId:'job',reason:'Please correct the labour amount.'})).code,200);assert.equal((await f.call('bill',{...bill,labourFee:400},'provider')).code,200);assert.equal(f.docs.get('requests/job').finalCost,visit+8600);assert.equal(f.docs.get('requests/job').billRevision,2);assert.equal(f.docs.get('requests/job/billRevisions/1').serviceFee,500);});
test('completed bill is immutable and unverified users cannot prepare visits',async()=>{const f=fixture();await f.arrived();f.docs.get('requests/job').status='completed';assert.equal((await f.call('bill',bill,'provider')).code,409);f.setVerified(false);assert.equal((await f.call('prepare',{providerId:'provider',latitude:7.4,longitude:81.84})).code,403);});
test('provider dismiss cancels only its targeted pending request',async()=>{const f=fixture();await f.request();assert.equal((await f.call('dismiss',{requestId:'job'},'provider')).code,200);assert.equal(f.docs.get('requests/job').status,'cancelled');assert.equal(f.docs.get('requests/job').cancellationType,'provider_declined');assert.equal(f.docs.get('providerDirectory/provider').online,true);});

test('legacy secondary provider role requires its own verified email',async()=>{
  const f=fixture();await f.request();Object.assign(f.docs.get('users/provider'),{role:'driver',roles:['driver','provider'],roleEmailRequired:['provider']});
  assert.equal((await f.call('accept',{requestId:'job'},'provider')).code,403);
  f.docs.set('roleEmailVerifications/provider',{provider:{email:'provider@example.com'}});
  assert.equal((await f.call('accept',{requestId:'job'},'provider')).code,200);
});

for (const checkoutMethod of ['cash','external','demo_card']) test(`server checkout completes ${checkoutMethod} atomically and retries safely`,async()=>{
 const f=fixture();await f.arrived();await f.call('bill',bill,'provider');const total=f.docs.get('requests/job').finalCost;
 const input={requestId:'job',expectedFinalCost:total,checkoutMethod};
 assert.equal((await f.call('checkout',input)).code,200);
 const j=f.docs.get('requests/job');assert.equal(j.status,'completed');assert.equal(j.completionState,'confirmed');assert.equal(j.paymentMethod,checkoutMethod);
 assert.equal(j.providerConfirmedPayment,undefined);assert.equal(j.driverReportedPayment,checkoutMethod==='demo_card'?undefined:true);
 assert.equal(f.docs.get('providerDirectory/provider').activeRequestId,null);assert.equal(f.docs.get('users/provider').activeRequestId,null);assert.equal(f.docs.get('providerDirectory/provider').online,true);
 assert.equal((await f.call('checkout',input)).code,200);assert.equal((await f.call('checkout',{...input,checkoutMethod:checkoutMethod==='cash'?'external':'cash'})).code,409);
});
test('checkout rejects foreign driver, stale totals, pending discounts and unresolved complaints',async()=>{
 const f=fixture();await f.arrived();await f.call('bill',bill,'provider');const job=f.docs.get('requests/job');const input={requestId:'job',expectedFinalCost:job.finalCost,checkoutMethod:'cash'};
 assert.equal((await f.call('checkout',input,'provider')).code,403);
 assert.equal((await f.call('checkout',{...input,expectedFinalCost:1})).code,409);
 job.pendingDiscountId='discount';assert.equal((await f.call('checkout',input)).code,409);delete job.pendingDiscountId;
 f.docs.set('requests/job/disputes/case',{reason:'Unfinished work'});assert.equal((await f.call('checkout',input)).code,409);
 assert.equal(f.docs.get('requests/job').status,'arrived');f.docs.set('complaintReviews/job',{status:'resolved'});assert.equal((await f.call('checkout',input)).code,200);
});
test('checkout tolerates a stale empty lock and preserves another active job lock',async()=>{
 for(const lock of [undefined,'','another-job']) {const f=fixture();await f.arrived();await f.call('bill',bill,'provider');f.docs.get('providerDirectory/provider').activeRequestId=lock;f.docs.get('users/provider').activeRequestId=lock;
 assert.equal((await f.call('checkout',{requestId:'job',expectedFinalCost:f.docs.get('requests/job').finalCost,checkoutMethod:'cash'})).code,200);
 assert.equal(f.docs.get('providerDirectory/provider').activeRequestId,lock);assert.equal(f.docs.get('users/provider').activeRequestId,lock);}
});

test('parts need advance approval and approved work caps each bill line',async()=>{
 const f=fixture();await f.arrived();f.docs.get('requests/job').workApprovalRequired=true;
 assert.equal((await f.call('bill',bill,'provider')).code,409);
 assert.equal((await f.call('estimate',bill,'provider')).code,200);
 assert.equal(f.docs.get('requests/job').completionState,undefined);
 const revision=f.docs.get('requests/job').workEstimate.revision;
 assert.equal((await f.call('bill',bill,'provider')).code,409);
 assert.equal((await f.call('decide_estimate',{requestId:'job',revision,approve:true},'provider')).code,403);
 assert.equal((await f.call('decide_estimate',{requestId:'job',revision:revision+1,approve:true})).code,409);
 assert.equal((await f.call('decide_estimate',{requestId:'job',revision,approve:true})).code,200);
 for(const changes of [{labourFee:501},{inspectionFee:201},{items:[{...bill.items[0],label:'Unapproved part'}]},{items:[bill.items[0],bill.items[0]]}]) assert.equal((await f.call('bill',{...bill,...changes},'provider')).code,409);
 assert.equal((await f.call('bill',{...bill,labourFee:400},'provider')).code,200);
 assert.ok(f.docs.get('requests/job').serviceCompletedAt);
 assert.equal(f.docs.get('requests/job').status,'arrived');
 assert.equal(f.docs.get('requests/job').driverReportedPayment,undefined);
 assert.equal(f.docs.get('providerDirectory/provider').activeRequestId,null);
 assert.equal(f.docs.get('users/provider').activeRequestId,null);
 assert.equal(f.docs.get('providerDirectory/provider').online,true);
});
test('declined or pending work cannot authorize replacement parts',async()=>{
 const f=fixture();await f.arrived();f.docs.get('requests/job').workApprovalRequired=true;
 await f.call('estimate',bill,'provider');
 assert.equal((await f.call('estimate',bill,'provider')).code,409);
 assert.equal((await f.call('decide_estimate',{requestId:'job',revision:1,approve:false})).code,200);
 assert.equal((await f.call('bill',bill,'provider')).code,409);
 assert.equal((await f.call('bill',{...bill,items:[],labourFee:0},'provider')).code,200);
});
test('finishing an old visit never releases the provider newer job lock',async()=>{
 const f=fixture();await f.arrived();f.docs.get('requests/job').workApprovalRequired=true;
 f.docs.get('providerDirectory/provider').activeRequestId='newer-job';f.docs.get('users/provider').activeRequestId='newer-job';
 assert.equal((await f.call('bill',{...bill,items:[]},'provider')).code,200);
 assert.equal(f.docs.get('providerDirectory/provider').activeRequestId,'newer-job');
 assert.equal(f.docs.get('users/provider').activeRequestId,'newer-job');
});
test('finished service corrections cannot increase an approved work budget',async()=>{
 const f=fixture();await f.arrived();f.docs.get('requests/job').workApprovalRequired=true;
 await f.call('estimate',bill,'provider');await f.call('decide_estimate',{requestId:'job',revision:1,approve:true});await f.call('bill',bill,'provider');
 await f.call('correct',{requestId:'job',reason:'Please check the labour charge.'});
 assert.equal((await f.call('estimate',bill,'provider')).code,409);
 assert.equal((await f.call('bill',{...bill,labourFee:700},'provider')).code,409);
 assert.equal((await f.call('bill',{...bill,labourFee:300},'provider')).code,200);
 assert.equal(f.docs.get('requests/job').billRevision,2);
});

test('numeric datastore failures return a retryable server response',async()=>{
 const handler=createBillingHandler({loadAdmin:async()=>{throw {code:14};}});
 const res={setHeader(){},status(code){this.code=code;return this;},json(body){this.body=body;return this;}};
 await handler({method:'POST',headers:{authorization:'Bearer test'},body:{action:'checkout',requestId:'job'}},res);
 assert.equal(res.code,500);assert.match(res.body.message,/retry/);
});

test('a stale profile reference to finished service does not block another visit',async()=>{
 const f=fixture();await f.request();f.docs.set('requests/old-visit',{status:'arrived',serviceCompletedAt:ts(Date.now()),completionState:'pending'});f.docs.get('users/provider').activeRequestId='old-visit';
 assert.equal((await f.call('accept',{requestId:'job'},'provider')).code,200);
 assert.equal(f.docs.get('requests/old-visit').completionState,'pending');
});
