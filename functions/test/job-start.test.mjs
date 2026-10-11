import {test} from 'node:test';
import assert from 'node:assert/strict';
import {newChallenge, checkCode, validateParticipant, CODE_TTL_MS} from '../job-start-policy.mjs';
import handler from '../../api/job-start-code.mjs';
test('job start code is six digits and only its salted digest is stored', () => {
  const {code,record} = newChallenge(1000);
  assert.match(code,/^\d{6}$/); assert.equal(record.code,undefined);
  assert.equal(record.expiresAtMs,1000+CODE_TTL_MS);
  assert.equal(checkCode(record,code,1001),'verified');
  assert.equal(checkCode(record,code,1000+CODE_TTL_MS),'expired');
  assert.equal(checkCode({...record,attempts:5},code,1001),'locked');
  assert.equal(checkCode({...record,usedAtMs:1001},code,1002),'unavailable');
  assert.equal(checkCode(record,'123',1001),'invalid');
  const wrong = code === '000000' ? '111111' : '000000';
  assert.equal(checkCode(record,wrong,1001),'incorrect');
});
test('driver issues and assigned provider verifies only an arrived unstarted job', () => {
  const job={driverId:'d',providerId:'p',status:'arrived'};
  assert.equal(validateParticipant(job,{uid:'d',email_verified:true},'issue'),null);
  assert.equal(validateParticipant(job,{uid:'p',email_verified:true},'verify'),null);
  for (const [actor,action] of [['p','issue'],['d','verify'],['stranger','verify']]) assert.ok(validateParticipant(job,{uid:actor,email_verified:true},action));
  assert.ok(validateParticipant({...job,status:'completed'},{uid:'p',email_verified:true},'verify'));
  assert.ok(validateParticipant({...job,arrivalConfirmedBy:'d'},{uid:'p',email_verified:true},'verify'));
  assert.ok(validateParticipant(job,{uid:'d',email_verified:false},'issue'));
});
test('endpoint rejects invalid requests before loading server credentials', async () => {
  for (const [req,status] of [[{method:'GET',headers:{}},405],[{method:'POST',headers:{}},401],[{method:'POST',headers:{authorization:'Bearer token'},body:{requestId:'../../secret',action:'issue'}},400]]) {
    const res={setHeader(){},status(value){this.code=value;return this;},json(body){this.body=body;return this;}};
    await handler(req,res); assert.equal(res.code,status);
  }
});
