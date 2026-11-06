'use strict';
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib');
const repo=path.resolve(__dirname,'..'),root=path.join(repo,'flutter_app/build/web');
const config=JSON.parse(fs.readFileSync(path.join(repo,'firebase.json'),'utf8'));
const headers=Object.fromEntries(config.hosting.headers[0].headers.map(h=>[h.key,h.value]));
const emulatorMode=process.argv.includes('--emulators'),port=emulatorMode?8200:8199;
if(emulatorMode)headers['Content-Security-Policy']=headers['Content-Security-Policy']
 .replace("connect-src 'self'", "connect-src 'self' http://127.0.0.1:9099 http://127.0.0.1:8187")
 .replace("frame-src 'self'", "frame-src 'self' http://127.0.0.1:9099");
const cache=new Map();
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json','.css':'text/css','.png':'image/png','.ttf':'font/ttf','.woff2':'font/woff2'};
http.createServer((req,res)=>{
  const pathname=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);
  const file=path.resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
  if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
  const stat=fs.statSync(file),encoding=/\bbr\b/.test(req.headers['accept-encoding']||'')?'br':null;
  const key=file+stat.mtimeMs+encoding;
  let bytes=cache.get(key);
  if(!bytes){bytes=fs.readFileSync(file);if(encoding)bytes=zlib.brotliCompressSync(bytes,{params:{[zlib.constants.BROTLI_PARAM_QUALITY]:6}});cache.set(key,bytes);}
  res.writeHead(200,{...headers,'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-cache',...(encoding?{'Content-Encoding':encoding}:{}),'Content-Length':bytes.length});res.end(bytes);
}).listen(port,'127.0.0.1',()=>console.log('Release test server: http://127.0.0.1:'+port));
