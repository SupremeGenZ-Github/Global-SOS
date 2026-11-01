import {readFile,stat} from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';

export function androidDownloads(directory){
 let verified;
 const release=()=>verified??=(async()=>{
  try{
   const info=JSON.parse(await readFile(resolve(directory,'release.json'),'utf8'));
   if(!/^\d+\.\d+\.\d+$/.test(info.version)||! /^[a-f0-9]{64}$/.test(info.sha256)||!Number.isSafeInteger(info.size_bytes)||info.size_bytes<1)throw Error('Invalid release metadata');
   const file=resolve(directory,'Global-SOS-AI.apk');
   if((await stat(file)).size!==info.size_bytes)throw Error('Wrong size');
   const hash=createHash('sha256');for await(const chunk of createReadStream(file))hash.update(chunk);
   if(hash.digest('hex')!==info.sha256)throw Error('Wrong checksum');
   return {file,public:{available:true,version:info.version,size_bytes:info.size_bytes,sha256:info.sha256,built_at:info.built_at,android_min:'8.0',architecture:'ARM64',signing:'Development/test key',device_tested:false,url:'/downloads/Global-SOS-AI.apk',checksum_url:'/downloads/Global-SOS-AI.apk.sha256'}};
  }catch{return {public:{available:false,message:'No verified APK is installed on this server. Deploy a release package containing the Android download files.'}};}
 })();
 return {
  metadata:async(req,res)=>res.json((await release()).public),
  apk:async(req,res,next)=>{const r=await release();if(!r.file)return res.status(503).json(r.public);res.download(r.file,'Global-SOS-AI.apk',{headers:{'Content-Type':'application/vnd.android.package-archive','Cache-Control':'no-store'}},err=>err&&next(err));},
  checksum:async(req,res)=>{const r=await release();if(!r.file)return res.status(503).json(r.public);res.type('text/plain').send(r.public.sha256+'  Global-SOS-AI.apk\n');},
 };
}
