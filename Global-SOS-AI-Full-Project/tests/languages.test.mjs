import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {classify,urgent} from '../backend/core.mjs';
const {languages}=JSON.parse(readFileSync(new URL('../shared/languages.json',import.meta.url)));
test('32 languages have complete core labels and explicit text direction',()=>{
 assert.equal(languages.length,32);assert.equal(new Set(languages.map(l=>l.code)).size,32);
 const keys=Object.keys(languages[0].labels);
 for(const l of languages){assert.deepEqual(Object.keys(l.labels),keys);assert.ok(Object.values(l.labels).every(v=>typeof v==='string'&&v.trim()));assert.ok(['ltr','rtl'].includes(l.direction));}
 for(const code of ['ar','fa','he','ur'])assert.equal(languages.find(l=>l.code===code).direction,'rtl');
});
test('multilingual requests keep emergency routing independent of an LLM',()=>{
 for(const text of ['पुलिस','పోలీసు','காவல்','شرطة','警察','полиция','경찰'])assert.equal(classify(text),'police',text);
 for(const text of ['आग','మంట','தீ விபத்து','حريق','火灾','ไฟไหม้']){assert.equal(classify(text),'fire',text);assert.equal(urgent(text),true);}
 for(const text of ['అంబులెన్స్','ஆம்புலன்ஸ்','إسعاف','救护车'])assert.equal(classify(text),'ambulance',text);
});
