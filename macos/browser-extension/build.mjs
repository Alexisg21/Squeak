import {generateKeyPairSync, createHash} from 'node:crypto';
import {readFileSync, writeFileSync} from 'node:fs';
const file=new URL('manifest.json',import.meta.url);
const manifest=JSON.parse(readFileSync(file,'utf8').replace(/^\uFEFF/,''));
if(!manifest.key) manifest.key=generateKeyPairSync('rsa',{modulusLength:2048,publicKeyEncoding:{type:'spki',format:'der'},privateKeyEncoding:{type:'pkcs8',format:'der'}}).publicKey.toString('base64');
const id=createHash('sha256').update(Buffer.from(manifest.key,'base64')).digest('hex').slice(0,32).replace(/[0-9a-f]/g,c=>String.fromCharCode(97+parseInt(c,16)));
writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');
writeFileSync(new URL('extension-id.txt',import.meta.url),id+'\n');
console.log(id);
