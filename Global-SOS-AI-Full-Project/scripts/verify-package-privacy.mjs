import {writeFile,readFile,rm} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const fixtureName='.env.package-check-'+randomUUID()+'.local';
const fixtures=[fixtureName,'android/'+fixtureName],created=[];
try{
 for(const file of fixtures){await writeFile(file,'PRIVATE_PACKAGE_FIXTURE=not-a-real-secret\n',{flag:'wx'});created.push(file);}
 const result=spawnSync(process.execPath,['scripts/package.mjs'],{stdio:'inherit',env:process.env});
 if(result.status!==0)throw Error('Package creation failed');
 const out=process.env.PACKAGE_OUTPUT_DIR?resolve(process.env.PACKAGE_OUTPUT_DIR):resolve('../..','outputs');
 for(const name of ['Global-SOS-AI-Full-Project.zip','Global-SOS-AI-Render.zip','Global-SOS-AI-Android-Source.zip']){
  const zip=await readFile(resolve(out,name));let at=0;const names=[];
  while(at+30<=zip.length&&zip.readUInt32LE(at)===0x04034b50){const packed=zip.readUInt32LE(at+18),length=zip.readUInt16LE(at+26),extra=zip.readUInt16LE(at+28);names.push(zip.subarray(at+30,at+30+length).toString('utf8'));at+=30+length+extra+packed;}
  assert.ok(names.length>0);
  assert.ok(!names.some(path=>path.split('/').some(part=>part.startsWith('.env')&&part!=='.env.example')),name+' must not contain private environment files');
 }
 console.log('PASS: source, Render and Android ZIPs exclude private environment-file fixtures');
}finally{for(const file of created)await rm(file,{force:true});}
