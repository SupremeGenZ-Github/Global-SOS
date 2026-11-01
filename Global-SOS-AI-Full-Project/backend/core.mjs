import {createHash,timingSafeEqual,randomBytes} from 'node:crypto';
import {readFileSync} from 'node:fs';
export const categories=JSON.parse(readFileSync(new URL('../shared/categories.json',import.meta.url)));
export const categoryIds=categories.map(x=>x.id);
export const sha=x=>createHash('sha256').update(x).digest('hex');
export const token=()=>randomBytes(32).toString('base64url');
export function equalSecret(got,expected){if(!expected||expected.length<32||typeof got!=='string')return false;return timingSafeEqual(Buffer.from(sha(got)),Buffer.from(sha(expected)));}
const faq=JSON.parse(readFileSync(new URL('../shared/assistant-faq.json',import.meta.url)));
export function everydayReply(text){if(urgent(text))return null;return faq.find(x=>new RegExp(x.pattern,'i').test(text.trim()))?.answer??null;}
export function classify(text){
 const t=text.toLowerCase();
 const rules=[['mental',/suicid|self.harm|kill myself|end my life/],['fire',/fire|burning|smoke|flames|आग/],['ambulance',/unconscious|not breathing|can.t breathe|cannot breathe|choking|stabbed|chest pain|bleeding|ambulance|heart attack|medical|injur/],['poison',/poison|overdose|swallowed chemical/],['domestic',/domestic|partner.*(hit|hurt)|abuse/],['police',/attack|robbe|police|danger|assault|gun|stalk|rape|पुलिस/],['child',/child|kidnap/],['cyber',/cyber|scam|fraud|hack/],['road',/crash|road accident|collision/],['flood',/flood|earthquake|tsunami/],['marine',/sea|boat|drowning/],['mountain',/mountain|hiking|wilderness/],['utilities',/gas leak|electric/],['women',/women|woman/],['tourist',/tourist|passport/],['railway',/railway|train/],['senior',/elderly|senior/],['disability',/disabil|deaf/],['consumer',/consumer|refund/],['workplace',/workplace/],['missing',/missing/]];
 return rules.find(([,re])=>re.test(t))?.[0]??'other';
}
export const urgent=t=>/unconscious|not breathing|can.t breathe|cannot breathe|choking|stabbed|severe bleeding|\bfire\b|attack|immediate|gun|suicid|kill myself|overdose|earthquake|flood|gas leak/i.test(t);
export function filterRecords(records,{country,category,q='',channel,region}={}){
 if(!country)return [];
 return records.filter(r=>r.country===country&&(!category||r.categories.includes(category))&&(!channel||r.channels.some(c=>c.kind===channel))&&(!region||!r.region||r.region.toLowerCase().includes(region.toLowerCase()))&&(!q||`${r.name} ${r.categories.join(' ')} ${r.region??''} ${r.channels.map(c=>c.value).join(' ')}`.toLowerCase().includes(q.toLowerCase())));
}
export function responseFor(text,category,records){
 if(!records.length)return 'Official helpline information not yet verified for this country and category. Confirm your country and browse the directory. If danger is immediate, use your phone’s emergency calling screen or seek nearby help.';
 if(urgent(text))return 'If you are in immediate danger, use a suitable emergency contact below now. Opening a dialer does not confirm that a call connected.';
 if(category==='other')return /^(hi|hello|hey|thanks|thank you)[!. ]*$/i.test(text.trim())?'Hello. Tell me what kind of help you need and confirm your country.':'Choose a service below or describe the help you need. This assistant routes to source-checked contacts; it does not provide medical diagnosis.';
 return 'These source-checked services match your request. Read the jurisdiction and channel notes before contacting them.';
}
export function safeIntent(modelOutput){const x=String(modelOutput).trim().toLowerCase().replace(/[^a-z]/g,'');return categoryIds.includes(x)?x:null;}
export function validateChannel(c){
 if(!c||!['phone','sms','whatsapp','email','web'].includes(c.kind)||typeof c.value!=='string')return false;
 if(c.kind==='phone'||c.kind==='sms')return /^\+?[0-9][0-9 ()-]{1,24}$/.test(c.value);
 if(c.kind==='whatsapp')return /^\+[1-9][0-9]{7,14}$/.test(c.value);
 if(c.kind==='email')return /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(c.value);
 try{return new URL(c.value).protocol==='https:';}catch{return false;}
}
