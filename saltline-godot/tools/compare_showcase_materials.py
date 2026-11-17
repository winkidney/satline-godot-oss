import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=json.loads((root/'evidence/fx-showcase-source.json').read_text())['state']
native=json.loads((root/'evidence/fx-showcase-native-state.json').read_text())
materials={node['material']:node['material_state'] for node in source['nodes'] if 'material_state' in node and node['material'] in ['concrete','paint_blue','wood_pallet']}
checks=0;maximum=0.;failures=[]
def compare(a,b,label):
 global checks,maximum
 if isinstance(a,list):
  for i,(x,y) in enumerate(zip(a,b)):compare(x,y,f'{label}/{i}')
 else:
  checks+=1;error=abs(float(a)-float(b));maximum=max(maximum,error)
  if error>1e-6:failures.append({'label':label,'error':error})
for surface in native['surfaces']:
 name=surface['name'];s=materials['concrete' if name=='ShowcaseGround' else name];n=surface['uniforms']
 for a,b in [('color','base_color'),('roughness','roughness_value'),('metalness','metallic_value')]:compare(s[a],n[b],name+'/'+b)
 for a,b,keys in [('uSlWetP','wet_params','xyzw'),('uSlMacro','macro_params','xyzw'),('uSlUv','source_uv_scale','xy')]:compare([s['sl'][a]['value'][k] for k in keys],n[b],name+'/'+b)
 compare(s['sl']['uSlWet']['value'],n['wetness'],name+'/wetness');compare(s['sl']['uSlX']['value']['x'],n['interior'],name+'/interior')
 for key in ['sun_active','local_active']:
  checks+=1
  if surface[key] is not True:failures.append(name+'/'+key)
compare(source['render']['exposure'],native['exposure'],'exposure')
checks+=1
if source['render']['autoExposure']!=native['auto_exposure']:failures.append('auto exposure')
report={'checks':checks,'maximum_scalar_error':maximum,'failures':failures,'scope':'Actual source/native scalar material and ready bindings, excludes textures/BRDF/environment image/history and pixel parity.'}
(root/'evidence/fx-showcase-material-comparison.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));raise SystemExit(bool(failures))
