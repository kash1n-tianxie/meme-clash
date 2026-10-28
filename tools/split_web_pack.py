#!/usr/bin/env python3
"""Split an exported Godot pack for itch.io's 200 MB per-file HTML5 limit.
Run after Godot Web export: python3 tools/split_web_pack.py ../build/web
The streamed loader restores the exact original bytes before engine.start().
"""
from pathlib import Path
import sys,json,hashlib,re
root=Path(sys.argv[1]).resolve(); pack=root/'index.pck'; html=root/'index.html'
if not pack.is_file():raise SystemExit('Export index.pck first; this tool only processes an unsplit export.')
size=pack.stat().st_size;sha=hashlib.sha256();parts=[]
with pack.open('rb') as f:
 while True:
  data=f.read(160_000_000)
  if not data:break
  name=f'index.pack-{len(parts):02d}.bin';(root/name).write_bytes(data);sha.update(data)
  parts.append({'name':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
manifest={'pack':'index.pck','bytes':size,'sha256':sha.hexdigest(),'parts':parts}
# Verify byte-for-byte order before removing the original shipped pack.
reassembled=hashlib.sha256()
for part in parts:
 with (root/part['name']).open('rb') as f:
  for data in iter(lambda:f.read(1024*1024),b''):reassembled.update(data)
assert reassembled.hexdigest()==manifest['sha256']
source=html.read_text();assert source.count('engine.startGame({')==1
loader=r'''
// Sequential streaming uses one destination buffer; no full-size concatenation copy.
async function startChunkedGame(overrides) {
 const info = __MANIFEST__;
 let packBytes = new Uint8Array(info.bytes);
 let offset = 0;
 for (const part of info.parts) {
  const start = offset;
  let complete = false;
  for (let attempt = 0; attempt < 3 && !complete; attempt++) {
   offset = start;
   try {
    const response = await fetch(part.name);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    if (!response.body) throw new Error('Streaming downloads are not supported by this browser.');
    const reader = response.body.getReader();
    try {
     while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      if (offset + value.byteLength > start + part.bytes) throw new Error('Unexpected data size');
      packBytes.set(value, offset);
      offset += value.byteLength;
      if (overrides.onProgress) overrides.onProgress(offset, info.bytes);
     }
    } finally { await reader.cancel().catch(() => {}); reader.releaseLock(); }
    if (offset !== start + part.bytes) throw new Error('Incomplete download');
    const digest = await crypto.subtle.digest('SHA-256', packBytes.subarray(start, offset));
    const actualHash = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
    if (actualHash !== part.sha256) throw new Error('Game data integrity check failed');
    complete = true;
   } catch (error) {
    if (attempt === 2) throw new Error(`Game data could not be loaded (${part.name}). Please reload to retry. ${error.message}`);
    await new Promise(resolve => setTimeout(resolve, 500 * (attempt + 1)));
   }
  }
 }
 if (offset !== info.bytes) throw new Error('Incomplete game data. Please reload to retry.');
 // Engine.startGame() would fetch index.pck again. Use documented init,
 // preloadFile(ArrayBuffer, destination), and start({args}) instead.
 if (overrides.onProgress) overrides.onProgress(0, 0);
 await engine.load(GODOT_CONFIG.executable, GODOT_CONFIG.fileSizes[GODOT_CONFIG.executable + '.wasm']);
 await engine.init(GODOT_CONFIG.executable);
 await engine.preloadFile(packBytes.buffer, 'index.pck');
 packBytes = null;
 return engine.start(Object.assign({}, overrides, {
  args: ['--main-pack', 'index.pck'].concat(GODOT_CONFIG.args || [])
 }));
}
'''.replace('__MANIFEST__',json.dumps(manifest,separators=(',',':')))
source=source.replace('const engine = new Engine(GODOT_CONFIG);','const engine = new Engine(GODOT_CONFIG);\n'+loader)
source=source.replace('engine.startGame({','startChunkedGame({')
html.write_text(source)
(root/'pack-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
pack.unlink()
files=[x for x in root.rglob('*') if x.is_file()]
assert all(x.stat().st_size <= 200_000_000 for x in files)
assert sum(x.stat().st_size for x in files) <= 500_000_000
print(json.dumps({'bytes':size,'sha256':manifest['sha256'],'parts':parts,'total_web_bytes':sum(x.stat().st_size for x in files)},indent=2))
