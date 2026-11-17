import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1]/'evidence'
names=['fx-showcase-source-explosion.png','fx-showcase-native-tape.png']
images=[np.asarray(Image.open(root/n).convert('RGB'),dtype=np.float64)/255 for n in names]
report={'images':[{'file':n,'sha256':hashlib.sha256((root/n).read_bytes()).hexdigest()} for n in names],'states':{name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in ['fx-showcase-source.json','fx-showcase-native-state.json']},'regions':{},'scope':'Fixed FX tape/age, fixed3 renderer frames at1/60 and matching cameras. Encoded RGB diagnostic only; not a full-game visual acceptance threshold.'}
for name,box in {'full':(0,0,1280,720),'ground':(430,455,850,700),'highlight':(590,480,690,650),'sky':(0,0,1280,220),'effect':(530,235,730,460)}.items():
 x0,y0,x1,y1=box;a,b=[v[y0:y1,x0:x1] for v in images];d=np.abs(a-b);lum=np.array([.2126,.7152,.0722])
 report['regions'][name]={'bounds':box,'mae':float(d.mean()),'p99':float(np.quantile(d,.99)),'maximum':float(d.max()),'source_mean_luma':float((a@lum).mean()),'native_mean_luma':float((b@lum).mean())}
(root/'fx-showcase-pixel-comparison.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
