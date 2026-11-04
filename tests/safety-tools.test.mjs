import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {PGlite} from '@electric-sql/pglite';
import request from 'supertest';
import {createApp} from '../backend/app.mjs';
import {migrate} from '../backend/store.mjs';
import {processSafetyCheckins} from '../backend/safety-tools.mjs';

test('private inboxes isolate messages and missed check-ins are delivered once', async () => {
  const db = new PGlite();
  try {
    await migrate({async query(sql, params) {
      if (sql.includes('CREATE TABLE')) {
        await db.exec(sql);
        return {rows: []};
      }
      return db.query(sql, params);
    }});
    const pool = {isReady: () => true, async connect() {
      return {query: (...args) => db.query(...args), release() {}};
    }};
    const api = request(createApp({pool, dbRequired:true, env:{}}));
    const url = '/api/safety';
    const sender = (await api.post(url+'/inbox').expect(201)).body;
    const recipient = (await api.post(url+'/inbox').expect(201)).body;
    const authorization = value => 'Bearer ' + value;
    await api.get(url+'/inbox').set('Authorization', authorization(recipient.invite)).expect(404);
    const alert = {invite: recipient.invite, request_id: randomUUID(), message: 'Test alert'};
    const send = () => api.post(url+'/alerts').send(alert).expect(201);
    assert.equal((await send()).body.status, 'stored_in_app');
    const read = key => api.get(url+'/inbox').set('Authorization', authorization(key)).expect(200);
    assert.equal((await read(sender.access_token)).body.alerts.length, 0);
    assert.equal((await read(recipient.access_token)).body.alerts.length, 1);
    await api.post(url+'/inbox/read').set('Authorization', authorization(recipient.access_token))
      .send({id: alert.request_id}).expect(200);
    assert.equal((await send()).body.status, 'opened_in_app');
    const schedule = () => api.post(url+'/checkins').set('Authorization', authorization(sender.access_token))
      .send({invite: recipient.invite, message: 'Missed check-in', minutes: 1}).expect(201);
    const safe = (await schedule()).body;
    await api.patch(url+'/checkins/'+safe.id).set('Authorization', authorization(sender.access_token))
      .send({status:'safe'}).expect(200);
    await schedule();
    await db.query("UPDATE safety_checkins SET due_at=now()-interval '1 minute'");
    assert.equal(await processSafetyCheckins(db), 1);
    assert.equal(await processSafetyCheckins(db), 0);
    const inbox = (await read(recipient.access_token)).body;
    assert.equal(inbox.alerts.filter(a => a.kind === 'missed_checkin').length, 1);
  } finally {
    await db.close();
  }
});
