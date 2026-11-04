import {useEffect, useState} from 'react';
import type {AlertContact} from './AlertSettings';

type Inbox = {access_token: string; invite: string};
type Alert = {id: string; message: string; created_at: string; read_at: string|null};
type Checkin = {id: string; due_at: string; status: string};
type Fix = {lat: number; lng: number; accuracy: number; timestamp: number; lastKnown: boolean};

async function request(path: string, method = 'GET', body?: object, key?: string) {
  const response = await fetch('/api/safety' + path, {
    method, signal: AbortSignal.timeout(10000),
    headers: {'Content-Type': 'application/json', ...(key ? {Authorization: 'Bearer ' + key} : {})},
    body: body ? JSON.stringify(body) : undefined,
  });
  if (response.status === 204) return null;
  const data = await response.json();
  if (!response.ok) throw Error(data.error || 'Safety service unavailable');
  return data;
}

export function SafetyHub({contacts, quiet}: {contacts: AlertContact[]; quiet: boolean}) {
  const [inbox, setInbox] = useState<Inbox|null>(() => {
    try { return JSON.parse(localStorage.getItem('sos_v5_inbox') || 'null'); }
    catch { return null; }
  });
  const [invite, setInvite] = useState('');
  const [minutes, setMinutes] = useState(30);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [checkins, setCheckins] = useState<Checkin[]>([]);
  const [fix, setFix] = useState<Fix|null>(null);
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [locating, setLocating] = useState(false);
  const [contactId, setContactId] = useState('');
  const [includeLocation, setIncludeLocation] = useState(false);
  const contact = contacts.find(item => item.id === contactId);
  const number = contact?.phone.replace(/[^+0-9]/g, '') ?? '';
  const positionText = fix
    ? `${fix.lastKnown || Date.now()-fix.timestamp > 120000 ? 'Last known location' : 'Location fix'} at ${new Date(fix.timestamp).toLocaleString()}, ±${Math.round(fix.accuracy)} m. https://maps.google.com/?q=${fix.lat},${fix.lng}`
    : '';
  const alertText = (quiet ? 'Please check in with me when you can.' : 'Global SOS: I need help. Please contact me.') +
    (includeLocation && positionText ? ' ' + positionText : '');

  async function refresh(key = inbox?.access_token) {
    if (!key) return;
    const data = await request('/inbox', 'GET', undefined, key);
    setAlerts(data.alerts);
    setCheckins(data.checkins);
  }

  useEffect(() => {
    if (!inbox) return;
    const poll = () => {
      if (!document.hidden) void refresh(inbox.access_token).catch(() => {});
    };
    poll();
    const timer = window.setInterval(poll, 30000);
    return () => window.clearInterval(timer);
  }, [inbox]);

  async function perform(action: () => Promise<void>) {
    if (busy) return;
    setBusy(true);
    try { await action(); }
    catch (error) { setNotice(error instanceof Error ? error.message : 'Action unavailable'); }
    finally { setBusy(false); }
  }

  function locate() {
    if (!navigator.geolocation) return setNotice('Location access is unavailable in this browser.');
    setLocating(true);
    navigator.geolocation.getCurrentPosition(p => {
      setFix({lat:p.coords.latitude, lng:p.coords.longitude, accuracy:p.coords.accuracy, timestamp:p.timestamp, lastKnown:false});
      setLocating(false);
      setNotice('Review the location before sharing.');
    }, () => {
      setLocating(false);
      setFix(previous => previous ? {...previous, lastKnown:true} : null);
      setNotice('A fresh location is unavailable. Check browser permissions or continue without location.');
    }, {enableHighAccuracy:true, maximumAge:0, timeout:12000});
  }

  async function share(text: string) {
    try {
      if (navigator.share) {
        await navigator.share({text});
        setNotice('Share sheet completed. Delivery is unconfirmed.');
      } else {
        await navigator.clipboard.writeText(text);
        setNotice('Copied. Paste into the platform you choose.');
      }
    } catch (error) {
      if (!(error instanceof Error && error.name === 'AbortError')) setNotice('Sharing unavailable. Select and copy the preview.');
    }
  }

  return <section className="v5-safety-hub" aria-label="Safety tools">
    <article className="service-card">
      <h2>Share my location</h2>
      <p>Request a single fix, review the timestamp, then choose how to share it.</p>
      <button disabled={locating} onClick={locate}>{locating ? 'Getting location…' : 'Get location'}</button>
      {fix && <>
        <p className="share-preview">{positionText}</p>
        <button onClick={() => void share(positionText)}>Share location</button>
        <label className="toggle"><input type="checkbox" checked={includeLocation} onChange={e => setIncludeLocation(e.target.checked)}/> Include this fix in the alert preview</label>
      </>}
    </article>
    <article className="service-card">
      <h2>Send a trusted-contact alert</h2>
      <p className="share-preview">{alertText}</p>
      <label>Trusted contact <select value={contactId} onChange={e => setContactId(e.target.value)}>
        <option value="">Choose a contact</option>
        {contacts.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
      </select></label>
      <div className="button-row">
        {number && <a className="contact primary" href={`sms:${number}?body=${encodeURIComponent(alertText)}`}>Open SMS</a>}
        {/^\+[1-9][0-9]{7,14}$/.test(number) && <a className="contact primary" href={`https://wa.me/${number.slice(1)}?text=${encodeURIComponent(alertText)}`} target="_blank" rel="noreferrer">Open WhatsApp</a>}
        <button onClick={() => void share(alertText)}>Other apps / copy</button>
      </div>
      <p>SMS and WhatsApp open a message for you to send. A share sheet cannot confirm delivery.</p>
      <label>Contact’s private app invite <input value={invite} onChange={e => setInvite(e.target.value.trim())} maxLength={43} autoComplete="off" spellCheck={false}/></label>
      <button disabled={busy || invite.length !== 43} onClick={() => void perform(async () => {
        await request('/alerts', 'POST', {invite, message:alertText, request_id:crypto.randomUUID()});
        setNotice('Stored in the contact’s inbox. Opening is unconfirmed.');
      })}>Send in-app alert</button>
    </article>
    <article className="service-card">
      <h2>Private inbox and timed check-in</h2>
      <p>Share the invite only with trusted people. This browser stores the inbox key locally. Open the inbox to see alerts.</p>
      {inbox ? <>
        <label>My invite <input readOnly value={inbox.invite}/></label>
        <div className="button-row">
          <button onClick={() => void share(inbox.invite)}>Share invite</button>
          <button disabled={busy} onClick={() => void perform(() => refresh())}>Refresh inbox</button>
          <button disabled={busy} onClick={() => {
            if (!window.confirm('Delete this inbox, its alerts and linked check-ins?')) return;
            void perform(async () => {
              await request('/inbox', 'DELETE', undefined, inbox.access_token);
              localStorage.removeItem('sos_v5_inbox');
              setInbox(null); setAlerts([]); setCheckins([]);
            });
          }}>Delete inbox</button>
        </div>
        {alerts.map(alert => <div className="history-item" key={alert.id}>
          <p>{alert.message}</p><small>{new Date(alert.created_at).toLocaleString()}</small>
          {!alert.read_at && <button disabled={busy} onClick={() => void perform(async () => {
            await request('/inbox/read', 'POST', {id:alert.id}, inbox.access_token);
            await refresh();
          })}>Acknowledge</button>}
        </div>)}
        <label>Check in within minutes <input type="number" min={1} max={1440} value={minutes} onChange={e => setMinutes(Number(e.target.value))}/></label>
        <button disabled={busy || invite.length !== 43 || !Number.isInteger(minutes) || minutes < 1 || minutes > 1440} onClick={() => void perform(async () => {
          await request('/checkins', 'POST', {invite, minutes, message:'I missed my planned Global SOS check-in. Please contact me.'}, inbox.access_token);
          setNotice('Check-in saved. The server attempts inbox delivery after the deadline.');
          await refresh();
        })}>Schedule for the invited contact</button>
        <p>Check-ins use the same invite entered above. A sleeping or unavailable server can delay them.</p>
        {checkins.map(item => <div className="history-item" key={item.id}>
          <p>{new Date(item.due_at).toLocaleString()} · {item.status.replaceAll('_', ' ')}</p>
          {item.status === 'pending' && ['safe','cancelled'].map(status => <button key={status} disabled={busy} onClick={() => void perform(async () => {
            await request('/checkins/'+item.id, 'PATCH', {status}, inbox.access_token);
            await refresh();
          })}>{status === 'safe' ? 'I’m safe' : 'Cancel check-in'}</button>)}
        </div>)}
      </> : <button disabled={busy} onClick={() => void perform(async () => {
        const created = await request('/inbox', 'POST');
        setInbox(created);
        try { localStorage.setItem('sos_v5_inbox', JSON.stringify(created)); }
        catch { setNotice('Browser storage is blocked. This inbox is available until you close this page.'); }
      })}>Create private inbox</button>}
    </article>
    <p role="status">{notice}</p>
  </section>;
}
