import {chromium} from 'playwright';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
const port=4178, origin='http://127.0.0.1:'+port;
const server=spawn(process.execPath,['backend/server.mjs'],{env:{...process.env,PORT:String(port),DATABASE_URL:'',APP_BASE_URL:origin,CORS_ORIGINS:origin},stdio:'ignore'});
let browser;
try {
 for(let i=0;i<80;i++){try{if((await fetch(origin+'/health')).ok)break;}catch{}await new Promise(r=>setTimeout(r,250));}
 browser=await chromium.launch({headless:true});
 const context=await browser.newContext({viewport:{width:390,height:844},geolocation:{latitude:28.61,longitude:77.21,accuracy:20},permissions:['geolocation']});
 const page=await context.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 let sessions=0;const notifications=[];
 await page.route('**/api/sos',async route=>{sessions++;assert.equal(route.request().postDataJSON().country,'IN');await route.fulfill({json:{id:'test-session',capability:'test-capability',expires_in:3600}});});
 await page.route('**/api/sos/test-session/location',route=>route.fulfill({json:{status:'stored'}}));
 await page.route('**/api/sos/test-session/notify',async route=>{notifications.push(route.request().postDataJSON());await route.fulfill({json:{results:[{kind:'sms',status:'queued'}]}});});
 await page.addInitScript(()=>{
   localStorage.setItem('sos_country','IN');
   localStorage.setItem('sos_auto_alerts','true');
   localStorage.setItem('sos_contacts',JSON.stringify([{id:'test-person',name:'Consenting test contact',phone:'+19995550123',alertConsent:true,methods:['sms']}]));
 });
 await page.goto(origin,{waitUntil:'networkidle'});
 await page.locator('nav button').filter({hasText:'My Safety'}).click();
 await page.getByPlaceholder('Configured operator token').fill('test-token-only-never-a-provider-secret');
 await page.locator('nav button').filter({hasText:'Home'}).click();
 await page.locator('.sos-orb').click();
 await page.getByRole('button',{name:'Start without location',exact:true}).click();
 await page.getByRole('button',{name:'Cancel countdown',exact:true}).click();
 await page.waitForTimeout(5500);
 assert.equal(sessions,0,'cancelled SOS must not create a session');
 assert.equal(notifications.length,0,'cancelled SOS must not send alerts');
 await page.locator('.sos-orb').click();
 await page.getByRole('button',{name:'Include my location & start',exact:true}).click();
 await page.waitForFunction(()=>document.body.textContent.includes('queued'),{},{timeout:20000});
 assert.equal(sessions,1);
 assert.equal(notifications.length,1);
 assert.match(notifications[0].message,/28.61,77.21/);
 assert.equal(notifications[0].contacts[0].recipient,'+19995550123');
 assert.match(await page.locator('.control-panel').innerText(),/does not confirm delivery/);
 assert.deepEqual(errors,[]);
 assert.ok(await page.locator('body').evaluate(el=>el.scrollWidth<=window.innerWidth),'mobile layout must not overflow horizontally');
 console.log('PASS: mobile SOS preparation, countdown cancellation, mock provider alerts and fresh consented location; no real calls or messages');
 await context.close();
} finally {await browser?.close();server.kill();}
