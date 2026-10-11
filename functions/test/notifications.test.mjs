import {test} from 'node:test';
import assert from 'node:assert/strict';
import {providerMatches,requestAlerts,quoteChanged,messageRecipient} from '../notification_events.mjs';
test('only suitable online free providers receive new requests',()=>{
  const r={status:'searching',issues:['Flat Tyre','General Mechanic']};
  const p={online:true,services:['Flat Tyre','General Mechanic']};
  assert.equal(providerMatches(r,p,'p'),true);
  assert.equal(providerMatches(r,{...p,online:false},'p'),false);
  assert.equal(providerMatches(r,{...p,activeRequestId:'busy'},'p'),false);
  assert.equal(providerMatches(r,{...p,services:['Flat Tyre']},'p'),false);
  assert.equal(providerMatches({...r,preferredProviderId:'other'},p,'p'),false);
  assert.equal(providerMatches({...r,rejectedBy:['p']},p,'p'),false);
});
test('providers beyond the service radius are excluded',()=>{
  assert.equal(providerMatches({status:'searching',issue:'Flat Tyre',latitude:6.9,longitude:79.9},{online:true,latitude:7.5,longitude:81,serviceRadius:'15 km'},'p'),false);
});
test('messages on completed jobs notify the other participant only',()=>{
  const r={driverId:'driver',providerId:'provider',status:'completed'};
  assert.equal(messageRecipient(r,{senderId:'driver'}),'provider');
  assert.equal(messageRecipient(r,{senderId:'provider'}),'driver');
  assert.equal(messageRecipient(r,{senderId:'stranger'}),null);
});
test('price proposals notify driver and decisions notify provider',()=>{
  const before={driverId:'d',providerId:'p',status:'arrived'};
  assert.deepEqual(requestAlerts(before,{...before,pendingRepairId:'r'}).map(n=>[n.uid,n.type]),[['d','repair']]);
  assert.deepEqual(requestAlerts(before,{...before,lastRepairDecisionId:'r',lastRepairDecision:'rejected'}).map(n=>[n.uid,n.type]),[['p','decision']]);
  assert.equal(requestAlerts({...before,pendingRepairId:'r'},{...before,pendingRepairId:'r'}).length,0);
});
test('selection, completion and payment confirmations target the correct account',()=>{
  const r={driverId:'d',providerId:'p',status:'searching'};
  assert.equal(requestAlerts(r,{...r,status:'accepted'})[0].uid,'p');
  assert.equal(requestAlerts(r,{...r,status:'completed'})[0].uid,'d');
  assert.equal(requestAlerts(r,{...r,driverReportedPayment:true})[0].uid,'p');
  assert.equal(requestAlerts(r,{...r,providerConfirmedPayment:true})[0].uid,'d');
});
test('quote timestamps alone do not resend an offer notification',()=>{
  const q={total:1800,notes:'Labour',quoteType:'direct'};
  assert.equal(quoteChanged(q,{...q,createdAt:'new'}),false);
  assert.equal(quoteChanged(q,{...q,total:2000}),true);
  assert.equal(quoteChanged(null,q),true);
  assert.equal(quoteChanged(q,null),false);
});
test('completion, job start and discount notifications are transition-only',()=>{
  const r={driverId:'d',providerId:'p',status:'arrived'};
  for (const [patch,uid,type] of [[{completionState:'pending'},'d','completion_review'],[{arrivalConfirmedBy:'d'},'p','job_started'],[{pendingDiscountId:'discount'},'p','discount']]) {
    const after={...r,...patch};
    assert.ok(requestAlerts(r,after).some(n=>n.uid===uid && n.type===type));
    assert.equal(requestAlerts(after,after).length,0);
  }
  assert.ok(requestAlerts({...r,pendingDiscountId:'discount'},r).some(n=>n.uid==='d' && n.type==='discount_decision'));
});
