import test from 'node:test';import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';import request from 'supertest';
import {migrate,seedDB,seed} from '../backend/store.mjs';import {createApp} from '../backend/app.mjs';
test('an outage preserves the last reviewed database snapshot including withdrawals',async()=>{
 const db=new PGlite();try{await migrate(db);await seedDB(db);const withdrawn=seed.records[0].id;await db.query('UPDATE helplines SET published=false WHERE id=$1',[withdrawn]);let healthy=true;
 const pool={isReady:()=>healthy,async connect(){if(!healthy)throw Object.assign(Error('Unavailable'),{status:503});return {query:(...args)=>db.query(...args),release(){}};}};
 const app=createApp({pool,dbRequired:true,env:{}});const original=await request(app).get('/api/directory').expect(200);assert.equal(original.body.authoritative,true);assert.ok(!original.body.records.some(r=>r.id===withdrawn));
 healthy=false;const cached=await request(app).get('/api/directory?version='+original.body.version).expect(200);assert.equal(cached.body.storage,'last_known_database');assert.equal(cached.body.authoritative,false);assert.ok(!cached.body.records.some(r=>r.id===withdrawn));assert.equal(cached.body.unchanged,undefined);
 await request(app).get('/ready').expect(503);await request(app).post('/api/sos').send({country:'IN'}).expect(503);
 }finally{await db.close();}
});
