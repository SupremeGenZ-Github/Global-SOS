import {readFile,mkdir,writeFile,rename,rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

export async function prepareDownload(source,destination){
 let info;
 try{info=JSON.parse(await readFile(resolve(source,'release.json'),'utf8'));}
 catch(e){if(e.code==='ENOENT')return {available:false};throw e;}
 if(!/^\d+\.\d+\.\d+$/.test(info.version)||! /^[a-f0-9]{64}$/.test(info.sha256)||!Number.isSafeInteger(info.size_bytes)||!Array.isArray(info.parts)||!info.parts.length)throw Error('Invalid Android release manifest');
 const bytes=[];let length=0;
 for(const part of info.parts){
  if(!/^Global-SOS-AI\.apk\.part-\d{3}$/.test(part.name)||! /^[a-f0-9]{64}$/.test(part.sha256))throw Error('Invalid release part');
  const data=await readFile(resolve(source,part.name));
  if(data.length!==part.size_bytes||createHash('sha256').update(data).digest('hex')!==part.sha256)throw Error('APK part integrity check failed: '+part.name);
  bytes.push(data);length+=data.length;
 }
 const apk=Buffer.concat(bytes);
 if(length!==info.size_bytes||createHash('sha256').update(apk).digest('hex')!==info.sha256)throw Error('APK integrity check failed');
 await mkdir(destination,{recursive:true});
 const target=resolve(destination,'Global-SOS-AI.apk'),temporary=target+'.tmp';
 await writeFile(temporary,apk);await rm(target,{force:true});await rename(temporary,target);
 await writeFile(resolve(destination,'release.json'),JSON.stringify(info,null,2));
 return {available:true,version:info.version,size_bytes:length};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
 console.log('Android website download:',await prepareDownload(resolve(root,'releases/android'),resolve(root,'public-downloads/android')));
}
