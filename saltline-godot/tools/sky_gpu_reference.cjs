async(page)=>{
 await page.goto('http://127.0.0.1:8795/saltline-godot/tools/sky_reference.html');
 const result=await page.evaluate(async()=>await window.ready);
 return {exports:[{name:'saltline-sky-reference.json',base64:btoa(unescape(encodeURIComponent(JSON.stringify(result))))}],cases:result.cases.length,three:result.three,scope:result.scope};
}