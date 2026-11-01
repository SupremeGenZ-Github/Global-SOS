import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import request from 'supertest';
import {createApp} from '../backend/app.mjs';
import {prepareDownload} from '../scripts/prepare-download.mjs';
const sha=b=>createHash('sha256').update(b).digest('hex');
const binary=(res,done)=>{const chunks=[];res.on('data',c=>chunks.push(c));res.on('end',()=>done(null,Buffer.concat(chunks)));};

test('public APK metadata, binary, HEAD/range and checksum agree without authentication',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'sos-download-'));try{
  const bytes=Buffer.from('Test fixture bytes: not an installable app');await writeFile(join(dir,'Global-SOS-AI.apk'),bytes);await writeFile(join(dir,'release.json'),JSON.stringify({version:'0.3.0',size_bytes:bytes.length,sha256:sha(bytes),built_at:'2026-11-01T00:00:00Z'}));
  const app=createApp({env:{ANDROID_RELEASE_DIR:dir}});
  const meta=await request(app).get('/api/releases/android').expect(200);assert.equal(meta.body.available,true);assert.equal(meta.body.sha256,sha(bytes));assert.equal(meta.body.file,undefined);
  const apk=await request(app).get('/downloads/Global-SOS-AI.apk').buffer(true).parse(binary).expect(200);assert.deepEqual(apk.body,bytes);assert.match(apk.headers['content-disposition'],/attachment/);assert.match(apk.headers['content-type'],/android.package-archive/);
  await request(app).head('/downloads/Global-SOS-AI.apk').expect(200);
  const range=await request(app).get('/downloads/Global-SOS-AI.apk').set('Range','bytes=0-3').buffer(true).parse(binary).expect(206);assert.deepEqual(range.body,bytes.subarray(0,4));
  const checksum=await request(app).get('/downloads/Global-SOS-AI.apk.sha256').expect(200);assert.ok(checksum.text.startsWith(sha(bytes)));
 }finally{await rm(dir,{recursive:true,force:true});}
});

test('missing or corrupt release never produces an enabled binary download',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'sos-missing-'));try{
  const missing=createApp({env:{ANDROID_RELEASE_DIR:dir}});assert.equal((await request(missing).get('/api/releases/android')).body.available,false);await request(missing).get('/downloads/Global-SOS-AI.apk').expect(503);
  await writeFile(join(dir,'release.json'),JSON.stringify({version:'0.3.0',size_bytes:4,sha256:sha(Buffer.from('good'))}));await writeFile(join(dir,'Global-SOS-AI.apk'),'evil');const corrupt=createApp({env:{ANDROID_RELEASE_DIR:dir}});await request(corrupt).get('/downloads/Global-SOS-AI.apk').expect(503);
 }finally{await rm(dir,{recursive:true,force:true});}
});

test('release parts assemble exactly and a corrupted update preserves the previous download',async()=>{
 const source=await mkdtemp(join(tmpdir(),'sos-parts-')),destination=await mkdtemp(join(tmpdir(),'sos-assembled-'));try{
  const a=Buffer.from('part one '),b=Buffer.from('part two'),bytes=Buffer.concat([a,b]);const parts=[a,b].map((p,i)=>({name:'Global-SOS-AI.apk.part-00'+(i+1),size_bytes:p.length,sha256:sha(p)}));
  await writeFile(join(source,'release.json'),JSON.stringify({version:'0.3.0',size_bytes:bytes.length,sha256:sha(bytes),parts}));for(let i=0;i<parts.length;i++)await writeFile(join(source,parts[i].name),[a,b][i]);
  assert.equal((await prepareDownload(source,destination)).available,true);assert.deepEqual(await readFile(join(destination,'Global-SOS-AI.apk')),bytes);
  await writeFile(join(source,parts[0].name),'bad');await assert.rejects(prepareDownload(source,destination),/integrity/);assert.deepEqual(await readFile(join(destination,'Global-SOS-AI.apk')),bytes);
 }finally{await rm(source,{recursive:true,force:true});await rm(destination,{recursive:true,force:true});}
});
