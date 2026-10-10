import {createRequire} from 'node:module';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {roleAddress} from '../functions/role-identity.mjs';
const email=process.argv[2]?.trim().toLowerCase();
if(!email) throw Error('Provide the authorized test mailbox');
const file=`build/role-auth-live/state-${createHash('sha256').update(email).digest('hex').slice(0,12)}.json`;
const state=JSON.parse(readFileSync(file,'utf8'));assert.equal(state.email,email);
const require=createRequire(import.meta.url);
const cliAuth=require('./rules-tests/node_modules/firebase-tools/lib/auth.js');
const account=cliAuth.getGlobalDefaultAccount();if(!account) throw Error('Firebase CLI login required');
const credentials=await cliAuth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase','https://www.googleapis.com/auth/userinfo.email']);
const project='roadassist-lk-munshif';
async function admin(url,method='GET',body) {
 const result=await fetch(url,{method,headers:{Authorization:`Bearer ${credentials.access_token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 if(!result.ok) throw Error(`Test cleanup HTTP ${result.status}`);return result.status===204?{}:result.json();
}
const authBase=`https://identitytoolkit.googleapis.com/v1/projects/${project}`;
const dataBase=`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
for(const [role,a] of Object.entries(state.accounts)) {
 if(a.existingAccount) continue;
 assert.match(a.uid,/^[a-zA-Z0-9_-]{1,128}$/);
 const user=(await admin(`${authBase}/accounts:lookup`,'POST',{localId:[a.uid]})).users?.[0];
 assert.equal(user?.email,roleAddress(email,role));
 const doc=await admin(`${dataBase}/users/${a.uid}`);const fields=doc.fields;
 assert.equal(fields.email.stringValue,email);assert.equal(fields.authIdentity.stringValue,'role-v1');
 assert.equal(fields.role.stringValue,role);assert.equal(fields.displayName.stringValue,`RoadAssist ${role} test`);
 for(const field of ['driverId','providerId']) {
  const jobs=await admin(`${dataBase}:runQuery`,'POST',{structuredQuery:{from:[{collectionId:'requests'}],
    where:{fieldFilter:{field:{fieldPath:field},op:'EQUAL',value:{stringValue:a.uid}}},limit:1}});
  assert.equal(jobs.some(row=>row.document),false,'Never delete a test account with job history');
 }
 await admin(`${authBase}/accounts:delete`,'POST',{localId:a.uid});
 await admin(`${dataBase}/users/${a.uid}`,'DELETE');
 state.cleanedAccounts??=[];state.cleanedAccounts.push({role,uid:a.uid,cleanedAt:new Date().toISOString()});
 delete state.accounts[role];writeFileSync(file,JSON.stringify(state,null,2),{mode:0o600});
 console.log(`${role}: temporary test identity/profile deleted; existing accounts preserved.`);
}
