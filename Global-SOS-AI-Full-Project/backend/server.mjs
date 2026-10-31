import pg from 'pg';
import {createApp} from './app.mjs';
import {migrate,seedDB} from './store.mjs';
import {monitorSources} from './monitor.mjs';
let pool=null;const dbRequired=!!process.env.DATABASE_URL;
if(dbRequired){const candidate=new pg.Pool({connectionString:process.env.DATABASE_URL,max:8,connectionTimeoutMillis:10000,idleTimeoutMillis:30000});candidate.on('error',()=>console.error(JSON.stringify({event:'database_pool_error'})));try{const c=await candidate.connect();try{await migrate(c);await seedDB(c);}finally{c.release();}pool=candidate;}catch{console.error(JSON.stringify({event:'database_initialization_failed',message:'Check database connection and TLS configuration; no data was reset.'}));await candidate.end();}}
const app=createApp({pool,dbRequired});const server=app.listen(Number(process.env.PORT)||3000,'0.0.0.0',()=>console.log(JSON.stringify({event:'listening',port:Number(process.env.PORT)||3000,storage:pool?'postgresql':dbRequired?'unavailable':'read_only_snapshot'})));
const cleanup=setInterval(async()=>{if(pool)try{await pool.query('DELETE FROM sos_sessions WHERE expires_at<now()');}catch{console.error(JSON.stringify({event:'retention_failed'}));}},60000);cleanup.unref();
const interval=Number(process.env.DIRECTORY_UPDATE_INTERVAL)||86400;let checking=false;const monitor=setInterval(async()=>{if(!pool||checking||!process.env.MONITOR_CONTACT)return;checking=true;try{const db=await pool.connect();try{await monitorSources(db);}finally{db.release();}}catch{console.error(JSON.stringify({event:'source_monitor_failed'}));}finally{checking=false;}},Math.max(interval,3600)*1000);monitor.unref();
for(const sig of ['SIGTERM','SIGINT'])process.on(sig,()=>{clearInterval(cleanup);clearInterval(monitor);server.close(async()=>{await pool?.end();process.exit(0);});setTimeout(()=>process.exit(1),10000).unref();});
