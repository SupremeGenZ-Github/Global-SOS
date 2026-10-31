import robotsParser from 'robots-parser';
import {randomUUID} from 'node:crypto';
import {sha} from './core.mjs';
import {pathToFileURL} from 'node:url';
const agent='GlobalSOSSourceMonitor';
async function boundedText(response,max=2000000){if(Number(response.headers.get('content-length'))>max)throw Error('Oversize');let count=0;const chunks=[];for await(const chunk of response.body){count+=chunk.length;if(count>max)throw Error('Oversize');chunks.push(chunk);}return Buffer.concat(chunks).toString('utf8');}
export async function inspectSource(source,fetcher=fetch){
 const url=new URL(source.url);if(!source.approved||url.protocol!=='https:'||url.hostname!==source.host||url.username||url.password||url.port)throw Error('Unapproved source');
 const contact=process.env.MONITOR_CONTACT||'manual-test-no-contact';
 const options={signal:AbortSignal.timeout(15000),redirect:'manual',headers:{'User-Agent':`${agent}/0.1 (${contact.replace(/[\r\n]/g,'')})`}};
 const robotURL=new URL('/robots.txt',url);const robots=await fetcher(robotURL,options);if(robots.status!==404&&!robots.ok)throw Error('Robots unavailable; skipped');
 const rules=robotsParser(robotURL.href,robots.status===404?'':await boundedText(robots,200000));if(rules.isAllowed(url.href,agent)===false)throw Error('Robots disallows path');const delay=Number(rules.getCrawlDelay(agent)||0);if(delay>30)throw Error('Crawl delay requires manual scheduling');
 // Callers space requests by host; never follow redirects or parse AI-generated contacts.
 if(delay>0)await new Promise(resolve=>setTimeout(resolve,delay*1000));
 const page=await fetcher(url,{...options,signal:AbortSignal.timeout(15000)});if(!page.ok||page.status>=300)throw Error('Source unavailable or redirected');const text=await boundedText(page);return {hash:sha(text),crawlDelay:Math.max(delay,2)};
}
export async function monitorSources(db,fetcher=fetch){const rows=(await db.query('SELECT * FROM sources WHERE approved ORDER BY id')).rows;const lastByHost=new Map();for(const s of rows){try{const wait=(lastByHost.get(s.host)??0)-Date.now();if(wait>0)await new Promise(r=>setTimeout(r,wait));const result=await inspectSource(s,fetcher);lastByHost.set(s.host,Date.now()+result.crawlDelay*1000);if(s.last_hash&&s.last_hash!==result.hash)await db.query("INSERT INTO verification_reviews(id,source_id,kind,payload,proposer) VALUES($1,$2,'source_change',$3,'source-monitor') ON CONFLICT DO NOTHING",[randomUUID(),s.id,JSON.stringify({old_hash:s.last_hash,new_hash:result.hash,url:s.url,note:'Page changed; contact details may be unchanged. Human review required.'})]);await db.query("UPDATE sources SET last_hash=$2,last_checked=now(),robots_status='allowed' WHERE id=$1",[s.id,result.hash]);}catch{await db.query("UPDATE sources SET last_checked=now(),robots_status='skipped_or_unavailable' WHERE id=$1",[s.id]);}}}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const {default:pg}=await import('pg');if(!process.env.DATABASE_URL)throw Error('DATABASE_URL required');const p=new pg.Pool({connectionString:process.env.DATABASE_URL});const c=await p.connect();try{await monitorSources(c);}finally{c.release();await p.end();}}
