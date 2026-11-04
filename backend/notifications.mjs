import {sha,equalSecret} from './core.mjs';

export function notificationConfig(env){return {configured:!!env.ALERT_CLIENT_TOKEN&&env.ALERT_CLIENT_TOKEN.length>=32,methods:{sms:!!(env.TWILIO_ACCOUNT_SID&&env.TWILIO_AUTH_TOKEN&&env.TWILIO_SMS_FROM),whatsapp:!!(env.TWILIO_ACCOUNT_SID&&env.TWILIO_AUTH_TOKEN&&env.TWILIO_WHATSAPP_FROM&&env.TWILIO_WHATSAPP_TEMPLATE_SID),email:!!(env.RESEND_API_KEY&&env.ALERT_EMAIL_FROM)}};}
export async function sendNotifications({db,env,session,clientToken,contacts,message,request=fetch}){
 if(!equalSecret(clientToken,env.ALERT_CLIENT_TOKEN))throw Object.assign(Error('Configure the private alert token in My Safety first'),{status:401});
 const allowed=new Set((env.ALERT_ALLOWED_RECIPIENTS??'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean));
 const results=[];
 for(const c of contacts){
  const recipient=c.recipient.trim(),kind=c.kind,key=sha(kind+'|'+recipient.toLowerCase());
  if(!allowed.has(recipient.toLowerCase())){results.push({kind,recipient,status:'not_allowed',detail:'The operator must approve this trusted recipient first.'});continue;}
  const config=notificationConfig(env);
  if(!config.methods[kind]){results.push({kind,recipient,status:'not_configured'});continue;}
  // Reserve before network I/O: a retry after a timeout must not duplicate an alert.
  const inserted=await db.query("INSERT INTO notification_attempts(session_id,recipient_hash,kind,status) VALUES($1,$2,$3,'submitting') ON CONFLICT DO NOTHING RETURNING status",[session.id,key,kind]);
  if(!inserted.rows.length){const old=(await db.query('SELECT status FROM notification_attempts WHERE session_id=$1 AND recipient_hash=$2 AND kind=$3',[session.id,key,kind])).rows[0];results.push({kind,recipient,recipient_hash:key,status:old?.status??'unknown'});continue;}
  let status='unknown',providerId=null;
  try{
   let response;
   if(kind==='email'){
    response=await request('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+env.RESEND_API_KEY,'Content-Type':'application/json','Idempotency-Key':session.id+'-'+key},signal:AbortSignal.timeout(10000),body:JSON.stringify({from:env.ALERT_EMAIL_FROM,to:[recipient],subject:'Global SOS AI — trusted contact alert',text:message})});
   }else{
    const form=new URLSearchParams(kind==='sms'?{To:recipient,From:env.TWILIO_SMS_FROM,Body:message}:{To:'whatsapp:'+recipient,From:env.TWILIO_WHATSAPP_FROM,ContentSid:env.TWILIO_WHATSAPP_TEMPLATE_SID,ContentVariables:JSON.stringify({'1':message})});
    response=await request('https://api.twilio.com/2010-04-01/Accounts/'+encodeURIComponent(env.TWILIO_ACCOUNT_SID)+'/Messages.json',{method:'POST',headers:{Authorization:'Basic '+Buffer.from(env.TWILIO_ACCOUNT_SID+':'+env.TWILIO_AUTH_TOKEN).toString('base64'),'Content-Type':'application/x-www-form-urlencoded'},signal:AbortSignal.timeout(10000),body:form.toString()});
   }
   const data=await response.json();
   if(response.ok){status=kind==='email'?'accepted':String(data.status??'accepted');providerId=data.sid??data.id??null;}else status='failed';
  }catch{status='unknown';}
  await db.query('UPDATE notification_attempts SET status=$4,provider_id=$5 WHERE session_id=$1 AND recipient_hash=$2 AND kind=$3',[session.id,key,kind,status,providerId]);
  results.push({kind,recipient,recipient_hash:key,status});
 }
 return results;
}

export async function notificationStatus({db,env,session,request=fetch}){
 const rows=(await db.query('SELECT recipient_hash,kind,status,provider_id FROM notification_attempts WHERE session_id=$1',[session.id])).rows;
 for(const row of rows){
  if(!row.provider_id)continue;
  try{
   const email=row.kind==='email';
   const url=email?'https://api.resend.com/emails/'+encodeURIComponent(row.provider_id):'https://api.twilio.com/2010-04-01/Accounts/'+encodeURIComponent(env.TWILIO_ACCOUNT_SID)+'/Messages/'+encodeURIComponent(row.provider_id)+'.json';
   const auth=email?'Bearer '+env.RESEND_API_KEY:'Basic '+Buffer.from(env.TWILIO_ACCOUNT_SID+':'+env.TWILIO_AUTH_TOKEN).toString('base64');
   const response=await request(url,{headers:{Authorization:auth},signal:AbortSignal.timeout(8000)});
   if(response.ok){const data=await response.json();row.status=String(email?data.last_event??row.status:data.status??row.status);await db.query('UPDATE notification_attempts SET status=$4 WHERE session_id=$1 AND recipient_hash=$2 AND kind=$3',[session.id,row.recipient_hash,row.kind,row.status]);}
  }catch{/* Retain the last confirmed provider state. */}
 }
 return rows.map(({kind,status,recipient_hash})=>({kind,status,recipient_hash}));
}
