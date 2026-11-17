async(page)=>await page.evaluate(()=>{
 const g=__G,T=g.THREE;const cases=[];
 for(const size of [.1,.4,1,1.9,4,6]){
  g.fx.clear();g.explosives.reset();g.fx.explosion(new T.Vector3(-18,.45,6),size);g.fx.update(0);
  const stats=g.fx.stats();cases.push({size,lit:stats.lit,add:stats.add,debris:stats.debris});
 }
 g.fx.clear();g.explosives.reset();g.render.lightPool.update(100);return {source:'Original active fx.explosion and fx.update(0)',cases,errors:__errors};
})
