import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRoleAuthHandler} from '../../api/role-auth.mjs';
import {roleAddress} from '../role-identity.mjs';

function fixture() {
  const users=new Map(), docs=new Map(), passwords=new Map();
  const auth={
    async getUserByEmail(email){if(users.has(email)) return users.get(email); throw Object.assign(Error(),{code:'auth/user-not-found'});},
    async createUser(data){if(users.has(data.email)) throw Object.assign(Error(),{code:'auth/email-already-exists'});
      const user={...data,uid:`uid-${users.size}`}; users.set(data.email,user);passwords.set(data.email,data.password);return user;},
    async deleteUser(uid){for(const [email,u] of users) if(u.uid===uid) users.delete(email);},
  };
  const db={doc(path){return {path,async get(){return {data:()=>docs.get(path)};},async create(data){assert.equal(docs.has(path),false);docs.set(path,data);}};},
    async runTransaction(fn){return fn({get:r=>r.get(),set:(r,data)=>docs.set(r.path,data)});}};
  const handler=createRoleAuthHandler({getServices:()=>({auth,db,timestamp:()=>123}), enabled:()=>true,
    passwordSignIn:async(email,password)=>passwords.get(email)===password?users.get(email)?.uid:null});
  async function request(body, method='POST'){
    const res={statusCode:200,setHeader(){},status(code){this.statusCode=code;return this;},json(data){this.body=data;return this;},end(){return this;}};
    await handler({method,body,headers:{'x-forwarded-for':'127.0.0.1'}},res);return res;
  }
  const register=(role,password)=>request({action:'register',email:'same@example.com',role,password,displayName:role+' Person',phone:'+94771234567'});
  const login=(role,password)=>request({action:'login',email:'same@example.com',role,password});
  return {users,docs,passwords,register,login,request};
}
test('same email enrolls distinct unverified role profiles and rejects crossed passwords',async()=>{
  const f=fixture();
  const driver=await f.register('driver','Driver123');const provider=await f.register('provider','Provider456');
  assert.equal(driver.statusCode,201);assert.equal(provider.statusCode,201);
  assert.notEqual(driver.body.authEmail,provider.body.authEmail);
  for(const role of ['driver','provider']){
    const u=f.users.get(roleAddress('same@example.com',role));assert.equal(u.emailVerified,false);
    assert.deepEqual(f.docs.get(`users/${u.uid}`).roles,[role]);
    assert.equal(f.docs.get(`users/${u.uid}`).email,'same@example.com');
  }
  assert.equal((await f.login('driver','Provider456')).statusCode,401);
  assert.equal((await f.login('provider','Driver123')).statusCode,401);
  assert.equal((await f.login('driver','Driver123')).statusCode,200);
  assert.equal((await f.login('provider','Provider456')).statusCode,200);
});
test('re-register cannot replace password or profile',async()=>{
  const f=fixture();await f.register('driver','Original123');
  assert.equal((await f.register('driver','Replacement456')).statusCode,409);
  assert.equal((await f.login('driver','Original123')).statusCode,200);
  assert.equal((await f.login('driver','Replacement456')).statusCode,401);
});
test('changing one native identity password leaves other role login intact',async()=>{
  const f=fixture();await f.register('driver','Driver123');await f.register('provider','Provider456');
  f.passwords.set(roleAddress('same@example.com','driver'),'Reset789');
  assert.equal((await f.login('driver','Driver123')).statusCode,401);
  assert.equal((await f.login('driver','Reset789')).statusCode,200);
  assert.equal((await f.login('provider','Provider456')).statusCode,200);
});
test('suspended legacy identity cannot enroll a fresh role',async()=>{
  const f=fixture();f.users.set('same@example.com',{uid:'legacy',email:'same@example.com'});
  f.docs.set('accountModeration/legacy',{status:'suspended'});
  assert.equal((await f.register('driver','Driver123')).statusCode,403);
  assert.equal(f.users.size,1);
});
test('durable limiter rejects excessive attempts',async()=>{
  const f=fixture();for(let i=0;i<10;i++) assert.equal((await f.login('driver','Wrong123')).statusCode,401);
  assert.equal((await f.login('driver','Wrong123')).statusCode,429);
});
test('invalid role and short password cannot create an identity',async()=>{
  const f=fixture();assert.equal((await f.register('admin','Password123')).statusCode,400);
  assert.equal((await f.register('driver','short')).statusCode,400);assert.equal(f.users.size,0);
  assert.equal((await f.request({},'GET')).statusCode,405);
});

test('candidate deployment accepts only the designated test mailbox',async()=>{
  let accessed=false;
  const handler=createRoleAuthHandler({enabled:()=>true,testEmail:()=> 'test@example.com',
    getServices:()=>{accessed=true;throw Error('must not access');}});
  const res={setHeader(){},status(code){this.code=code;return this;},json(body){this.body=body;return this;}};
  await handler({method:'POST',body:{action:'login',email:'other@example.com',role:'driver',password:'Password123'},headers:{}},res);
  assert.equal(res.code,503);assert.equal(accessed,false);
});
test('disabled production flow never accesses account services',async()=>{
  const handler=createRoleAuthHandler({enabled:()=>false,getServices:()=>{throw Error('must not access');}});
  const res={setHeader(){},status(code){this.code=code;return this;},json(){return this;}};
  await handler({method:'POST',body:{},headers:{}},res);assert.equal(res.code,503);
});
