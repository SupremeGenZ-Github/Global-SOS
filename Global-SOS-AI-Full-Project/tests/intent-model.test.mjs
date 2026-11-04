import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {classify, safeIntent, urgent} from '../backend/core.mjs';
import {predictIntent} from '../backend/intent-model.mjs';

test('the trained offline model handles unseen phrasings and abstains on weak matches', () => {
  for (const [message, category] of [
    ['Stranded offshore after our engine stopped', 'marine'],
    ['Seller refuses warranty for a broken appliance', 'consumer'],
    ['Our vehicle overturned on the highway', 'road'],
    ['Factory machinery has unsafe guards', 'workplace'],
    ['What time is dinner?', null],
    ['Help me please', null],
    ['My landlord will not fix the lights', null],
  ]) assert.equal(predictIntent(message), category, message);
});

test('urgent paraphrases use the rules and generated output must be a single allowed label', () => {
  for (const [message, category] of [
    ['She collapsed beside the table', 'ambulance'],
    ['A toddler swallowed laundry detergent', 'poison'],
    ['There is a gas odor near the oven', 'utilities'],
  ]) {
    assert.equal(classify(message), category);
    assert.equal(urgent(message), true);
  }
  assert.equal(safeIntent('POLICE'), 'police');
  assert.equal(safeIntent('police 123'), null);
  assert.equal(safeIntent('p.o.l.i.c.e'), null);
});

test('Android bundles the same trained weights as the server', () => {
  assert.deepEqual(
    readFileSync(new URL('../android/assets/intent-model.json', import.meta.url)),
    readFileSync(new URL('../shared/intent-model.json', import.meta.url)),
  );
});
