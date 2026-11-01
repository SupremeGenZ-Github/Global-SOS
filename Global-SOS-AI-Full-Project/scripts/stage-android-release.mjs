import {readFile,writeFile,mkdir,readdir,unlink} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const apk=await readFile(resolve(process.argv[2]));
const metadata=JSON.parse(await readFile(resolve(process.argv[3]),'utf8'));
const sha=x=>createHash('sha256').update(x).digest('hex');
if(metadata.sha256!==sha(apk)||metadata.size_bytes!==apk.length||metadata.signature_verified!==true)throw Error('APK must match verified build metadata');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..'),folder=resolve(root,'releases/android');await mkdir(folder,{recursive:true});
for(const name of await readdir(folder))if(/^Global-SOS-AI\.apk\.part-\d{3}$/.test(name))await unlink(resolve(folder,name));
const parts=[];for(let offset=0,index=1;offset<apk.length;offset+=10*1024*1024,index++){
 const data=apk.subarray(offset,offset+10*1024*1024),name='Global-SOS-AI.apk.part-'+String(index).padStart(3,'0');
 await writeFile(resolve(folder,name),data);parts.push({name,size_bytes:data.length,sha256:sha(data)});
}
const release={version:metadata.version,size_bytes:apk.length,sha256:sha(apk),built_at:new Date().toISOString(),parts};
await writeFile(resolve(folder,'release.json'),JSON.stringify(release,null,2));
console.log({version:release.version,parts:parts.length,size_bytes:release.size_bytes});
