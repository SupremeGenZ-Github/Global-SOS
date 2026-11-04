import {readFileSync, writeFileSync} from 'node:fs';

const root = new URL('../', import.meta.url);
const data = JSON.parse(readFileSync(new URL('shared/intent-training.json', root)));
const stop = new Set('the and was are has have from with into out not can cannot someone person need help will she her him his my our this that'.split(' '));
const examples = Object.entries(data);
const documents = examples.flatMap(([category, phrases]) => phrases.map(text => ({
  category,
  tokens: new Set((text.toLowerCase().match(/[a-z]{3,}/g) ?? []).filter(token => !stop.has(token))),
})));
const overall = new Map();
const byCategory = new Map(examples.map(([category]) => [category, new Map()]));
for (const {category, tokens} of documents) {
  const counts = byCategory.get(category);
  for (const token of tokens) {
    overall.set(token, (overall.get(token) ?? 0) + 1);
    counts.set(token, (counts.get(token) ?? 0) + 1);
  }
}
const weights = Object.fromEntries(examples.map(([category, phrases]) => [
  category,
  Object.fromEntries([...byCategory.get(category)].filter(([token, count]) =>
    count >= 2 && count / overall.get(token) >= 0.6,
  ).map(([token, count]) => [token, Number((count / phrases.length * count / overall.get(token)).toFixed(4))])),
]));
const output = JSON.stringify({minimumScore: 0.55, minimumMargin: 0.18, weights}, null, 2) + '\n';
for (const path of ['shared/intent-model.json', 'android/assets/intent-model.json']) {
  writeFileSync(new URL(path, root), output);
}
console.log(`Trained on ${documents.length} synthetic examples across ${examples.length} labels.`);
