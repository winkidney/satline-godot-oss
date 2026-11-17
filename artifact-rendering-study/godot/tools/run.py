#!/usr/bin/env python3
"""Run isolated Godot studies, capture real GPU frames, and inspect engine errors."""
import argparse,os,subprocess,sys,re,json,datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument("mode",choices=["run","capture"],nargs="?",default="run");args=a.parse_args()
env=os.environ.copy();env.setdefault("XDG_DATA_HOME","/tmp/saltline-godot-data");env.setdefault("XDG_CONFIG_HOME","/tmp/saltline-godot-config")
cmd=[os.environ.get("GODOT","godot"),"--path",str(ROOT),"--audio-driver","Dummy"]
if sys.platform.startswith("linux") and env.get("DISPLAY"):cmd += ["--display-driver","x11"]
if args.mode=="capture":cmd += ["--","--capture"]
p=subprocess.Popen(cmd,env=env,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
lines=[]
for line in p.stdout:print(line,end="");lines.append(line)
code=p.wait()
if args.mode=="capture":
 (ROOT/"captures/runtime.log").write_text("".join(lines))
 if code or any(re.search(r"SCRIPT ERROR|SHADER ERROR|Parse Error|^ERROR:",x) for x in lines) or not any("SALTLINE_LABS_CAPTURE_OK" in x for x in lines):raise SystemExit(1)
 if code==0 and any("SALTLINE_LABS_CAPTURE_OK" in x for x in lines):
  report_path=ROOT/"captures/runtime.json"
  report=json.loads(report_path.read_text());report["process_completed_utc"]=datetime.datetime.now(datetime.timezone.utc).isoformat();report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
raise SystemExit(code)
