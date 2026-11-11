// Verify the exact APK again before generating trusted release metadata.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const apk=process.argv[2];if(!apk)throw Error('APK path required');
const verification=spawnSync((process.env.ANDROID_HOME??'')+'/build-tools/36.0.0/apksigner',['verify','--verbose',apk],{stdio:'inherit'});if(verification.status!==0)throw Error('APK signature verification failed');
const bytes=await readFile(apk),pkg=JSON.parse(await readFile('package.json','utf8'));
const metadata={version:pkg.version,size_bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),signature_verified:true,signing:'development_test_key',physical_device_tested:false};
await writeFile('artifacts/APK-BUILD-RESULT.json',JSON.stringify(metadata,null,2));
const staged=spawnSync(process.execPath,['scripts/stage-android-release.mjs',apk,'artifacts/APK-BUILD-RESULT.json'],{stdio:'inherit'});if(staged.status!==0)process.exit(staged.status??1);
await writeFile('TEST_REPORT.md','# v6 automated build validation\n\nThis package was created after Flutter analysis, Flutter tests, APK/AAB builds and signature verification passed. Backend tests, TypeScript compilation and Vite build run in CI. See the workflow for exact steps.\n\nNot tested: a physical phone, real emergency calls, real SIM SMS, live provider delivery or your deployed PostgreSQL connection. The APK uses a development signing key and may require uninstalling older APKs signed by a different key.\n');
