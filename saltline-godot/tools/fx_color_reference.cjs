const fs=require('fs'),path=require('path'),crypto=require('crypto');const root=path.resolve(__dirname,'..');const source=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const T=eval(source.slice(0,source.indexOf('  var Kn = {'))+'return ut;})()');
const start=source.indexOf('function ph(n, e, t, i) {');if(start<0)throw Error('ph missing');let depth=0,end=source.indexOf('{',start);for(let i=end;i<source.length;i++){if(source[i]==='{')depth++;if(source[i]==='}'&&!--depth){end=i+1;break;}}
const ph=new Function('Qe','var e5=new Qe(),Lo=[1,1,1];'+source.slice(start,end)+';return ph;')(T.Color);
const values=[null,0,0xff8a3a,-1,123456.9,'#abc','#A1b2C3','red','ReBeccAPurple','rgb(256,128,0)','rgba(20,40,60,.3)','rgb(150%,50%,0%)','hsl(390,75%,35%)','hsla(180,0%,60%,.2)','hsl(20.5,150%,120%)','invalid','#abcd','RGB(1,2,3)',' rgb(1,2,3)','rgb(-1,0,0)','rgb(1.5,2,3)','','#12','transparent',true,false,{},[.1,.2,1.7],{isColor:true,r:.9,g:.8,b:.7},null,'invalid'];
for(const name of Object.keys(T.Color.NAMES))values.push(name);
const rows=values.map(input=>({input,expected:[...ph(input,.32,.32,.33)]}));
fs.writeFileSync(path.join(root,'assets/export/fx-css-colors.json'),JSON.stringify(T.Color.NAMES,null,2));fs.writeFileSync(path.join(root,'evidence/fx-color-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(source).digest('hex'),rows},null,2));console.log(rows.length+' cases');
