import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createBillingHandler} from '../../api/visit-billing.mjs';
const require=createRequire(new URL('../../functions/package.json',import.meta.url));
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore,FieldValue,Timestamp}=require('firebase-admin/firestore');
test('real Firestore transactions accept one job, submit a bill and correct it without duplicate assignment', {skip:!process.env.FIRESTORE_TEST_PORT}, async()=>{
  process.env.FIRESTORE_EMULATOR_HOST=`127.0.0.1:${process.env.FIRESTORE_TEST_PORT}`;
  const app=initializeApp({projectId:'demo-roadassist'},'visit-billing-integration');
  const db=getFirestore(app),prefix='billing-test';
  let actor={uid:`${prefix}-driver`,email_verified:true,email:'driver@example.com'};
  const providerId=`${prefix}-provider`,driverId=actor.uid, now=Date.now();
  const paths=[`users/${driverId}`,`users/${providerId}`,`providerApplications/${providerId}`,`accountModeration/${providerId}`,`providerDirectory/${providerId}`,`requests/${prefix}-job`,`requests/${prefix}-job2`];
  const quotes=[];
  try {
    await Promise.all([
      db.doc(`users/${driverId}`).set({role:'driver'}), db.doc(`users/${providerId}`).set({role:'provider',displayName:'Test mechanic',phone:''}),
      db.doc(`providerApplications/${providerId}`).set({revision:1,applicationStatus:'submitted'}),
      db.doc(`accountModeration/${providerId}`).set({status:'active',verification:'verified',verificationRevision:1,validUntil:Timestamp.fromMillis(now+86400000)}),
      db.doc(`providerDirectory/${providerId}`).set({online:true,services:['General Mechanic'],vehicleTypes:['Sedan / Hatchback'],latitude:7.39,longitude:81.84,locationUpdatedAt:Timestamp.now(),serviceRadius:'20 km'}),
    ]);
    const handler=createBillingHandler({loadAdmin:async()=>({db,auth:{verifyIdToken:async()=>actor},FieldValue,Timestamp})});
    async function call(action,values,uid=driverId) {
      actor={uid,email_verified:true,email:`${uid}@example.com`};
      const res={setHeader(){},status(code){this.code=code;return this;},json(body){this.body=body;return this;},end(){return this;}};
      await handler({method:'POST',headers:{authorization:'Bearer emulator-test'},body:{action,...values}},res);return res;
    }
    const fee=await call('prepare',{providerId,latitude:7.4,longitude:81.84});assert.equal(fee.code,200,JSON.stringify(fee.body));quotes.push(`visitFeeQuotes/${fee.body.quoteId}`);
    const job={workflowVersion:3,driverId,providerId:null,preferredProviderId:providerId,status:'searching',issues:['General Mechanic'],vehicleType:'Sedan / Hatchback',latitude:7.4,longitude:81.84,dispatchFee:fee.body.visitFee,estimatedCost:fee.body.visitFee,visitFeeQuoteId:fee.body.quoteId,createdAt:Timestamp.now()};
    await Promise.all([db.doc(`requests/${prefix}-job`).set(job),db.doc(`requests/${prefix}-job2`).set(job)]);
    const results=await Promise.all([call('accept',{requestId:`${prefix}-job`},providerId),call('accept',{requestId:`${prefix}-job2`},providerId)]);
    assert.deepEqual(results.map(r=>r.code).sort(),[200,409]);
    const requestId=(await db.doc(`providerDirectory/${providerId}`).get()).data().activeRequestId;
    await db.doc(`requests/${requestId}`).update({status:'arrived',arrivalConfirmedBy:driverId});
    const bill={requestId,inspectionFee:200,labourFee:500,items:[{label:'Battery',reason:'Failed load test',amount:8000}],summary:'Battery replaced and engine tested.'};
    assert.equal((await call('bill',bill,providerId)).code,200);
    let saved=(await db.doc(`requests/${requestId}`).get()).data();assert.equal(saved.finalCost,fee.body.visitFee+8700);assert.equal(saved.completionState,'pending');assert.equal(saved.driverReportedPayment,undefined);assert.equal(saved.billRevision,1);
    assert.equal((await call('correct',{requestId,reason:'Please correct the labour charge.'})).code,200);
    assert.equal((await call('bill',{...bill,labourFee:400},providerId)).code,200);
    saved=(await db.doc(`requests/${requestId}`).get()).data();assert.equal(saved.billRevision,2);assert.equal(saved.finalCost,fee.body.visitFee+8600);assert.equal((await db.doc(`providerDirectory/${providerId}`).get()).data().online,true);
    const checkout={requestId,expectedFinalCost:saved.finalCost,checkoutMethod:'cash'};
    assert.equal((await call('checkout',checkout)).code,200);
    saved=(await db.doc(`requests/${requestId}`).get()).data();
    assert.equal(saved.status,'completed');assert.equal(saved.driverReportedPayment,true);assert.equal(saved.providerConfirmedPayment,undefined);
    assert.equal((await db.doc(`providerDirectory/${providerId}`).get()).data().activeRequestId,null);
    assert.equal((await db.doc(`users/${providerId}`).get()).data().activeRequestId,null);
    assert.equal((await call('checkout',checkout)).code,200);
  } finally {
    for(const path of [...paths,...quotes]) await db.recursiveDelete(db.doc(path));
    await deleteApp(app);
  }
});
