import {test} from 'node:test';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {migrate,seedDB,createSOS} from '../backend/store.mjs';
import {sendNotifications,notificationStatus} from '../backend/notifications.mjs';

test('provider alerts require a private token, approved recipients, and preserve queued/delivery status without duplicate submission',async()=>{
 const db=new PGlite();await db.waitReady;
 const adapter={query:async(t,v)=>v?db.query(t,v):/;/.test(t)?(await db.exec(t)).at(-1):db.query(t)};
 try {
  await migrate(adapter);await seedDB(adapter);const session=await createSOS(adapter,'IN');
  const env={ALERT_CLIENT_TOKEN:'a'.repeat(40),ALERT_ALLOWED_RECIPIENTS:'+12025550123',TWILIO_ACCOUNT_SID:'ACtest',TWILIO_AUTH_TOKEN:'test',TWILIO_SMS_FROM:'+12025550124'};
  const contacts=[{kind:'sms',recipient:'+12025550123'}];let requests=0;
  const mock=async()=>{requests++;return new Response(JSON.stringify({sid:'SMtest',status:'queued'}),{status:201});};
  await assert.rejects(sendNotifications({db:adapter,env,session,clientToken:'wrong',contacts,message:'Please contact me.',request:mock}),/private alert token/);
  const denied=await sendNotifications({db:adapter,env,session,clientToken:env.ALERT_CLIENT_TOKEN,contacts:[{kind:'sms',recipient:'+12025550999'}],message:'Please contact me.',request:mock});assert.equal(denied[0].status,'not_allowed');assert.equal(requests,0);
  const first=await sendNotifications({db:adapter,env,session,clientToken:env.ALERT_CLIENT_TOKEN,contacts,message:'Please contact me.',request:mock});assert.equal(first[0].status,'queued');
  await sendNotifications({db:adapter,env,session,clientToken:env.ALERT_CLIENT_TOKEN,contacts,message:'Please contact me.',request:mock});assert.equal(requests,1);
  const status=await notificationStatus({db:adapter,env,session,request:async()=>new Response(JSON.stringify({status:'delivered'}))});assert.equal(status[0].status,'delivered');assert.equal(status[0].provider_id,undefined);
 }finally{await db.close();}
});

test('unconfigured and ambiguous provider outcomes never report delivery',async()=>{
 const db=new PGlite();await db.waitReady;const adapter={query:async(t,v)=>v?db.query(t,v):/;/.test(t)?(await db.exec(t)).at(-1):db.query(t)};
 try{await migrate(adapter);await seedDB(adapter);const session=await createSOS(adapter,'IN');const env={ALERT_CLIENT_TOKEN:'a'.repeat(40),ALERT_ALLOWED_RECIPIENTS:'friend@example.com'};
 const noProvider=await sendNotifications({db:adapter,env,session,clientToken:env.ALERT_CLIENT_TOKEN,contacts:[{kind:'email',recipient:'friend@example.com'}],message:'Please contact me.'});assert.equal(noProvider[0].status,'not_configured');
 env.RESEND_API_KEY='fake';env.ALERT_EMAIL_FROM='owner@example.com';const unknown=await sendNotifications({db:adapter,env,session,clientToken:env.ALERT_CLIENT_TOKEN,contacts:[{kind:'email',recipient:'friend@example.com'}],message:'Please contact me.',request:async()=>{throw Error('timeout');}});assert.equal(unknown[0].status,'unknown');
 }finally{await db.close();}
});
