#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const crypto = require("node:crypto");

const root = path.resolve(__dirname, "..");
const source = path.join(root, "artifact-rendering-study/source/extracted/bundle-1.js");
const expectedSourceSha = "756bd2b539d1466bd5ab2da1836d6c39dd3ff8a3ba2afc0b02fd9f7fb3cb04c8";
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");

function loadSynth() {
  const bytes = fs.readFileSync(source);
  if (sha256(bytes) !== expectedSourceSha) throw new Error("Original audio source does not match the recorded version");
  const script = bytes.toString("utf8");
  const start = script.indexOf("  var at = Math.PI * 2;");
  const end = script.indexOf("  var ji = {", start);
  if (start < 0 || end <= start) throw new Error("Original audio generator boundaries were not found");
  const context = vm.createContext({});
  vm.runInContext(script.slice(start, end) + "\nglobalThis.audioExport={registry:Ir,generate:K6,music:Ci};", context);
  return context.audioExport;
}

function encodeWav(audio) {
  const channels = audio.ch.length;
  const frames = audio.ch[0].length;
  if (![1, 2].includes(channels) || !frames || !audio.ch.every((channel) => channel.length === frames)) {
    throw new Error("Invalid original audio channel layout");
  }
  const pcm = Buffer.allocUnsafe(frames * channels * 2);
  const raw = Buffer.allocUnsafe(frames * channels * 4);
  let maxError = 0;
  for (let frame = 0; frame < frames; frame++) {
    for (let channel = 0; channel < channels; channel++) {
      const sample = audio.ch[channel][frame];
      if (!Number.isFinite(sample) || sample < -1 || sample > 1) throw new Error("Invalid original audio sample");
      const index = frame * channels + channel;
      const quantized = Math.round(sample * 32767);
      pcm.writeInt16LE(quantized, index * 2);
      raw.writeFloatLE(sample, index * 4);
      maxError = Math.max(maxError, Math.abs(sample - quantized / 32767));
    }
  }
  const header = Buffer.alloc(44);
  header.write("RIFF", 0); header.writeUInt32LE(36 + pcm.length, 4); header.write("WAVEfmt ", 8);
  header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(audio.sr, 24); header.writeUInt32LE(audio.sr * channels * 2, 28);
  header.writeUInt16LE(channels * 2, 32); header.writeUInt16LE(16, 34);
  header.write("data", 36); header.writeUInt32LE(pcm.length, 40);
  return { wav: Buffer.concat([header, pcm]), raw, frames, channels, maxError };
}

function main() {
  const synth = loadSynth();
  const wavDir = path.join(root, "saltline-godot/assets/audio/original");
  const rawDir = path.join(root, "artifact-rendering-study/audio-original-f32");
  fs.mkdirSync(wavDir, { recursive: true });
  fs.mkdirSync(rawDir, { recursive: true });
  const manifest = { source_sha256: expectedSourceSha, ir_sample_rate: 48000, sounds: {} };
  let count = 0;
  for (const [name, metadata] of Object.entries(synth.registry)) {
    if (!/^[a-z0-9_]+$/.test(name)) throw new Error(`Invalid sound identifier: ${name}`);
    const properties = Object.fromEntries(Object.entries(metadata).filter(([, value]) => typeof value !== "function"));
    const variants = [];
    for (let variant = 0; variant < metadata.n; variant++) {
      const audio = synth.generate(name, variant, metadata.ir ? 48000 : undefined);
      const encoded = encodeWav(audio);
      const stem = `${name}-${variant}`;
      fs.writeFileSync(path.join(wavDir, `${stem}.wav`), encoded.wav);
      fs.writeFileSync(path.join(rawDir, `${stem}.f32le`), encoded.raw);
      variants.push({ variant, sample_rate: audio.sr, channels: encoded.channels, frames: encoded.frames,
        loop: audio.loop, wav_sha256: sha256(encoded.wav), float32_sha256: sha256(encoded.raw),
        max_pcm16_error: encoded.maxError });
      count++;
    }
    manifest.sounds[name] = { properties, variants };
  }
  if (Object.keys(manifest.sounds).length !== 79 || count !== 136) throw new Error("Unexpected original sound inventory");
  fs.writeFileSync(path.join(wavDir, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
  console.log(`Exported ${Object.keys(manifest.sounds).length} sound definitions and ${count} original buffers.`);
}

if (require.main === module) main();
module.exports = { encodeWav, loadSynth, sha256 };
