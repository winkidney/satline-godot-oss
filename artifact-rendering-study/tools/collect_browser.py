#!/usr/bin/env python3
"""Run a Playwright CLI collector and save its JSON result without logging image data."""
import argparse, base64, json, subprocess, shutil
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('script',type=Path)
parser.add_argument('--session',default='saltgpu')
parser.add_argument('--name',required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
wrapper=Path.home()/'.codex/skills/playwright/scripts/playwright_cli.sh'
result=subprocess.run(['rtk','proxy','bash',str(wrapper),f'-s={args.session}','run-code','--filename',str(args.script.resolve())],cwd=root.parent,text=True,capture_output=True,timeout=240)
logs=root/'output/playwright'; logs.mkdir(parents=True,exist_ok=True)
(logs/f'{args.name}.log').write_text(result.stdout+result.stderr)
if result.returncode: raise SystemExit(result.stderr or result.stdout)
try: data=json.loads(result.stdout.split('### Result\n',1)[1].split('\n### ',1)[0])
except (IndexError,json.JSONDecodeError): raise SystemExit('No JSON result; inspect '+str(logs/f'{args.name}.log'))
assets=root/'evidence/runtime'; assets.mkdir(parents=True,exist_ok=True)
(assets/'captures').mkdir(exist_ok=True)
for item in data.get('captures',[]):
    source=root.parent/item['file']
    if source.is_file():
        dest=assets/'captures'/source.name
        shutil.copy2(source,dest)
        item['archived_file']='captures/'+source.name
for item in data.pop('exports',[]):
    name=item.pop('name')
    if name == f'{args.name}.json':
        raise SystemExit('Export filename collides with metadata: use a different --name')
    encoded=item.pop('base64',None)
    if encoded is None: encoded=item.pop('png').split(',',1)[1]
    (assets/name).write_bytes(base64.b64decode(encoded))
    data.setdefault('exported_assets',[]).append({'file':name,**item})
(assets/f'{args.name}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'metadata':f'evidence/runtime/{args.name}.json','exports':len(data.get('exported_assets',[])),'captures':len(data.get('captures',[]))},ensure_ascii=False))
