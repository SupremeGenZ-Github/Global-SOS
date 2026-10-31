import {spawnSync} from 'node:child_process';
import {readFile,writeFile,access} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
const root=fileURLToPath(new URL('../android/',import.meta.url));
const flutter=process.argv[2]||process.env.FLUTTER_BIN||(process.platform==='win32'?'flutter.bat':'flutter');
try{await access(resolve(root,'android/app/build.gradle.kts'));console.log('Android platform already exists; preserving its configuration.');process.exit(0);}catch{}
const r=spawnSync(flutter,['create','--platforms=android','--org','org.globalsos','--project-name','global_sos_ai','--no-pub',root],{stdio:'inherit',shell:process.platform==='win32'});if(r.status!==0)process.exit(r.status??1);
const gradle=resolve(root,'android/app/build.gradle.kts');let g=await readFile(gradle,'utf8');g=g.replace('minSdk = flutter.minSdkVersion','minSdk = 26').replace('ndkVersion = flutter.ndkVersion','ndkVersion = "28.2.13676358"');
g=g.replace('android {',`val releaseStore = System.getenv("KEYSTORE_PATH")\nval releaseAlias = System.getenv("KEY_ALIAS")\nval releaseStorePassword = System.getenv("KEYSTORE_PASSWORD")\nval releaseKeyPassword = System.getenv("KEY_PASSWORD")\nval hasReleaseKey = listOf(releaseStore, releaseAlias, releaseStorePassword, releaseKeyPassword).all { !it.isNullOrBlank() }\n\nandroid {\n    if (hasReleaseKey) {\n        signingConfigs {\n            create("production") {\n                storeFile = file(releaseStore!!)\n                storePassword = releaseStorePassword\n                keyAlias = releaseAlias\n                keyPassword = releaseKeyPassword\n            }\n        }\n    }`);
g=g.replace('signingConfig = signingConfigs.getByName("debug")','signingConfig = signingConfigs.getByName(if (hasReleaseKey) "production" else "debug")\n            isMinifyEnabled = false\n            isShrinkResources = false');await writeFile(gradle,g);
const manifest=resolve(root,'android/app/src/main/AndroidManifest.xml');let m=await readFile(manifest,'utf8');m=m.replace('<application','<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <application').replace('android:label="global_sos_ai"','android:label="Global SOS AI" android:allowBackup="false" android:usesCleartextTraffic="false"');await writeFile(manifest,m);
// flutter create generates a default counter test; the product uses its own routing and widget tests.
try{await access(resolve(root,'test/widget_test.dart'));const {unlink}=await import('node:fs/promises');await unlink(resolve(root,'test/widget_test.dart'));}catch{}
console.log('Android platform generated. Minimum API 26; debug signing unless all four release signing variables are configured.');
