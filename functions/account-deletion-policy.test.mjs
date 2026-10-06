import test from 'node:test';
import assert from 'node:assert/strict';
import {deletionBlockers} from './account-deletion-policy.mjs';
test('active work, unpaid jobs and unresolved evidence prevent deletion',()=> {
  assert.equal(deletionBlockers([{status:'accepted'},{status:'completed'},{status:'cancelled',hasDispute:true}]).length,3);
});
test('settled jobs and closed complaints allow deletion',()=> {
  assert.equal(deletionBlockers([{status:'cancelled'},{status:'completed',providerConfirmedPayment:true,hasDispute:true,complaintStatus:'resolved'}]).length,0);
});

import handler from '../api/admin-delete-account.mjs';
test('deletion endpoint rejects GET without accessing credentials', async()=> {
  let code, body;
  const res={setHeader(){},status(value){code=value;return this;},json(value){body=value;return this;}};
  await handler({method:'GET'},res);
  assert.equal(code,405);
  assert.equal(body.message,'POST required.');
});
test('preflight returns without authentication or mutations', async()=> {
  let code;
  const res={setHeader(){},status(value){code=value;return this;},end(){return this;}};
  await handler({method:'OPTIONS'},res);
  assert.equal(code,204);
});