import test from 'node:test';
import assert from 'node:assert/strict';
import {writeFile, mkdtemp, readFile, readdir, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import extract from 'extract-zip';
import {makeIncident, validateAttachment, journalBytes} from '../website/src/incident-store.mjs';
import {incidentArchive} from '../website/src/incident-export.mjs';

test('incident limits reject unsupported, empty and excessive attachments and preserve creation time', () => {
  assert.throws(() => validateAttachment({type:'text/html',size:8}));
  assert.throws(() => validateAttachment({type:'image/jpeg',size:0}));
  assert.throws(() => validateAttachment({type:'video/mp4',size:100*1024*1024+1}));
  const file = new File(['original media'],'photo.jpg',{type:'image/jpeg'});
  const incident = makeIncident('Entry','Notes',[file]);
  const update = makeIncident('Edited','Updated',incident.attachments,incident);
  assert.equal(update.createdAt,incident.createdAt);
  assert.equal(update.id,incident.id);
  assert.equal(journalBytes([incident]),file.size);
  assert.throws(() => makeIncident('Entry','Notes',Array(11).fill(file)));
  assert.throws(() => makeIncident('Entry','Notes',Array(3).fill({type:'video/mp4',size:80*1024*1024})));
});

test('incident ZIP retains original media bytes and keeps attachment names inside the archive', async () => {
  const incident = makeIncident('తెలుగు notes','Line one\nLine two',[
    new File([new Uint8Array([1,2,3,255])],'../../photo.jpg',{type:'image/jpeg'}),
    new File(['video bytes'],'../../photo.jpg',{type:'video/mp4'}),
  ]);
  const zip = await incidentArchive(incident);
  const folder = await mkdtemp(join(tmpdir(),'sos-incident-'));
  try {
    const path = join(folder,'incident.zip');
    await writeFile(path,new Uint8Array(await zip.arrayBuffer()));
    const destination = join(folder,'extracted');
    await extract(path,{dir:destination});
    const names = (await readdir(destination)).sort();
    assert.deepEqual(names,['1-_.._photo.jpg','2-_.._photo.jpg','incident.json','notes.txt']);
    assert.deepEqual(new Uint8Array(await readFile(join(destination,names[0]))),new Uint8Array([1,2,3,255]));
    assert.equal(await readFile(join(destination,names[1]),'utf8'),'video bytes');
    const metadata = JSON.parse(await readFile(join(destination,'incident.json'),'utf8'));
    assert.equal(metadata.attachments[0].blob,undefined);
    assert.match(await readFile(join(destination,'notes.txt'),'utf8'),/తెలుగు/);
    assert.ok((await readFile(path)).length>0);
  } finally {await rm(folder,{recursive:true,force:true});}
});
