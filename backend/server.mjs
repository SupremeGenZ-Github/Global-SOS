import {createApp} from './app.mjs';
import {createDatabase} from './database.mjs';
import {monitorSources} from './monitor.mjs';
import {processSafetyCheckins} from './safety-tools.mjs';
const database=createDatabase({url:process.env.DATABASE_URL,onEvent:event=>console.log(JSON.stringify(event))});
const dbRequired=!!process.env.DATABASE_URL?.trim();
const pool=dbRequired?database:null;
const app=createApp({pool,dbRequired});
const server=app.listen(Number(process.env.PORT)||3000,'0.0.0.0',()=>console.log(JSON.stringify({event:'listening',port:Number(process.env.PORT)||3000})));
database.start();
let processingCheckins = false;
const checkins = setInterval(async () => {
 if (!database.isReady() || processingCheckins) return;
 processingCheckins = true;
 try {
  const client = await database.connect();
  try { await processSafetyCheckins(client); } finally { client.release(); }
 } catch {
  console.error(JSON.stringify({event:'safety_checkin_processing_failed'}));
 } finally {
  processingCheckins = false;
 }
}, 15000);
checkins.unref();
const cleanup=setInterval(async()=>{if(database.isReady())try{await database.query('DELETE FROM sos_sessions WHERE expires_at<now()');}catch{console.error(JSON.stringify({event:'retention_failed'}));}},60000);cleanup.unref();
let checking=false;const monitor=setInterval(async()=>{if(!database.isReady()||checking||!process.env.MONITOR_CONTACT)return;checking=true;try{const db=await database.connect();try{await monitorSources(db);}finally{db.release();}}catch{console.error(JSON.stringify({event:'source_monitor_failed'}));}finally{checking=false;}},Math.max(Number(process.env.DIRECTORY_UPDATE_INTERVAL)||86400,3600)*1000);monitor.unref();
for(const sig of ['SIGTERM','SIGINT'])process.on(sig,()=>{clearInterval(cleanup);clearInterval(monitor);clearInterval(checkins);server.close(async()=>{await database.close();process.exit(0);});setTimeout(()=>process.exit(1),10000).unref();});
