// Smoke test of the WebAssembly core through its page-facing exports, run by
// CI (.github/workflows/web-core.yml). Usage: node Web/Tests/smoke.mjs <sieuviet.wasm> <pinyin_simp.dict.yaml>
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const [wasmPath, dictionaryPath] = process.argv.slice(2);
const encoder = new TextEncoder(), decoder = new TextDecoder();
let wasm;
const { instance } = await WebAssembly.instantiate(readFileSync(wasmPath), { wasi_snapshot_preview1: {
  fd_write: (fd, iovs, count, written) => {
    const view = new DataView(wasm.memory.buffer); let total = 0;
    for (let i = 0; i < count; i++) {
      const pointer = view.getUint32(iovs + i * 8, true), length = view.getUint32(iovs + i * 8 + 4, true);
      process.stderr.write(decoder.decode(new Uint8Array(wasm.memory.buffer, pointer, length))); total += length;
    }
    view.setUint32(written, total, true); return 0;
  },
  random_get: (pointer, length) => { crypto.getRandomValues(new Uint8Array(wasm.memory.buffer, pointer, length)); return 0; },
  fd_close: () => 8, fd_fdstat_get: () => 8, fd_seek: () => 8
} });
wasm = instance.exports;
wasm._initialize();

const write = (text) => {
  const pointer = wasm.sv_input(text.length * 3 + 1);
  return encoder.encodeInto(text, new Uint8Array(wasm.memory.buffer, pointer, text.length * 3 + 1)).written;
};
const read = (length) => decoder.decode(new Uint8Array(wasm.memory.buffer, wasm.sv_output(), length));
const state = () => JSON.parse(read(wasm.sv_state()));

// A document with Keyflow's composition semantics: marked text always ends at the caret.
let value = '', mark = 0;
const segments = (text) => [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(text)];
function apply(length) {
  for (const record of read(length).split('\0').filter(Boolean)) {
    const body = record.slice(1);
    if (record[0] === 'M') { value = value.slice(0, value.length - mark) + body; mark = body.length; }
    else if (record[0] === 'U') mark = 0;
    else if (record[0] === 'I') { mark = 0; value += body; }
    else if (record[0] === 'D') { mark = 0; const last = segments(value).at(-1); if (last) value = value.slice(0, last.index); }
  }
}
function key(position, text = position) {
  wasm.sv_document(write(['test', value, '', '', String(mark ? segments(value.slice(-mark)).length : 0)].join('\0')));
  const result = wasm.sv_key(write(`${position}\0${text}`), 0);
  apply(result >> 1);
  wasm.sv_key_up(write(position));
  return (result & 1) === 1;
}
const type = (keys) => { for (const character of keys) key(character === ' ' ? 'Space' : character, character); };
function shiftTap(at) {
  wasm.sv_document(write(['test', value, '', '', '0'].join('\0')));
  wasm.sv_modifier(1, 1, 1, 0, at);
  apply(wasm.sv_modifier(1, 1, 0, 0, at + 0.05) >> 1);
}

const ids = ['A0000000-0000-4000-8000-000000000001', 'A0000000-0000-4000-8000-000000000002', 'A0000000-0000-4000-8000-000000000003'];
wasm.sv_configure(write([`${ids[0]}\ten\t0.2`,
  `${ids[0]}\tvi\tascii+\tsieuviet\tsieuviet\t1\tDefault keyboard`,
  `${ids[1]}\ten\tqwerty\tliteral\tsieuviet\t1\tEnglish`,
  `${ids[2]}\tzh\tMicrosoft Shuangpin\tSimplified Chinese\tsieuviet\t1\tChinese`].join('\n')));

let checks = 0;
const expect = (actual, expected, message) => { assert.deepEqual(actual, expected, message); checks++; };
expect(state().language, 'vi', 'starts on the first keyboard');
type('b');
expect(state().pending, true, 'an initial starts a syllable');
expect(state().phase, 1, 'the vowel round follows the initial');
expect(key('Backspace'), true, 'Backspace undoes one round');
expect(state().pending, false, 'nothing is pending after undoing the initial');
type('bs');
expect(value, 'ba', 'initial + vowel are marked');
type(' ');
expect(value, 'ba ', 'Space finishes a partial syllable as typed');
shiftTap(10);
expect(state().language, 'en', 'a left Shift tap moves to the next keyboard');
type('hi');
expect(value, 'ba hi', 'English types literally');
shiftTap(20);
expect(state().language, 'zh', 'a second Shift tap reaches Chinese');
wasm.sv_load(0, write(readFileSync(dictionaryPath, 'utf8')));
let slices = 0;
while (wasm.sv_idle() === 1) slices++;
expect(state().chineseDictionary, true, 'the dictionary builds in idle slices');
type(' nihk');
expect(state().suggestions[0], '你好', 'Shuangpin nihk offers 你好 first');
type(' ');
expect(value, 'ba hi 你好', 'Space chooses the first candidate');
console.log(`Passed ${checks} WebAssembly core checks (dictionary built in ${slices + 1} idle slices).`);
