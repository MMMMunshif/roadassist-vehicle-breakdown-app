import {test} from 'node:test';
import assert from 'node:assert/strict';
import {canConfirmRole} from '../role-email-policy.mjs';
const data={uid:'u',role:'driver',email:'same@example.com',expiresAtMs:200,used:false};
const profile={role:'provider',roles:['provider','driver'],roleEmailRequired:['driver']};
const user={uid:'u',email:'same@example.com',emailVerified:true};
test('additional-role email confirmation accepts the matching live challenge',()=>{
  assert.equal(canConfirmRole(data,profile,user,100),true);
});
test('role confirmation rejects replay, expiry, wrong account, changed email and missing enrollment',()=>{
  for(const invalid of [{...data,used:true},{...data,expiresAtMs:100},{...data,expiresAtMs:NaN},{...data,uid:'stranger'},{...data,email:'old@example.com'},{...data,role:'admin'}])
    assert.equal(canConfirmRole(invalid,profile,user,100),false);
  assert.equal(canConfirmRole(data,{...profile,roles:['provider']},user,100),false);
  assert.equal(canConfirmRole(data,profile,{...user,emailVerified:false},100),false);
  assert.equal(canConfirmRole(data,profile,{...user,disabled:true},100),false);
  assert.equal(canConfirmRole(data,null,user,100),false);
});
