import assert from 'node:assert/strict';
const listeners={}, menu=[], calls=[], saved={};
let rejectTab=false;
const event=name=>({addListener:fn=>{listeners[name]=fn;}});
globalThis.chrome={
  runtime:{id:'test',lastError:null,onInstalled:event('installed'),onStartup:event('startup'),onMessage:event('message'),sendNativeMessage:async(host,data)=>{calls.push({host,...data});return {ok:true,covered:true};}},
  contextMenus:{removeAll:async()=>{menu.length=0;},create:(item,done)=>{if(rejectTab&&item.contexts.includes('tab'))throw Error('Unsupported tab context');menu.push(item);done();},onClicked:event('click')},
  storage:{local:{set:async x=>Object.assign(saved,x)},session:{set:async x=>Object.assign(saved,x)}},
  tabs:{get:async()=>({url:'https://active.example/'}),onActivated:event('activated'),onUpdated:event('updated')},
  action:{setBadgeText:async()=>{},setBadgeBackgroundColor:async()=>{},setTitle:async()=>{},openPopup:async()=>{}}
};
const app=await import('./background.js');
await app.installMenus();
assert.equal(menu.length,4); assert(menu[0].contexts.includes('tab')); assert.equal(saved.tabContext,true);
rejectTab=true; await app.installMenus();
assert.equal(menu.length,4); assert.deepEqual(menu[0].contexts,['page','link']); assert.equal(saved.tabContext,false);
await listeners.click({menuItemId:'squeak-site'},{id:7,windowId:1,url:'https://background.example/path'});
assert.equal(calls.at(-1).url,'https://background.example/path'); assert.equal(calls.at(-1).method,'add-site');
await listeners.click({menuItemId:'squeak-page',linkUrl:'https://linked.example/item'},{id:7,url:'https://active.example/'});
assert.equal(calls.at(-1).url,'https://linked.example/item'); assert.equal(calls.at(-1).method,'add-page');
for(const url of ['file:///C:/secret','chrome://settings','javascript:alert(1)','https://name:password@example.org/']) assert.equal(app.supportedUrl(url),null);
await assert.rejects(app.requestNative('status','chrome://extensions'));
let responded=false;
listeners.message({method:'delete',url:'https://example.org'},{id:'test'},()=>responded=true);
assert.equal(responded,false);
console.log('PASS: menus tab/fallback, clicked tab/link targeting, URL validation and action allowlist');
