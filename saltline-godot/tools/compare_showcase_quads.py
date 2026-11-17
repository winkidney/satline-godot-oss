import json,hashlib
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1]/'evidence'
source_file=root/'fx-showcase-source.json';native_file=root/'fx-showcase-native-state.json'
s=json.loads(source_file.read_text())['state'];n=json.loads(native_file.read_text());failures=[];checks=0;maximum=0.;pools={}
for key in ['fx_lit','fx_add']:
 a,b=np.array(s['quads'][key]),np.array(n['quads'][key]);checks+=1
 if a.shape!=b.shape:failures.append(key+' shape');continue
 d=np.abs(a-b);checks+=int(d.size);error=float(d.max());maximum=max(maximum,error)
 if not np.isfinite(d).all() or error>3e-6:failures.append(key+' attributes')
 pools[key]={'particles':int(a.shape[0]),'attributes':int(d.size),'maximum_error':error}
checks+=2
if abs(s['fx_clock_before_snapshot']+.5-n['fx_clock'])>1e-12:failures.append('clock')
if s['snapshot_draws']!=n['snapshot_draws']:failures.append('rng count')
report={'checks':checks,'maximum_error':maximum,'pools':pools,'source_fx_clock':s['fx_clock_before_snapshot']+.5,'native_fx_clock':n['fx_clock'],'snapshot_draws':n['snapshot_draws'],'failures':failures,'inputs':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [source_file,native_file]},'scope':'Actual original GPU instance attributes vs native float32 quads at FXclock.55/age.5. Single explosion/tape snapshot; not shader, blending, depth, post or whole-game parity.'}
(root/'fx-showcase-quads-comparison.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));raise SystemExit(bool(failures))
