import fs from 'node:fs';
import {createHash} from 'node:crypto';
const file='C:/Users/ronde/Downloads/Pokemon - Emerald Version (USA, Europe)/Pokemon - Emerald Version (USA, Europe).gba';
const bytes=fs.readFileSync(file),header=bytes.subarray(0,0xc0);
const sha1=createHash('sha1').update(bytes).digest('hex');
const expected='f3ae088181bf583e55daf962a92bb46f4f1d07b7';
let checksum=0;for(let i=0xa0;i<=0xbc;i++)checksum=(checksum-header[i])&255;checksum=(checksum-0x19)&255;
const report={file,bytes:bytes.length,title:header.subarray(0xa0,0xac).toString('ascii').replaceAll('\0',''),gameCode:header.subarray(0xac,0xb0).toString('ascii'),revision:header[0xbc],headerChecksumValid:checksum===header[0xbd],sha1,sha256:createHash('sha256').update(bytes).digest('hex'),matchesLocalPokeemeraldReference:sha1===expected,method:'Read-only GBA header and digest inspection; no ROM execution or extraction',referenceChecksumFile:'D:/work/acqron/pokemon-emerald-horizons/third-party/pokeemerald/rom.sha1'};
fs.writeFileSync('docs/emerald-rom-reference.json',JSON.stringify(report,null,2)+'\n');console.log(report);
