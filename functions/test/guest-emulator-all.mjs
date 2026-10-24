import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
if(!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST || !['localhost','127.0.0.1'].includes(process.env.FIRESTORE_EMULATOR_HOST.split(':')[0])) throw Error('Local Auth and Firestore emulators are required.');
const env={...process.env,GUEST_REQUESTS_ENABLED:'true',FIRESTORE_TEST_PORT:process.env.FIRESTORE_EMULATOR_HOST.split(':').at(-1),ROADASSIST_RULES_FILE:resolve('firestore.rules')};
for(const args of [['functions/test/guest-emulator.integration.mjs'],['--test','tools/rules-tests/workflow.test.mjs']]){
 const result=spawnSync(process.execPath,args,{env,stdio:'inherit'});if(result.status!==0)process.exit(result.status??1);
}
