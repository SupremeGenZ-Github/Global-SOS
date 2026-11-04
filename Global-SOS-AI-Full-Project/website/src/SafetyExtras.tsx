import {useState} from 'react';
import checklist from '../../shared/safety-checklist.json';
import type {AlertContact as Contact} from './AlertSettings';
const read=<T,>(key:string,fallback:T):T=>{try{return JSON.parse(localStorage.getItem(key)||'null')??fallback;}catch{return fallback;}};

type TripPlan = {destination:string; route:string; meetingPoint:string; checkIn:string};
const blankTrip:TripPlan = {destination:'',route:'',meetingPoint:'',checkIn:''};
const tripKey = 'sos_trip_plan_v1';
const tripFields = [
  ['destination','Destination',100],
  ['route','Route or transport',300],
  ['meetingPoint','Backup meeting point',150],
] as const;

function loadTrip():TripPlan {
  const value = read<Partial<TripPlan> | null>(tripKey,null);
  const plan = {...blankTrip};
  for (const [field,,limit] of tripFields) {
    const text = value?.[field];
    if (typeof text === 'string') plan[field] = text.slice(0,limit);
  }
  if (typeof value?.checkIn === 'string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d$/.test(value.checkIn)) plan.checkIn = value.checkIn;
  return plan;
}

function downloadFile(name:string, type:string, body:string) {
  const url = URL.createObjectURL(new Blob([body],{type}));
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url),1000);
}

function escapeFileText(text:string) {
  return text.replaceAll('\\','\\\\').replace(/\r\n|\r|\n/g,'\\n').replaceAll(';','\\;').replaceAll(',','\\,');
}

function foldFileLine(line:string) {
  const encoder = new TextEncoder();
  let bytes = 0;
  let output = '';
  for (const character of line) {
    const size = encoder.encode(character).length;
    if (bytes + size > 75) {
      output += '\r\n ';
      bytes = 1;
    }
    output += character;
    bytes += size;
  }
  return output;
}

function serializeLines(lines:string[]) {
  return lines.map(foldFileLine).join('\r\n') + '\r\n';
}

function calendarDate(date:Date) {
  return date.toISOString().replace(/[-:]/g,'').replace(/\.\d{3}Z$/,'Z');
}

