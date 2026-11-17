async(page)=>await page.evaluate(()=>{__G.fx.clear();__G.explosives.reset();__G.render.lightPool.update(100);return {ready:__ready,stats:__G.fx.stats(),errors:__errors}})
