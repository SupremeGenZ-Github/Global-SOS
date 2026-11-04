import {readFileSync} from 'node:fs';

const model = JSON.parse(readFileSync(new URL('../shared/intent-model.json', import.meta.url)));

export function modelTokens(text) {
  return new Set(text.toLowerCase().match(/[a-z]{3,}/g) ?? []);
}

export function predictIntent(text, trained = model) {
  const tokens = modelTokens(text);
  const ranked = Object.entries(trained.weights).map(([category, weights]) => {
    const matches = [...tokens].filter(token => Object.hasOwn(weights, token));
    const score = matches.reduce((sum, token) => sum + weights[token], 0);
    return {category, score, matches: matches.length};
  }).sort((a, b) => b.score - a.score);
  const [best, next] = ranked;
  if (!best || best.category === 'other' || best.matches < 2 ||
      best.score < trained.minimumScore || best.score - (next?.score ?? 0) < trained.minimumMargin) {
    return null;
  }
  return best.category;
}