function TripPlanner({country}:{country:string}) {
  const [plan,setPlan] = useState(loadTrip);
  const [notice,setNotice] = useState('');
  const checkIn = plan.checkIn ? new Date(plan.checkIn) : null;
  const validTime = checkIn !== null && Number.isFinite(checkIn.getTime());
  const hasPlan = tripFields.some(([field]) => plan[field].trim()) || validTime;
  const summary = [
    'Global SOS trip plan',
    country && 'Country: '+country,
    ...tripFields.map(([field,label]) => plan[field].trim() && label+': '+plan[field].trim()),
    validTime && 'Planned check-in: '+checkIn.toLocaleString(undefined,{dateStyle:'medium',timeStyle:'short'})+' ('+Intl.DateTimeFormat().resolvedOptions().timeZone+')',
    'I plan to check in myself. This plan sends no automatic alerts.',
  ].filter(Boolean).join('\n');

  function savePlan() {
    try {
      localStorage.setItem(tripKey,JSON.stringify(plan));
      setNotice('Trip plan saved in this browser.');
    } catch {
      setNotice('Browser storage is unavailable. You can still copy or download the plan.');
    }
  }

  function clearPlan() {
    try {
      localStorage.removeItem(tripKey);
      setPlan({...blankTrip});
      setNotice('Trip plan cleared from this browser.');
    } catch {
      setNotice('Browser storage could not be cleared.');
    }
  }

  async function sharePlan() {
    try {
      if (navigator.share) {
        await navigator.share({title:'Global SOS trip plan',text:summary});
        setNotice('Plan handed to the selected app. Delivery is unconfirmed.');
      } else {
        await navigator.clipboard.writeText(summary);
        setNotice('Plan copied. Paste it into the app you want to use.');
      }
    } catch (error) {
      if (!(error instanceof DOMException && error.name === 'AbortError')) {
        setNotice('Sharing is unavailable. Select the preview text or download the plan.');
      }
    }
  }

  function exportReminder() {
    if (!validTime || checkIn.getTime() <= Date.now()) {
      setNotice('Choose a future check-in time for the calendar reminder.');
      return;
    }
    const body = serializeLines([
      'BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//Global SOS//Trip Planner//EN',
      'BEGIN:VEVENT','UID:'+crypto.randomUUID()+'@global-sos',
      'DTSTAMP:'+calendarDate(new Date()),'DTSTART:'+calendarDate(checkIn),
      'SUMMARY:Personal check-in','DESCRIPTION:Contact your trusted person yourself.',
      'BEGIN:VALARM','ACTION:DISPLAY','TRIGGER:PT0M','DESCRIPTION:Time for your check-in',
      'END:VALARM','END:VEVENT','END:VCALENDAR',
    ]);
    downloadFile('global-sos-check-in.ics','text/calendar;charset=utf-8',body);
    setNotice('Import the file into your calendar and check that reminders are enabled. This calendar event sends no alerts to contacts.');
  }

  return <article className="service-card">
    <h2>Trip plan and personal reminder</h2>
    <p>Plan a route, agree on a meeting point, and choose when to check in. Saving is optional. Saved plans stay in this browser’s storage.</p>
    {tripFields.map(([field,label,limit]) => <label key={field} style={{display:'block',marginBlock:8}}>
      {label}{' '}<input value={plan[field]} maxLength={limit} onChange={e => setPlan({...plan,[field]:e.target.value})}/>
    </label>)}
    <label style={{display:'block',marginBlock:8}}>Planned check-in (device time){' '}
      <input type="datetime-local" value={plan.checkIn} onChange={e => setPlan({...plan,checkIn:e.target.value})}/>
    </label>
    {hasPlan && <details><summary>Preview what you will share</summary><pre style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere'}}>{summary}</pre></details>}
    <div className="button-row" style={{flexWrap:'wrap',marginBlock:8}}>
      <button disabled={!hasPlan} onClick={savePlan}>Save on this device</button>
      <button disabled={!hasPlan} onClick={() => void sharePlan()}>Share or copy plan</button>
      <button disabled={!hasPlan} onClick={() => downloadFile('global-sos-trip-plan.txt','text/plain;charset=utf-8',summary)}>Download plan</button>
      <button disabled={!validTime} onClick={exportReminder}>Download calendar reminder</button>
      <button onClick={clearPlan}>Clear saved plan</button>
    </div>
    <p role="status">{notice}</p>
  </article>;
}

function downloadContact(contact:Contact) {
  const number = contact.phone.replace(/[^+0-9]/g,'');
  if (!/^\+?\d{3,20}$/.test(number)) return false;
  const body = serializeLines([
    'BEGIN:VCARD','VERSION:3.0','FN:'+escapeFileText(contact.name),
    'N:'+escapeFileText(contact.name)+';;;;','TEL;TYPE=VOICE:'+number,'END:VCARD',
  ]);
  downloadFile('global-sos-contact.vcf','text/vcard;charset=utf-8',body);
  return true;
}

export function SafetyExtras({contacts,country,emergency,onContacts}:{contacts:Contact[];country:string;emergency:string|null;onContacts:(c:Contact[])=>void}){
 const [checked,setChecked]=useState<Record<string,boolean>>(()=>read('sos_checklist',{})),[medical,setMedical]=useState(()=>read<string>('sos_medical','')),[includeMedical,setIncludeMedical]=useState(false),[editing,setEditing]=useState<string|null>(null),[name,setName]=useState(''),[phone,setPhone]=useState(''),[notice,setNotice]=useState('');
 const save=(key:string,value:unknown)=>{try{localStorage.setItem(key,JSON.stringify(value));}catch{setNotice('Browser storage is unavailable. Changes may not survive closing this page.');}};
 return <section className="safety-extras"><TripPlanner country={country}/><h2>Personal readiness checklist</h2><p>{checklist.filter(t=>checked[t.id]).length} of {checklist.length} self-marked tasks. This is a personal reminder, not a safety assessment.</p><div className="checklist">{checklist.map(t=><label key={t.id}><input type="checkbox" checked={!!checked[t.id]} onChange={e=>{const next={...checked,[t.id]:e.target.checked};setChecked(next);save('sos_checklist',next);}}/>{t.label}</label>)}</div><button onClick={()=>{setChecked({});save('sos_checklist',{});}}>Reset checklist</button>
 <h2>Edit trusted contacts</h2>{contacts.length?contacts.map(c=><div className="contact-edit-row" key={c.id}><span>{c.name} · {c.phone}</span><button onClick={()=>{setEditing(c.id);setName(c.name);setPhone(c.phone);}}>Edit</button><button onClick={()=>{setNotice(downloadContact(c)?'Contact file prepared for import.':'This contact does not have a valid phone number.');}}>Download contact</button></div>):<p>Add a trusted contact above to get started.</p>}
 {editing&&<form className="contact-form" onSubmit={e=>{e.preventDefault();if(!name.trim()||!/^\+?[0-9 ()-]{3,25}$/.test(phone)){setNotice('Enter a name and valid phone number.');return;}onContacts(contacts.map(c=>c.id===editing?{...c,name:name.trim(),phone:phone.trim(),...(phone.trim()!==c.phone?{alertConsent:false,methods:[]}: {})}:c));setEditing(null);}}><input aria-label="Edit contact name" value={name} maxLength={100} onChange={e=>setName(e.target.value)}/><input aria-label="Edit contact phone" value={phone} onChange={e=>setPhone(e.target.value)}/><button>Save changes</button><button type="button" onClick={()=>setEditing(null)}>Cancel</button></form>}
 <h2>Printable emergency card</h2><p>A small card for your wallet or family. Print it or choose Save as PDF in your browser’s print dialog.</p><label className="toggle"><input type="checkbox" checked={includeMedical} onChange={e=>setIncludeMedical(e.target.checked)}/> Include optional medical notes on the printed card</label><textarea aria-label="Private medical notes for emergency card" placeholder="Optional allergies or other details you choose to include" value={medical} maxLength={1000} onChange={e=>{setMedical(e.target.value);save('sos_medical',e.target.value);}}/><p className="footnote">These browser notes stay in this browser’s local storage, which is not encrypted by this website. Include only what you are comfortable storing here.</p>
 <article id="emergency-print-card" className="emergency-print-card"><strong>GLOBAL SOS AI · PERSONAL EMERGENCY CARD</strong><h3>{country||'Confirm your current country'}</h3><p>Emergency shortcut: <b>{emergency||'Not verified — check the official local service'}</b></p><h4>My trusted contacts</h4>{contacts.length?contacts.map(c=><p key={c.id}>{c.name}: <b>{c.phone}</b></p>):<p>No trusted contacts added.</p>}{includeMedical&&medical&&<><h4>Notes provided by the card holder</h4><p style={{whiteSpace:'pre-wrap'}}>{medical}</p></>}<small>Prepared {new Date().toLocaleDateString()}. Recheck details when travelling. This card does not contact anyone automatically.</small></article><button disabled={!country} onClick={()=>window.print()}>Print emergency card / Save PDF</button>{notice&&<p role="status">{notice}</p>}
 </section>;
}

export function Diagnostics(){
 const [results,setResults]=useState<{label:string;status:string}[]>([]),[busy,setBusy]=useState(false);
 async function check(){setBusy(true);const rows=[{label:'Device connectivity',status:navigator.onLine?'Online indicator (not a server guarantee)':'Offline'}];for(const [label,url]of [['Web server','/health'],['Cloud features / PostgreSQL','/ready'],['APK availability','/api/releases/android']]){try{const response=await fetch(url,{signal:AbortSignal.timeout(8000)});const data=await response.json();rows.push({label,status:response.ok?(url.includes('releases')?(data.available?'APK ready':'APK not installed'):data.storage??data.status??'Available'):(data.database?.action??(data.status==='database_unavailable'?'PostgreSQL unavailable: check DATABASE_URL in Render. Public directory remains available.':'Unavailable (HTTP '+response.status+')'))});}catch{rows.push({label,status:'Unreachable — saved offline contacts remain available'});}}setResults(rows);setBusy(false);}
 return <article className="service-card"><h2>Connection and setup check</h2><p>Check the web server, directory storage and APK download. This does not call helplines or contact messaging providers.</p><button disabled={busy} onClick={()=>void check()}>{busy?'Checking…':'Run setup check'}</button><ul aria-live="polite">{results.map(r=><li key={r.label}><b>{r.label}:</b> {r.status}</li>)}</ul></article>;
}
