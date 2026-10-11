import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createGoogleRoleAuthHandler} from '../../api/google-role-auth.mjs';
import {roleAddress} from '../role-identity.mjs';
function fixture(proof={uid:'google',email:'same@example.com',email_verified:true,firebase:{sign_in_provider:'google.com'}}){
 const users=new Map(),docs=new Map();
 const auth={verifyIdToken:async()=>proof,getUserByEmail:async email=>{if(users.has(email))return users.get(email);throw Object.assign(Error(),{code:'auth/user-not-found'});},
 createUser:async data=>{if(users.has(data.email))throw Object.assign(Error(),{code:'auth/email-already-exists'});const u={...data,uid:`role-${users.size}`};users.set(data.email,u);return u;},
 updateUser:async(uid,data)=>{for(const u of users.values())if(u.uid===uid)Object.assign(u,data);},deleteUser:async()=>{},createCustomToken:async uid=>`token:${uid}`};
 const db={doc(path){return {path,get:async()=>({data:()=>docs.get(path)}),create:async data=>docs.set(path,data)};},runTransaction:async fn=>fn({get:r=>r.get(),set:(r,d)=>docs.set(r.path,d)})};
 const handler=createGoogleRoleAuthHandler({getServices:()=>({auth,db,timestamp:()=>1}),enabled:()=>true});
 async function request(role='driver',extra={}){const res={setHeader(){},status(c){this.code=c;return this;},json(d){this.body=d;return this;},end(){return this;}};await handler({method:'POST',headers:{authorization:'Bearer proof'},body:{role,...extra}},res);return res;}
 return {users,docs,request};
}
const details={displayName:'Test Person',phone:'+94771234567',photoData:'data:image/png;base64,AAAA'};
test('Google creates separate verified role profiles without passwords',async()=>{
 const f=fixture();const d=await f.request('driver',details),p=await f.request('provider',details);
 assert.equal(d.code,200);assert.equal(p.code,200);assert.notEqual(d.body.customToken,p.body.customToken);
 assert.equal(f.users.size,2);for(const u of f.users.values()){assert.equal(u.emailVerified,true);assert.equal(u.password,undefined);}
});
test('existing role keeps its UID password and profile',async()=>{
 const f=fixture(),email=roleAddress('same@example.com','driver');f.users.set(email,{uid:'existing',email,password:'Keep123',emailVerified:false});
 const profile={role:'driver',authIdentity:'role-v1',email:'same@example.com',displayName:'Original',phone:'original'};f.docs.set('users/existing',profile);
 assert.equal((await f.request()).body.customToken,'token:existing');assert.equal(f.users.get(email).password,'Keep123');assert.deepEqual(f.docs.get('users/existing'),profile);
});
test('requires fresh verified Google proof',async()=>{
 for(const proof of [{uid:'x',email:'same@example.com',email_verified:false,firebase:{sign_in_provider:'google.com'}},{uid:'x',email:'same@example.com',email_verified:true,firebase:{sign_in_provider:'password'}}]){
 const f=fixture(proof);assert.equal((await f.request('driver',details)).code,401);assert.equal(f.users.size,0);}
});
test('missing profile details cannot create a role',async()=>{const f=fixture();assert.equal((await f.request()).body.code,'profile-details-required');assert.equal(f.users.size,0);});
test('moderation blocks both matching role and Google principal',async()=>{
 for(const uid of ['google','existing']){const f=fixture();const email=roleAddress('same@example.com','driver');f.users.set(email,{uid:'existing',email,emailVerified:true});f.docs.set('users/existing',{role:'driver',authIdentity:'role-v1',email:'same@example.com'});f.docs.set(`accountModeration/${uid}`,{status:'suspended'});assert.equal((await f.request()).code,403);}
});
test('disabled internal identity cannot be replaced',async()=>{const f=fixture(),email=roleAddress('same@example.com','driver');f.users.set(email,{uid:'disabled',email,disabled:true});assert.equal((await f.request('driver',details)).code,409);assert.equal(f.users.size,1);});
