'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);}
const registrants=files(path.join(root,'.dart_tool/flutter_build')).filter(p=>path.basename(p)==='web_plugin_registrant.dart')
 .sort((a,b)=>fs.statSync(b).mtimeMs-fs.statSync(a).mtimeMs);
assert.ok(registrants.length,'A generated web plugin registrant is required');
const registration=fs.readFileSync(registrants[0],'utf8');
for(const plugin of ['firebase_app_check_web','file_selector_web'])assert.ok(registration.includes(`package:${plugin}/`),`${plugin} missing: run flutter clean, flutter pub get and rebuild`);
const html=fs.readFileSync(path.join(root,'build/web/index.html'),'utf8');
assert.ok(html.includes('firebase_loader.js'));
assert.ok(!/<script\s*>|\son[a-z]+\s*=/i.test(html),'Inline scripts and event handlers conflict with CSP');
for(const file of ['main.dart.js','main.dart.wasm','main.dart.mjs','firebase_loader.js','downloads.js','app_shell.js'])assert.ok(fs.statSync(path.join(root,'build/web',file)).size>0,`Missing ${file}`);
const lock=fs.readFileSync(path.join(root,'pubspec.lock'),'utf8');
assert.ok(/firebase_core_web:[\s\S]*?version: "2\.24\.1"/.test(lock),'Review external Firebase SDK imports after changing firebase_core_web');
console.log('Web build verified: App Check + file picker registered, Wasm + JS fallback present, no inline scripts.');
