import {readFile,writeFile} from 'node:fs/promises';
import {createWriteStream,createReadStream} from 'node:fs';
import {pipeline} from 'node:stream/promises';
import {Readable} from 'node:stream';
import {createHash} from 'node:crypto';
import {stat} from 'node:fs/promises';
const meta=JSON.parse(await readFile(new URL('../android/assets/model.json',import.meta.url),'utf8'));
const file=new URL('../android/assets/offline-model.gguf',import.meta.url);console.log('Downloading optional model from its pinned official repository revision.');const r=await fetch(meta.url);if(!r.ok)throw Error('Model HTTP '+r.status);await pipeline(Readable.fromWeb(r.body),createWriteStream(file));const h=createHash('sha256');for await(const chunk of createReadStream(file))h.update(chunk);if(h.digest('hex')!==meta.sha256||(await stat(file)).size!==meta.size_bytes)throw Error('Model integrity mismatch; do not build this distribution.');const spec=new URL('../android/pubspec.yaml',import.meta.url);let text=await readFile(spec,'utf8');if(!text.includes('assets/offline-model.gguf'))text+='    - assets/offline-model.gguf\n';await writeFile(spec,text);console.log('Verified bundled model asset prepared. Build a separate model-inclusive APK.');
