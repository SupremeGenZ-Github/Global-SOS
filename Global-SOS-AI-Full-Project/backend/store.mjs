import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {categories,sha,token} from './core.mjs';
export const seed=JSON.parse(await readFile(new URL('../shared/directory.json',import.meta.url),'utf8'));
export async function migrate(db){await db.query(await readFile(new URL('../database/001_initial.sql',import.meta.url),'utf8'));await db.query("INSERT INTO schema_migrations(version) VALUES('001') ON CONFLICT DO NOTHING");}
export async function seedDB(db){
 await db.query('BEGIN');try{
 await db.query('SELECT version FROM directory_state WHERE singleton=1 FOR UPDATE');
 for(const c of seed.countries)await db.query('INSERT INTO countries(code,name) VALUES($1,$2) ON CONFLICT DO NOTHING',[c.code,c.name]);
 for(const c of categories)await db.query('INSERT INTO categories(id,name) VALUES($1,$2) ON CONFLICT DO NOTHING',[c.id,c.name]);
 for(const s of seed.sources){await db.query('INSERT INTO organizations(id,name,government_affiliation) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[s.id,s.organization,s.affiliation]);await db.query('INSERT INTO sources(id,url,host,organization_id,approved,last_checked) VALUES($1,$2,$3,$1,true,$4) ON CONFLICT DO NOTHING',[s.id,s.url,new URL(s.url).hostname,seed.checked_at]);}
 for(const r of seed.records){const inserted=await db.query('INSERT INTO helplines(id,country,source_id,payload) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING RETURNING id',[r.id,r.country,r.source_id,JSON.stringify(r)]);if(inserted.rows.length)for(const c of r.channels)await db.query('INSERT INTO channels(helpline_id,kind,value,immediate) VALUES($1,$2,$3,$4)',[r.id,c.kind,c.value,c.immediate]);}
 await db.query("INSERT INTO directory_versions(version,actor,notes) VALUES(1,'seed','Government-page checked seed; no operational certification') ON CONFLICT DO NOTHING");await db.query('COMMIT');
 }catch(e){await db.query('ROLLBACK');throw e;}
}
export async function snapshot(db){if(!db)return seed;const v=await db.query('SELECT version FROM directory_state WHERE singleton=1');const rs=await db.query('SELECT payload,revision FROM helplines WHERE published ORDER BY id');return {...seed,version:String(v.rows[0].version),records:rs.rows.map(r=>({...r.payload,revision:r.revision}))};}
export async function audit(db,actor,action,target){await db.query('INSERT INTO audit_logs(actor,action,target) VALUES($1,$2,$3)',[actor,action,target]);}
export async function propose(db,record,actor){
 const s=await db.query('SELECT * FROM sources WHERE id=$1 AND approved',[record.source_id]);if(!s.rows.length)throw Object.assign(new Error('Source must be approved by a maintainer first'),{status:400});
 if(record.source_url!==s.rows[0].url)throw Object.assign(new Error('Source URL does not match approved source'),{status:400});
 const old=await db.query('SELECT revision FROM helplines WHERE id=$1',[record.id]);const id=randomUUID();await db.query("INSERT INTO verification_reviews(id,helpline_id,source_id,kind,payload,base_revision,proposer) VALUES($1,$2,$3,'record',$4,$5,$6)",[id,record.id,record.source_id,JSON.stringify(record),old.rows[0]?.revision??0,actor]);await audit(db,actor,'propose',id);return id;
}
export async function approve(db,id,actor,notes){
 await db.query('BEGIN');try{
 await db.query('SELECT version FROM directory_state WHERE singleton=1 FOR UPDATE');
 const rows=await db.query('SELECT * FROM verification_reviews WHERE id=$1 FOR UPDATE',[id]);const p=rows.rows[0];
 if(!p||p.status!=='pending')throw Object.assign(new Error('Review missing or already decided'),{status:409});
 if(p.proposer===actor)throw Object.assign(new Error('A different role must review the proposal'),{status:403});
 if(p.kind==='source_change')throw Object.assign(new Error('Source changes require a separate record proposal after manual verification'),{status:400});
 const s=await db.query('SELECT approved FROM sources WHERE id=$1',[p.source_id]);if(!s.rows[0]?.approved)throw Object.assign(new Error('Source no longer approved'),{status:409});
 const old=await db.query('SELECT * FROM helplines WHERE id=$1 FOR UPDATE',[p.helpline_id]);const r=old.rows[0];if((r?.revision??0)!==p.base_revision)throw Object.assign(new Error('Record changed; submit a fresh proposal'),{status:409});
 if(r)await db.query('INSERT INTO helpline_history(helpline_id,payload,revision,actor) VALUES($1,$2,$3,$4)',[r.id,r.payload,r.revision,actor]);
 const payload={...p.payload,verification_status:'admin_approved',checked_at:new Date().toISOString(),revision:(r?.revision??0)+1};
 await db.query('INSERT INTO helplines(id,country,source_id,payload,revision,published) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(id) DO UPDATE SET country=excluded.country,source_id=excluded.source_id,payload=excluded.payload,revision=excluded.revision,published=excluded.published,updated_at=now()',[p.helpline_id,payload.country,p.source_id,JSON.stringify(payload),payload.revision,payload.published!==false]);
 await db.query('DELETE FROM channels WHERE helpline_id=$1',[p.helpline_id]);for(const c of payload.channels)await db.query('INSERT INTO channels(helpline_id,kind,value,immediate) VALUES($1,$2,$3,$4)',[p.helpline_id,c.kind,c.value,c.immediate]);
 await db.query("UPDATE verification_reviews SET status='approved',reviewer=$2,notes=$3,reviewed_at=now() WHERE id=$1",[id,actor,notes]);
 const v=await db.query('UPDATE directory_state SET version=version+1 WHERE singleton=1 RETURNING version');await db.query('INSERT INTO directory_versions(version,actor,notes) VALUES($1,$2,$3)',[v.rows[0].version,actor,notes]);await audit(db,actor,'approve',id);await db.query('COMMIT');return String(v.rows[0].version);
 }catch(e){await db.query('ROLLBACK');throw e;}
}
export async function createSOS(db,country){const id=randomUUID(),secret=token();await db.query("INSERT INTO sos_sessions(id,capability_hash,status,expires_at,country) VALUES($1,$2,'active',now()+interval '1 hour',$3)",[id,sha(secret),country]);return {id,capability:secret,expires_in:3600,notification_status:'not_sent'};}
