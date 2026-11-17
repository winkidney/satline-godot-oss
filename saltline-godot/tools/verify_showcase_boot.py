"""Exercise each interactive runner through its real setup and shared loading UI."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import sys

root = Path(__file__).resolve().parents[1]
cases = [
    ('mats', 'material_catalog_runner', []),
    ('props', 'material_catalog_runner', ['--catalog=props']),
    ('render', 'material_catalog_runner', ['--catalog=render']),
    ('ground', 'material_catalog_runner', ['--catalog=ground']),
    ('level', 'level_showcase_runner', []),
    ('backdrop', 'level_showcase_runner', ['--showcase=backdrop']),
    ('weapon', 'weapon_showcase_runner', []),
    ('hands', 'hands_showcase_runner', []),
    ('enemies', 'enemies_showcase_runner', []),
    ('fx', 'fx_showcase_runner', []),
]
reports = []
with tempfile.TemporaryDirectory(prefix='saltline-showcase-boot-') as temporary:
    for name, runner, arguments in cases:
        if len(sys.argv)>1 and name not in sys.argv[1:]:continue
        script = Path(temporary) / (name + '.gd')
        script.write_text('''extends "res://scripts/%s.gd"
var test_done=false
func _process(delta:float)->bool:
 if test_done:return false
 return super._process(delta)
func setup()->void:
 await super.setup()
 var failures=[]
 var expected=[{"message":"Waking the renderer","progress":.04},{"message":"Mixing paint, rust and rain","progress":.12},{"message":"Waiting for first light","progress":.92},{"message":"Ready","progress":1.0}]
 if boot_loading==null or boot_loading.stages!=expected:failures.append("original showcase stages")
 if not game.post_pipeline.combined_depth.is_ready_for(game.post_pipeline.world_port.size):failures.append("depth not ready")
 if not boot_loading.done or boot_loading.cover.mouse_filter!=Control.MOUSE_FILTER_IGNORE:failures.append("loading not released")
 root.get_texture().get_image().save_png("res://evidence/boot-showcase-%s-ready.png")
 await create_timer(.8).timeout
 if is_instance_valid(boot_loading):failures.append("loading overlay retained")
 root.get_texture().get_image().save_png("res://evidence/boot-showcase-%s.png")
 FileAccess.open("res://evidence/boot-showcase-%s.json",FileAccess.WRITE).store_string(JSON.stringify({"case":"%s","failures":failures,"stages":expected},"  "))
 test_done=true;game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
''' % (runner, name, name, name, name))
        if runner=='fx_showcase_runner':
            script.write_text(script.read_text().replace('test_done=true;', 'tracing_exposure=false;test_done=true;'))
        environment = os.environ.copy()
        environment['XDG_DATA_HOME'] = '/tmp/saltline-showcase-boot-' + name
        log = Path('/tmp/saltline-showcase-boot-' + name + '.log')
        with log.open('w') as output:
            process = subprocess.run([str(root / 'tools/run_native.sh'), '--script', str(script), '--', '--game', *arguments],
                                     env=environment, stdout=output, stderr=subprocess.STDOUT, timeout=90)
        text = log.read_text()
        report_path = root / ('evidence/boot-showcase-' + name + '.json')
        assert process.returncode == 0, (name, process.returncode, text[-2000:])
        assert 'ERROR:' not in text and 'WARNING:' not in text, (name, text[-2000:])
        report = json.loads(report_path.read_text())
        assert not report['failures'], report
        reports.append(report)
        print(name + ': passed', flush=True)
if len(sys.argv)==1:
    (root / 'evidence/showcase-boot-verification.json').write_text(json.dumps({'cases': reports, 'scope': 'All ten interactive showcase types, real inherited runner setup, original four stage labels and weights, depth readiness, pointer release, fade removal and GPU screenshots. Existing explicit frame-limit diagnostics keep their synchronous setup.'}, indent=2) + '\n')
