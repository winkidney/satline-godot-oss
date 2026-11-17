async(page)=>await page.evaluate(async()=>{
 const g=__G,T=g.THREE;g.explosives.reset();const grid=g.physics.nav._grid();let seed=4207;
 const rng=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};
 const pairs=[[[ -32,0,6],[1.5,0,7.5]],[[-32,0,6],[-2,0,-19.5]],[[-32,0,6],[23,0,0]],[[-32,0,6],[29,0,20]]];
 for(let i=0;i<20;i++)pairs.push([[-38+rng()*66,0,-30+rng()*58],[-38+rng()*66,0,-30+rng()*58]]);
 const cases=pairs.map(([start,end])=>{const a=new T.Vector3(...start),b=new T.Vector3(...end);const path=g.physics.nav.findPath(a,b);return {start,end,path:path?path.map(p=>p.toArray()):null,clear:g.physics.nav.clearLine(a,b)}});
 const output={source:'Original active physics.nav grid, A* and path smoothing',width:grid.w,height:grid.h,cell:grid.cell,blocked:Array.from(grid.blocked),cases};
 const response=await fetch('http://127.0.0.1:8794/',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:'fixtures/navigation-reference.json',json:output})});if(!response.ok)throw Error(await response.text());return {cells:grid.blocked.length,paths:cases.length,reachable:cases.filter(c=>c.path).length,errors:__errors};
})
