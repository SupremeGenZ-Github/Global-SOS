import pg from 'pg';
import {migrate,seedDB} from './store.mjs';
export function databaseError(error){
 const code=String(error?.code??'');
 if(['28P01','28000'].includes(code))return {code:'authentication_failed',action:'Replace DATABASE_URL with the complete current database connection URL in Render Environment.'};
 if(code==='3D000')return {code:'database_missing',action:'Check the database name in DATABASE_URL.'};
 if(['ENOTFOUND','EAI_AGAIN'].includes(code))return {code:'host_unreachable',action:'Check DATABASE_URL. Render internal URLs require the same region and workspace.'};
 if(['ECONNREFUSED','ETIMEDOUT','ECONNRESET','57P03','53300'].includes(code))return {code:'connection_unavailable',action:'Check that PostgreSQL is available and the service can reach its host.'};
 if(/CERT|SSL|TLS/.test(code))return {code:'tls_error',action:'Use the provider connection URL with its original TLS parameters.'};
 return {code:'initialization_failed',action:'Check PostgreSQL availability, connection URL and database permissions. No data was reset.'};
}
export function createDatabase({url,Pool=pg.Pool,prepare=async c=>{await migrate(c);await seedDB(c);},retryMs=30000,onEvent=()=>{}}={}){
 let pool=null,ready=false,busy=false,closed=false,timer=null,problem=null;
 const configured=!!url?.trim();
 async function retry(){
  if(!configured||busy||closed||ready)return;
  busy=true;let client;
  try{
   if(!pool){
    const parsed=new URL(url);if(!['postgres:','postgresql:'].includes(parsed.protocol))throw Object.assign(Error('Invalid PostgreSQL URL'),{code:'INVALID_DATABASE_URL'});
    pool=new Pool({connectionString:url,max:8,connectionTimeoutMillis:10000,idleTimeoutMillis:30000});
    pool.on('error',e=>{ready=false;problem=databaseError(e);onEvent({event:'database_disconnected',code:problem.code});});
   }
   client=await pool.connect();await prepare(client);ready=true;problem=null;onEvent({event:'database_ready'});
  }catch(e){ready=false;problem=databaseError(e);if(e?.code==='INVALID_DATABASE_URL')problem={code:'invalid_url',action:'DATABASE_URL must begin with postgres:// or postgresql://, not https://.'};onEvent({event:'database_unavailable',code:problem.code});}
  finally{client?.release();busy=false;}
 }
 const status=()=>({configured,ready,state:ready?'connected':configured?(busy?'connecting':'unavailable'):'not_configured',...(problem??{}),retry_seconds:configured&&!ready?Math.ceil(retryMs/1000):null});
 return {isReady:()=>ready,status,retry,start(){timer=setInterval(()=>void retry(),retryMs);timer.unref?.();void retry();},async connect(){if(!ready)throw Object.assign(Error('PostgreSQL unavailable'),{status:503});try{return await pool.connect();}catch(e){ready=false;problem=databaseError(e);throw Object.assign(Error('PostgreSQL unavailable'),{status:503});}},async query(...args){const c=await this.connect();try{return await c.query(...args);}finally{c.release();}},async close(){closed=true;clearInterval(timer);await pool?.end();}};
}
