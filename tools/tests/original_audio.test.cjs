"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { encodeWav, loadSynth, sha256 } = require("../export_original_audio.cjs");

test("original generator inventory and deterministic variants", () => {
  const synth = loadSynth();
  const entries = Object.entries(synth.registry);
  assert.equal(entries.length, 79);
  assert.equal(entries.reduce((sum, [, value]) => sum + value.n, 0), 136);
  const first = encodeWav(synth.generate("rifle_shot", 0));
  const repeat = encodeWav(synth.generate("rifle_shot", 0));
  const variant = encodeWav(synth.generate("rifle_shot", 1));
  assert.equal(sha256(first.raw), sha256(repeat.raw));
  assert.notEqual(sha256(first.raw), sha256(variant.raw));
  assert.equal(first.wav.toString("ascii", 0, 4), "RIFF");
  assert.equal(first.wav.toString("ascii", 8, 12), "WAVE");
  assert.equal(first.wav.readUInt16LE(34), 16);
  assert.equal(first.wav.readUInt32LE(40), first.frames * first.channels * 2);
  assert.ok(first.maxError <= 1 / 32767);
  const ticks = synth.generate("music_ticks", 0);
  assert.equal(ticks.loop, true);
  assert.equal(ticks.ch[0].length / ticks.sr, 15);
  const ir = synth.generate("ir_shed", 0, 48000);
  assert.equal(ir.sr, 48000);
  assert.equal(ir.ch.length, 2);
});
