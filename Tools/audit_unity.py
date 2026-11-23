"""Read-only Unity dependency and serialized component audit."""
from pathlib import Path
import re,json,hashlib
ROOT=Path(__file__).resolve().parents[2]/'Moodium'
OUT=Path(__file__).resolve().parents[1]/'docs'
index={}
for p in (ROOT/'Assets').rglob('*.meta'):
 try:
  m=re.search(r'^guid: ([0-9a-f]{32})',p.read_text(),re.M)
  if m:index[m[1]]=Path(str(p)[:-5])
 except (UnicodeError,OSError):pass
scene=ROOT/'Assets/ARTnGAME/Meshing 1.unity'
pending=[scene];seen=set();entries=[]
# Include Resources assets because runtime loads are not serialized scene references.
pending+=list((ROOT/'Assets/Resources').rglob('*.asset'))
while pending:
 p=pending.pop()
 if p in seen or not p.is_file():continue
 seen.add(p); refs=set()
 for q in [p,Path(str(p)+'.meta')]:
  if q.exists() and (q.suffix in ['.meta','.unity','.prefab','.mat','.asset','.controller','.anim']):
   try:refs.update(re.findall(r'guid: ([0-9a-f]{32})',q.read_text()))
   except UnicodeError:pass
 pending.extend(index[g] for g in refs if g in index)
 entries.append({'path':str(p.relative_to(ROOT)),'bytes':p.stat().st_size,'references':[str(index[g].relative_to(ROOT)) for g in sorted(refs) if g in index]})
components=[]
for block in re.split(r'^--- ',scene.read_text(),flags=re.M):
 m=re.search(r'm_Script:.*guid: ([0-9a-f]{32})',block)
 if m and m[1] in index:
  components.append({'script':str(index[m[1]].relative_to(ROOT)),'serialized':block})
OUT.mkdir(exist_ok=True)
(OUT/'unity-dependency-audit.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2))
(OUT/'unity-scene-components.json').write_text(json.dumps(components,ensure_ascii=False,indent=2))
(OUT/'unity-guid-index.json').write_text(json.dumps({g:str(p.relative_to(ROOT)) for g,p in index.items()},ensure_ascii=False,indent=2))
print(f'{len(entries)} dependencies; {len(components)} scene script components; {len(index)} indexed assets')
