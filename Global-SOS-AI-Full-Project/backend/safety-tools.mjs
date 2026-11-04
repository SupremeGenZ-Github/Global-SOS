import {randomBytes, randomUUID} from 'node:crypto';
import {rateLimit} from 'express-rate-limit';
import {z} from 'zod';
import {sha} from './core.mjs';

const newToken = () => randomBytes(32).toString('base64url');
const token = z.string().regex(/^[A-Za-z0-9_-]{43}$/);
const message = z.string().trim().min(1).max(500);
const id = z.string().uuid();

async function findInbox(db, column, value) {
  const {rows} = await db.query(
    column === 'owner'
      ? 'SELECT id FROM safety_inboxes WHERE owner_hash=$1'
      : 'SELECT id FROM safety_inboxes WHERE invite_hash=$1',
    [sha(token.parse(value))],
  );
  if (!rows[0]) throw Object.assign(Error('Inbox or invitation unavailable'), {status: 404});
  return rows[0].id;
}

export function mountSafetyTools(app, {run, withDB}) {
  const prefix = '/api/safety';
  const limit = max => rateLimit({windowMs: 3600000, limit: max, standardHeaders: 'draft-8', legacyHeaders: false});
  const owner = (db, req) => findInbox(db, 'owner', req.get('authorization')?.replace(/^Bearer /, ''));

  app.post(prefix + '/inbox', limit(8), run(async (_req, res) => {
    const accessToken = newToken();
    const invite = newToken();
    await withDB(db => db.query(
      'INSERT INTO safety_inboxes(id,owner_hash,invite_hash) VALUES ($1,$2,$3)',
      [randomUUID(), sha(accessToken), sha(invite)],
    ));
    res.status(201).json({access_token: accessToken, invite});
  }));

  app.get(prefix + '/inbox', run(async (req, res) => {
    res.json(await withDB(async db => {
      const inbox = await owner(db, req);
      const alerts = await db.query(
        "SELECT id,message,kind,created_at,read_at FROM safety_messages WHERE inbox_id=$1 AND created_at > now()-interval '7 days' ORDER BY created_at DESC LIMIT 50",
        [inbox],
      );
      const checkins = await db.query(
        'SELECT id,due_at,status FROM safety_checkins WHERE owner_id=$1 ORDER BY created_at DESC LIMIT 20',
        [inbox],
      );
      return {alerts: alerts.rows, checkins: checkins.rows};
    }));
  }));

  app.delete(prefix + '/inbox', run(async (req, res) => {
    await withDB(async db => db.query('DELETE FROM safety_inboxes WHERE id=$1', [await owner(db, req)]));
    res.json({status: 'deleted'});
  }));

  app.post(prefix + '/inbox/read', run(async (req, res) => {
    const alert = id.parse(req.body.id);
    await withDB(async db => db.query(
      'UPDATE safety_messages SET read_at=COALESCE(read_at,now()) WHERE id=$1 AND inbox_id=$2',
      [alert, await owner(db, req)],
    ));
    res.json({status: 'recorded'});
  }));

  app.post(prefix + '/alerts', limit(12), run(async (req, res) => {
    const body = z.object({invite: token, message, request_id: id}).parse(req.body);
    await withDB(async db => {
      const inbox = await findInbox(db, 'invite', body.invite);
      await db.query(
        "INSERT INTO safety_messages(id,inbox_id,message,kind) VALUES ($1,$2,$3,'alert') ON CONFLICT (id) DO NOTHING",
        [body.request_id, inbox, body.message],
      );
      const {rows} = await db.query('SELECT id,read_at FROM safety_messages WHERE id=$1 AND inbox_id=$2 AND message=$3 AND kind=\'alert\'', [body.request_id, inbox, body.message]);
      if (!rows[0]) throw Object.assign(Error('Request already used'), {status: 409});
      res.status(201).json({status: rows[0].read_at ? 'opened_in_app' : 'stored_in_app'});
    });
  }));

  app.post(prefix + '/checkins', limit(10), run(async (req, res) => {
    const body = z.object({invite: token, minutes: z.number().int().min(1).max(1440), message}).parse(req.body);
    res.status(201).json(await withDB(async db => {
      const sender = await owner(db, req);
      const recipient = await findInbox(db, 'invite', body.invite);
      if (recipient === sender) throw Object.assign(Error('Choose a different inbox for your trusted contact'), {status: 400});
      const {rows} = await db.query(
        "INSERT INTO safety_checkins(id,owner_id,recipient_id,message,due_at) VALUES ($1,$2,$3,$4,now()+$5::integer*interval '1 minute') RETURNING id,due_at,status",
        [randomUUID(), sender, recipient, body.message, body.minutes],
      );
      return rows[0];
    }));
  }));

  app.patch(prefix + '/checkins/:id', run(async (req, res) => {
    const checkin = id.parse(req.params.id);
    const status = z.enum(['safe', 'cancelled']).parse(req.body.status);
    const result = await withDB(async db => db.query(
      "UPDATE safety_checkins SET status=$1 WHERE id=$2 AND owner_id=$3 AND status='pending' RETURNING status",
      [status, checkin, await owner(db, req)],
    ));
    if (!result.rows.length) throw Object.assign(Error('Check-in is no longer pending'), {status: 409});
    res.json(result.rows[0]);
  }));
}

// One atomic statement keeps the scheduled delivery and status in sync after a restart.
export async function processSafetyCheckins(db) {
  const {rows} = await db.query(`
    WITH due AS (
      UPDATE safety_checkins SET status='alert_stored'
      WHERE id IN (
        SELECT id FROM safety_checkins WHERE status='pending' AND due_at<=now()
        ORDER BY due_at LIMIT 50 FOR UPDATE SKIP LOCKED
      )
      RETURNING id, recipient_id, message
    )
    INSERT INTO safety_messages(id,inbox_id,message,kind)
    SELECT id, recipient_id, message, 'missed_checkin' FROM due
    ON CONFLICT (id) DO NOTHING
    RETURNING id
  `);
  await db.query("DELETE FROM safety_messages WHERE created_at < now()-interval '7 days'");
  await db.query("DELETE FROM safety_checkins WHERE status<>'pending' AND due_at < now()-interval '7 days'");
  return rows.length;
}
