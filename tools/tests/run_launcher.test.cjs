"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "saltline-launcher-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const project = path.join(root, "saltline-godot");
  fs.mkdirSync(path.join(project, "tools"), { recursive: true });
  fs.copyFileSync(path.join(__dirname, "../../run.sh"), path.join(root, "run.sh"));
  fs.writeFileSync(path.join(project, "tools/run_native.sh"), '#!/bin/sh\nprintf "%s\\n" "$@" > "$TEST_GAME_LOG"\n', { mode: 0o755 });
  const editor = path.join(root, "editor");
  fs.writeFileSync(editor, `#!/bin/sh
if [ "\${1-}" = "--version" ]; then echo "\${TEST_VERSION:-4.7.2.stable.official.ed1daf0bf}"; exit 0; fi
printf '%s\\n' "$@" > "$TEST_EDITOR_LOG"
[ "\${TEST_IMPORT_FAIL:-0}" = 0 ] || exit 13
[ "\${TEST_INCOMPLETE:-0}" = 0 ] || exit 0
mkdir -p "$TEST_PROJECT/.godot/imported"
echo '[list]' > "$TEST_PROJECT/.godot/global_script_class_cache.cfg"
`, { mode: 0o755 });
  const gameLog = path.join(root, "game.log");
  const editorLog = path.join(root, "editor.log");
  function run(extra = {}, args = []) {
    const log = path.join(root, "output.log");
    const fd = fs.openSync(log, "w");
    const env = { ...process.env, GODOT: editor, TEST_PROJECT: project, TEST_GAME_LOG: gameLog, TEST_EDITOR_LOG: editorLog, ...extra };
    const result = spawnSync("sh", [path.join(root, "run.sh"), ...args], { cwd: root, env, stdio: ["ignore", fd, fd] });
    fs.closeSync(fd);
    if (result.error) throw result.error;
    return { status: result.status, output: fs.readFileSync(log, "utf8") };
  }
  return { root, project, editor, gameLog, editorLog, run };
}

test("fresh checkout imports once then starts the bundled engine", t => {
  const f = fixture(t);
  const first = f.run({}, ["--headless", "--", "--game"]);
  assert.equal(first.status, 0);
  assert.deepEqual(fs.readFileSync(f.editorLog, "utf8").trim().split("\n"), ["--headless", "--editor", "--path", f.project, "--import", "--quit"]);
  assert.deepEqual(fs.readFileSync(f.gameLog, "utf8").trim().split("\n"), ["--headless", "--", "--game"]);
  fs.unlinkSync(f.editorLog);
  assert.equal(f.run({ GODOT: path.join(f.root, "missing-editor") }).status, 0);
  assert.equal(fs.existsSync(f.editorLog), false);
});

test("missing, incompatible, failed or incomplete imports do not start the game", t => {
  const f = fixture(t);
  for (const env of [
    { GODOT: path.join(f.root, "missing-editor") },
    { TEST_VERSION: "4.6.stable.official" },
    { TEST_IMPORT_FAIL: "1" },
    { TEST_INCOMPLETE: "1" },
  ]) {
    const result = f.run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.output, /Godot 4\.7\.2|资源导入/);
    assert.equal(fs.existsSync(f.gameLog), false);
  }
});
