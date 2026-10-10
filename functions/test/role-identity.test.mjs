import { test } from 'node:test';
import assert from 'node:assert/strict';
import {roleAddress, resolveRoleUser, contactEmail} from '../role-identity.mjs';

test('same mailbox creates independent stable identities without plus aliases', () => {
  assert.equal(roleAddress(' TEST@Example.com ', 'driver'),roleAddress('test@example.com','driver'));
  assert.notEqual(roleAddress('test@example.com','driver'),roleAddress('test@example.com','provider'));
  assert.notEqual(roleAddress('test+one@example.com','driver'),roleAddress('test@example.com','driver'));
  assert.throws(() => roleAddress('a@example.com','admin'));
  assert.throws(() => roleAddress('bad','driver'));
});
function fixture(users, profiles) {
  const calls=[];
  return {calls, auth:{async getUserByEmail(email) {calls.push(email); if(users[email]) return users[email]; throw Object.assign(Error(),{code:'auth/user-not-found'});}},
    db:{doc(path){return {async get(){return {data:()=>profiles[path]};}};}}};
}
test('new role identity takes precedence and orphan cannot fall back to legacy', async () => {
  const address=roleAddress('a@example.com','driver');
  const f=fixture({[address]:{uid:'new',email:address},'a@example.com':{uid:'old'}}, {'users/old':{role:'driver'}});
  assert.equal(await resolveRoleUser(f.auth,f.db,'a@example.com','driver'),null);
  assert.deepEqual(f.calls,[address]);
});
test('legacy login is limited to primary role and preserves UID', async () => {
  const f=fixture({'a@example.com':{uid:'old',email:'a@example.com'}},{'users/old':{role:'provider',roles:['provider','driver']}});
  assert.equal(await resolveRoleUser(f.auth,f.db,'a@example.com','driver'),null);
  assert.equal((await resolveRoleUser(f.auth,f.db,'a@example.com','provider')).user.uid,'old');
});
test('mailer validates identity and delivers to real contact email', () => {
  const profile={email:'a@example.com',role:'provider',authIdentity:'role-v1'};
  assert.equal(contactEmail({email:roleAddress(profile.email,profile.role)},profile),profile.email);
  assert.throws(()=>contactEmail({email:roleAddress(profile.email,'driver')},profile));
  assert.equal(contactEmail({email:'legacy@example.com'},{role:'driver'}),'legacy@example.com');
});
test('disabled role identity never falls back to a legacy password', async () => {
  const address=roleAddress('a@example.com','driver');
  const f=fixture({[address]:{uid:'new',email:address,disabled:true},'a@example.com':{uid:'old'}},
    {'users/new':{email:'a@example.com',role:'driver',authIdentity:'role-v1'},'users/old':{role:'driver'}});
  assert.equal(await resolveRoleUser(f.auth,f.db,'a@example.com','driver'),null);
  assert.deepEqual(f.calls,[address]);
});
