"""Package the built Flutter web app and required API modules for Vercel.
Run Flutter build web first; this script does not build or deploy.
No credentials or environment files are copied.
"""
from pathlib import Path
import shutil,re,json,hashlib
from datetime import datetime,timezone
root=Path(__file__).resolve().parent.parent
stamp=datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
stage=root/'.codex_tmp/releases'/stamp
assert not stage.exists(),'Release directory already exists; inspect before reusing'
assert (root/'build/web/main.dart.js').stat().st_size>1000000
stage.mkdir(parents=True)
shutil.copytree(root/'build/web',stage/'public')
queue=list((root/'api').glob('*.mjs'));seen=set()
while queue:
 f=queue.pop().resolve()
 if f in seen:continue
 rel=f.relative_to(root)
 assert rel.parts[0] in ('api','functions') and f.suffix=='.mjs'
 seen.add(f);dest=stage/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,dest)
 for imp in re.findall(r'''(?:from\s*|import\s*\()\s*['"](\.[^'"]+)['"]''',f.read_text()):
  queue.append((f.parent/imp).resolve())
shutil.copy2(root/'package.json',stage/'package.json')
config=json.loads((root/'vercel.json').read_text());config.update({'framework':None,'outputDirectory':'public','buildCommand':''})
config['headers']=[{'source':p,'headers':[{'key':'Cache-Control','value':'no-cache, no-store, must-revalidate'}]} for p in ['/','/index.html','/flutter_bootstrap.js','/flutter_service_worker.js','/main.dart.js','/version.json']]
(stage/'vercel.json').write_text(json.dumps(config,indent=2))
(stage/'.vercel').mkdir();shutil.copy2(root/'.vercel/project.json',stage/'.vercel/project.json')
manifest={f.relative_to(stage).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in stage.rglob('*') if f.is_file() and '.vercel' not in f.parts}
(stage/'release-manifest.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps({'stage':str(stage),'files':len(manifest),'api_helpers':[str(f.relative_to(root)) for f in sorted(seen)],'main_js_sha256':manifest['public/main.dart.js']}))
