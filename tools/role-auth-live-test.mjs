import {readFileSync, writeFileSync, mkdirSync, existsSync} from 'node:fs';
import {randomBytes,createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

// State contains temporary test credentials/tokens; keep it only under ignored build/.
const [action, base, email] = process.argv.slice(2);
if (!base?.startsWith('https://') || !email) throw Error('Provide action, HTTPS candidate URL and authorized email.');
const web = readFileSync('lib/firebase_options.dart','utf8').split('static const FirebaseOptions web =')[1];
const key = web.match(/apiKey:\s*'([^']+)'/)[1];
const directory='build/role-auth-live';
mkdirSync(directory,{recursive:true});
const file=`${directory}/state-${createHash('sha256').update(email).digest('hex').slice(0,12)}.json`;
const state=existsSync(file)?JSON.parse(readFileSync(file,'utf8')):{email,base,accounts:{}};
assert.equal(state.email,email);
assert.ok(new URL(base).hostname.endsWith('-breakers-projects-d332ab9a.vercel.app'),'Use only this project test candidate');
if(action==='native-smoke') state.base=base;
assert.equal(state.base,base);
function save(){writeFileSync(file,JSON.stringify(state,null,2),{mode:0o600});}
async function post(url, body, token) {
  if (url.startsWith(base)) {
    const cli = process.env.ROLE_TEST_VERCEL_CLI;
    if (!cli) throw Error('ROLE_TEST_VERCEL_CLI is required for protected candidate requests.');
    const args = [cli, 'curl', url.slice(base.length), '--deployment', base, '--',
      '--silent', '--show-error', '--request', 'POST', '--header', 'Content-Type: application/json',
      ...(token ? ['--header', `Authorization: Bearer ${token}`] : []),
      '--data-binary', '@-', '--write-out', '\n%{http_code}'];
    let output;
    try {
      output = execFileSync(process.execPath, args, {input:JSON.stringify(body),encoding:'utf8',timeout:60000,stdio:['pipe','pipe','pipe']});
    } catch {throw Error('Protected candidate request failed; credential-bearing output withheld.');}
    const split=output.lastIndexOf('\n');
    return {status:Number(output.slice(split+1)),data:JSON.parse(output.slice(0,split))};
  }

  const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},
    body:JSON.stringify(body),signal:AbortSignal.timeout(40000)});
  const data=await response.json();return {status:response.status,data};
}
async function exchange(role,authEmail) {
  const result=await post(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,{email:authEmail,password:state.accounts[role].password,returnSecureToken:true});
  assert.equal(result.status,200,'Native Firebase password sign-in failed');
  Object.assign(state.accounts[role],{idToken:result.data.idToken,refreshToken:result.data.refreshToken,uid:result.data.localId});save();
}
if(action==='guard') {
  const result=await post(`${base}/api/role-auth`,{action:'login',email:'outside-test-scope@example.com',role:'driver',password:'Dummy123!'});
  assert.equal(result.status,503,'Candidate must reject mailboxes outside the authorized test scope');
  const live=await fetch('https://vehiclebreakdownapp.vercel.app/api/role-auth');
  assert.equal(live.status,404,'Live domain must remain on the old backend');
  console.log('Candidate restriction passed; live-domain role authentication remains inactive.');
} else if(['register','native-smoke'].includes(action)) {
  for(const role of action==='native-smoke'?['driver']:['driver','provider']) {
    if(state.accounts[role]?.existingAccount) { console.log(`${role}: existing account preserved; no credentials or history changed.`);continue; }
    if(!state.accounts[role]) {
      const password=`Ra9!${randomBytes(18).toString('base64url')}`;
      state.accounts[role]={password};save();
      const result=await post(`${base}/api/role-auth`,{action:'register',role,email,password,displayName:`RoadAssist ${role} test`,phone:'+94770000001'});
      if(result.status===409) {state.accounts[role]={existingAccount:true};save();console.log(`${role}: existing account preserved; no credentials or history changed.`);continue;}
      if(result.status!==201) throw Error(`${role} registration: HTTP ${result.status}, ${result.data.code ?? 'unknown'}. Existing accounts are never overwritten.`);
      assert.equal(typeof result.data.authEmail,'string','Native sign-in identity required');
      assert.equal(result.data.token,undefined,'No reusable custom token should be issued');
      state.accounts[role].authEmail=result.data.authEmail;save();
      await exchange(role,result.data.authEmail);
    }
    const account=state.accounts[role];
    if(!account.idToken) throw Error(`${role} registration did not finish. Inspect state without exposing credentials.`);
    const lookup=await post(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${key}`,{idToken:account.idToken});
    assert.equal(lookup.status,200);assert.equal(lookup.data.users[0].emailVerified,false);
    account.uid = lookup.data.users[0].localId;save();
    const profile=await fetch(`https://firestore.googleapis.com/v1/projects/roadassist-lk-munshif/databases/(default)/documents/users/${account.uid}`,{headers:{Authorization:`Bearer ${account.idToken}`}});
    assert.equal(profile.status,200,'Unverified owner profile should be readable');
    const fields=(await profile.json()).fields;
    assert.equal(fields.email.stringValue,email);assert.equal(fields.role.stringValue,role);
    const protectedData=await fetch('https://firestore.googleapis.com/v1/projects/roadassist-lk-munshif/databases/(default)/documents/requests?pageSize=1',{headers:{Authorization:`Bearer ${account.idToken}`}});
    assert.equal(protectedData.status,403,'Unverified account must not read requests');
    if(action==='register') {
      const delivery=await post(`${base}/api/request-email-verification`,{role},account.idToken);
      assert.equal(delivery.status,200,`${role} verification email failed (${delivery.status})`);
      console.log(`${role}: independent account created; unverified request access denied; verification email accepted by SMTP.`);
    } else {console.log(`${role}: native Firebase password sign-in passed; unverified request access denied; no email sent.`);}
  }
  if(!state.accounts.driver.existingAccount && !state.accounts.provider.existingAccount) assert.notEqual(state.accounts.driver.uid,state.accounts.provider.uid);
  for(const role of ['driver','provider']) {
    if(state.accounts[role].existingAccount) continue;
    const other=role==='driver'?'provider':'driver';
    if(!state.accounts[other].existingAccount) {
    const crossed=await post(`${base}/api/role-auth`,{action:'login',email,role,password:state.accounts[other].password});
    assert.equal(crossed.status,401,'Crossed role password must be rejected');
    console.log(`${role}: other role password rejected.`);
    }
    const own=await post(`${base}/api/role-auth`,{action:'login',email,role,password:state.accounts[role].password});
    assert.equal(own.status,200,'Own role password must authenticate');
    console.log(`${role}: own password accepted.`);
  }
} else if(action==='verification-status') {
  for(const role of ['driver','provider']) {
    const account=state.accounts[role];
    if(account.existingAccount) {console.log(`${role}: existing account; verification unchanged.`);continue;}
    const lookup=await post(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${key}`,{idToken:account.idToken});
    assert.equal(lookup.status,200);
    const verified = lookup.data.users[0].emailVerified===true;
    console.log(`${role}: email verified = ${verified}`);
    if(verified) {
      const refreshed=await fetch(`https://securetoken.googleapis.com/v1/token?key=${key}`,{method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body:new URLSearchParams({grant_type:'refresh_token',refresh_token:account.refreshToken})});
      assert.equal(refreshed.status,200,'Verified session refresh failed');
      const fresh=await refreshed.json();account.idToken=fresh.id_token;account.refreshToken=fresh.refresh_token;save();
      if(role==='driver') {
        const requests=await post('https://firestore.googleapis.com/v1/projects/roadassist-lk-munshif/databases/(default)/documents:runQuery',{
          structuredQuery:{from:[{collectionId:'requests'}],where:{fieldFilter:{field:{fieldPath:'driverId'},op:'EQUAL',value:{stringValue:account.uid}}},limit:1}
        },account.idToken);
        assert.equal(requests.status,200,'Verified driver must be able to query own requests');
        console.log('driver: refreshed verified session can read its own requests.');
      }
    }
  }
} else if(action==='reset-status') {
  const account=state.accounts.driver;
  const old=await post(`${base}/api/role-auth`,{action:'login',email,role:'driver',password:account.password});
  assert.equal(old.status,401,'Old driver password must fail after reset');
  const refreshed=await fetch(`https://securetoken.googleapis.com/v1/token?key=${key}`,{method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'refresh_token',refresh_token:account.refreshToken})});
  assert.equal(refreshed.status,400,'Old refresh token must fail after reset');
  console.log('driver: old password and old refresh token rejected after reset.');
} else if(['reset-emails','reset-driver'].includes(action)) {
  for(const role of action==='reset-driver'?['driver']:['driver','provider']) {
    const result=await post(`${base}/api/request-password-reset`,{email,role,website:''});
    assert.equal(result.status,200,`${role} reset request failed`);
    console.log(`${role}: password reset email request accepted.`);
  }
} else {throw Error('Unknown live test action');}
