import {createApp} from '../backend/app.mjs';
import {createHash} from 'node:crypto';
import {writeFile} from 'node:fs/promises';

const server=createApp({env:{}}).listen(0,'127.0.0.1');
await new Promise(r=>server.once('listening',r));
try{
 const origin='http://127.0.0.1:'+server.address().port;
 const metadata=await (await fetch(origin+'/api/releases/android')).json();if(!metadata.available)throw Error('Real APK unavailable');
 const page=await fetch(origin+'/download');if(page.status!==200||!page.headers.get('content-type')?.includes('text/html'))throw Error('Download page route failed');
 const response=await fetch(origin+metadata.url);if(response.status!==200)throw Error('APK response failed');
 const bytes=Buffer.from(await response.arrayBuffer());const hash=createHash('sha256').update(bytes).digest('hex');
 if(hash!==metadata.sha256||bytes.length!==metadata.size_bytes)throw Error('Served APK differs from release');
 const result={version:metadata.version,page_status:page.status,apk_status:response.status,bytes:bytes.length,sha256:hash,hash_matches:true,authentication_required:false,browser_interaction_tested:false};
 await writeFile(new URL('../docs/evidence/v3-public-download.json',import.meta.url),JSON.stringify(result,null,2));console.log(result);
}finally{await new Promise((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
