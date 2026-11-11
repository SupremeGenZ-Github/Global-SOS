import {useEffect, useRef, useState} from 'react';
import {deleteIncident, journalBytes, listIncidents, makeIncident, saveIncident, validateAttachment} from './incident-store.mjs';
import type {Incident, IncidentAttachment} from './incident-store.mjs';
import {incidentArchive, incidentText} from './incident-export.mjs';
import './incident-journal.css';

type Attachment = File | IncidentAttachment;
const asBlob = (item:Attachment) => 'blob' in item ? item.blob : item;
const prettySize = (size:number) => (size / (1024 * 1024)).toFixed(1) + ' MB';

function MediaPreview({item}:{item:Attachment}) {
  const [url,setUrl] = useState('');
  useEffect(() => {
    const next = URL.createObjectURL(asBlob(item));
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  },[item]);
  return item.type.startsWith('video/')
    ? <video src={url} controls preload="metadata" aria-label={item.name}/>
    : <img src={url} alt={item.name} loading="lazy"/>;
}

function download(blob:Blob, name:string) {
  const url = URL.createObjectURL(blob), link = document.createElement('a');
  link.href = url; link.download = name; document.body.appendChild(link); link.click(); link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url),1000);
}

export function IncidentJournal() {
  const [records,setRecords] = useState<Incident[]>([]);
  const [editing,setEditing] = useState<Incident|null|undefined>(undefined);
  const [title,setTitle] = useState(''), [notes,setNotes] = useState('');
  const [files,setFiles] = useState<Attachment[]>([]);
  const [notice,setNotice] = useState(''), [busy,setBusy] = useState(false), [ready,setReady] = useState(false);
  const [opened,setOpened] = useState<string|null>(null);
  const operation = useRef(false);

  async function refresh() {
    setReady(false);
    try { setRecords(await listIncidents()); setReady(true); }
    catch (error) { setNotice(String(error)); }
  }
  useEffect(() => { void refresh(); },[]);
  useEffect(() => {
    if (editing === undefined) return;
    const warn = (event:BeforeUnloadEvent) => {event.preventDefault(); event.returnValue = '';};
    window.addEventListener('beforeunload',warn);
    return () => window.removeEventListener('beforeunload',warn);
  },[editing]);

  async function perform(action:()=>Promise<void>) {
    if (operation.current) return;
    operation.current = true; setBusy(true); setNotice('');
    try { await action(); }
    catch (error) { setNotice(error instanceof Error ? error.message : 'Action unavailable.'); }
    finally { operation.current = false; setBusy(false); }
  }
  function start(record:Incident|null) {
    setEditing(record); setTitle(record?.title ?? ''); setNotes(record?.notes ?? '');
    setFiles(record?.attachments ?? []); setNotice('');
  }
  function pick(event:React.ChangeEvent<HTMLInputElement>) {
    const incoming = Array.from(event.target.files ?? []);
    event.target.value = '';
    try {
      incoming.forEach(validateAttachment);
      if (files.length + incoming.length > 10) throw Error('Use up to 10 attachments per incident.');
      if ([...files,...incoming].reduce((sum,file) => sum + file.size,0) > 200 * 1024 * 1024) throw Error('Keep each incident under 200 MB.');
      setFiles([...files,...incoming]);
    } catch (error) { setNotice(String(error)); }
  }
  async function share(record:Incident) {
    const selected = record.attachments.map(item => new File([item.blob],item.name,{type:item.type}));
    if (navigator.share && (!selected.length || navigator.canShare?.({files:selected}))) {
      try { await navigator.share({title:record.title,text:incidentText(record),...(selected.length?{files:selected}:{})}); }
      catch (error) { if (error instanceof DOMException && error.name === 'AbortError') return; throw error; }
      setNotice('Share sheet completed. Delivery is unconfirmed.');
    } else {
      download(await incidentArchive(record),'global-sos-incident.zip');
      setNotice('Sharing these files is unavailable here. The ZIP download contains the notes and original attachments.');
    }
  }

  return <section className="incident-journal service-card" aria-label="Incident journal">
    <div className="journal-heading"><div><p className="eyebrow">YOUR PERSONAL RECORD</p><h2>Incident journal</h2></div>
      <span className="journal-badge">On this device</span></div>
    <p>Record photos, videos, and notes. Entries stay in this browser until you choose to export or share. Camera controls depend on your device. Clearing browser data can erase entries.</p>
    <p className="footnote">Media and notes use unencrypted browser storage. Review them before sharing. Keep an exported copy of anything you need to retain.</p>
    {!ready && <button disabled={busy} onClick={() => void refresh()}>Retry journal storage</button>}
    <div className="journal-toolbar"><span>{records.length} incidents · {prettySize(journalBytes(records))} / 500 MB</span>
      <button disabled={!ready || busy || editing !== undefined} onClick={() => start(null)}>＋ New incident</button></div>
    {editing !== undefined && <form className="journal-editor" onSubmit={event => {
      event.preventDefault();
      void perform(async () => {
        if (!title.trim() && !notes.trim() && !files.length) throw Error('Add a title, notes, or an attachment.');
        const next = makeIncident(title,notes,files,editing);
        await saveIncident(next); setEditing(undefined); setFiles([]);
        await refresh(); setOpened(next.id); setNotice('Incident saved on this device.');
      });
    }}>
      <label>Incident title<input value={title} disabled={busy} maxLength={100} onChange={event => setTitle(event.target.value)}/></label>
      <label>Notes<textarea aria-label="Notes" value={notes} disabled={busy} maxLength={4000} rows={5} onChange={event => setNotes(event.target.value)} placeholder="What happened? Add only the details you choose to keep."/></label>
      <div className="journal-capture">
        <label className="journal-picker">Take photo<input disabled={busy} aria-label="Take incident photo" type="file" accept="image/jpeg,image/png,image/webp,image/heic,image/heif" capture="environment" onChange={pick}/></label>
        <label className="journal-picker">Record video<input disabled={busy} aria-label="Record incident video" type="file" accept="video/mp4,video/webm,video/quicktime,video/3gpp" capture="environment" onChange={pick}/></label>
        <label className="journal-picker">Choose existing files<input disabled={busy} aria-label="Choose incident attachments" type="file" accept="image/jpeg,image/png,image/webp,image/heic,image/heif,video/mp4,video/webm,video/quicktime,video/3gpp" multiple onChange={pick}/></label>
      </div>
      <p className="footnote">Up to 10 files per entry, 100 MB per file, 200 MB per entry. Browser playback varies by format.</p>
      <div className="journal-media">{files.map((file,index) => <figure key={index}><MediaPreview item={file}/><figcaption>{file.name} · {prettySize(file.size)}</figcaption><button type="button" disabled={busy} onClick={() => setFiles(files.filter((_,i) => i !== index))}>Remove attachment {index+1}</button></figure>)}</div>
      <div className="journal-toolbar"><button disabled={busy} type="submit">Save incident</button><button disabled={busy} type="button" onClick={() => void perform(async () => {
        download(await incidentArchive(makeIncident(title,notes,files,editing)),'global-sos-incident-draft.zip');
        setNotice('Draft ZIP prepared. The draft is still open.');
      })}>Export draft ZIP</button><button disabled={busy} type="button" onClick={() => {
        if (window.confirm('Discard this draft? Unsaved attachments and notes will be removed.')) {setEditing(undefined);setFiles([]);}
      }}>Discard draft</button></div>
    </form>}
    {ready && !records.length && editing === undefined && <div className="journal-empty"><strong>Your journal is ready</strong><p>Start an entry to keep notes and media together.</p></div>}
    <div className="journal-records">{records.map(record => <article key={record.id} className="journal-record">
      <button className="journal-record-title" aria-expanded={opened === record.id} onClick={() => setOpened(opened === record.id ? null : record.id)}><strong>{record.title}</strong><span>{new Date(record.createdAt).toLocaleString()} · {record.attachments.length} attachments</span></button>
      {opened === record.id && <><p className="journal-notes">{record.notes}</p><div className="journal-media">{record.attachments.map(file => <figure key={file.id}><MediaPreview item={file}/><figcaption>{file.name}</figcaption><button disabled={busy} onClick={() => download(file.blob,file.name)}>Download original</button></figure>)}</div>
        <div className="journal-toolbar"><button disabled={busy || editing !== undefined} onClick={() => start(record)}>Edit notes and files</button><button disabled={busy} onClick={() => void perform(async () => {download(await incidentArchive(record),'global-sos-incident.zip');setNotice('Incident ZIP prepared.');})}>Export incident ZIP</button><button disabled={busy} onClick={() => void perform(() => share(record))}>Share incident</button><button disabled={busy || editing !== undefined} onClick={() => {
          if (!window.confirm('Delete this incident and all its attachments from this browser?')) return;
          void perform(async () => {await deleteIncident(record.id);await refresh();setNotice('Incident deleted.');});
        }}>Delete incident</button></div></>}
    </article>)}</div>
    <p role="status" aria-live="polite">{busy ? 'Working…' : notice}</p>
  </section>;
}
