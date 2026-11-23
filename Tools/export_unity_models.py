"""Run in isolated Blender background process; never opens/saves the user's Blender scene.
Converts Unity FBX + importer material overrides to USDZ. Unsupported shader features
are recorded for RealityKit implementation and visual verification, not silently accepted.
"""
import bpy,json,re,sys,hashlib
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]/'Moodium'
DEST=Path(__file__).resolve().parents[1]
INDEX=json.loads((DEST/'docs/unity-guid-index.json').read_text())
OUT=DEST/'Moodium/Content/Models';OUT.mkdir(parents=True,exist_ok=True)
report=[]
def tex(block,key):
 m=re.search(r'- '+re.escape(key)+r':\s*\n\s*m_Texture:.*?guid: ([0-9a-f]{32})',block)
 return ROOT/INDEX[m[1]] if m and m[1] in INDEX else None
def scalar(block,key,default):
 m=re.search(r'- '+re.escape(key)+r': ([\d.eE+-]+)',block);return float(m[1]) if m else default
def material(path):
 data=path.read_text();m=bpy.data.materials.new(path.stem);m.use_nodes=True
 bsdf=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 sm=scalar(data,'_Smoothness',.5)
 bsdf.inputs['Roughness'].default_value=1-sm
 bsdf.inputs['Metallic'].default_value=scalar(data,'_Metallic',0)
 col=re.search(r'- _BaseColor: \{r: ([\d.eE+-]+), g: ([\d.eE+-]+), b: ([\d.eE+-]+), a: ([\d.eE+-]+)',data)
 if col:bsdf.inputs['Base Color'].default_value=tuple(float(v) for v in col.groups())
 def image_node(p,linear=False):
  n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(p),check_existing=True)
  if linear:n.image.colorspace_settings.name='Non-Color'
  return n
 base=tex(data,'_BaseMap') or tex(data,'_MainTex')
 if base and base.exists():
  n=image_node(base);m.node_tree.links.new(n.outputs['Color'],bsdf.inputs['Base Color'])
 normal=tex(data,'_BumpMap')
 if normal and normal.exists():
  n=image_node(normal,True);nm=m.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=scalar(data,'_BumpScale',1)
  m.node_tree.links.new(n.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])
 # URP LitInput.hlsl: metallic = R; smoothness = A * _Smoothness.
 packed=tex(data,'_MetallicGlossMap')
 issues=[]
 if packed and packed.exists() and '_METALLICSPECGLOSSMAP' in data:
  source=bpy.data.images.load(str(packed),check_existing=True);source.colorspace_settings.name='Non-Color'
  pixels=np.empty(len(source.pixels),dtype=np.float32);source.pixels.foreach_get(pixels);rgba=pixels.reshape((-1,4))
  cache=DEST/'BuildAssets/Textures';cache.mkdir(parents=True,exist_ok=True)
  for suffix,values,socket in [('metallic',rgba[:,0],'Metallic'),('roughness',1-rgba[:,3]*sm,'Roughness')]:
   img=bpy.data.images.new(path.stem+'_'+suffix,width=source.size[0],height=source.size[1],alpha=False,float_buffer=False)
   img.colorspace_settings.name='Non-Color'
   result=np.ones_like(rgba);result[:,:3]=values[:,None]
   img.pixels.foreach_set(result.reshape(-1));img.filepath_raw=str(cache/(path.stem+'_'+suffix+'.png'));img.file_format='PNG';img.save()
   n=image_node(Path(img.filepath_raw),True);m.node_tree.links.new(n.outputs['Color'],bsdf.inputs[socket])
  issues.append('Packed metallic/smoothness channels converted using URP LitInput; visual validation pending')
 if scalar(data,'_Surface',0):issues.append('Transparent surface requires native blending validation')
 return m,issues
names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['CandyWorldUI','NatureWorldUI','CandySoft','NatureSoft','Moodi_Rigged']
for name in names:
 sources={'CandyWorldUI':'candyworld_lofi','NatureWorldUI':'natureworld_lofi'}
 p=ROOT/'Assets/Model'/f'{sources.get(name,name)}.fbx'
 if not p.exists():report.append({'name':name,'error':'Source missing'});continue
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.fbx(filepath=str(p))
 meta=Path(str(p)+'.meta').read_text();overrides={}
 for matname,guid in re.findall(r'name: ([^\n]+)\n\s*second: \{fileID: \d+, guid: ([0-9a-f]{32})',meta):
  if guid in INDEX:overrides[matname]=ROOT/INDEX[guid]
 # Prefab renderer overrides take precedence over importer assignments.
 prefab=ROOT/'Assets/prefab'/f'{name}.prefab'
 if prefab.exists():
  matches=re.findall(r"propertyPath: '?m_Materials.Array.data\[0\]'?\n\s*value:.*?\n\s*objectReference: \{fileID: \d+, guid: ([0-9a-f]{32})",prefab.read_text())
  if matches:
   for ob in bpy.context.scene.objects:
    for slot in ob.material_slots:
     if slot.material:overrides[slot.material.name]=ROOT/INDEX[matches[-1]]
 issues=[];materials={}
 for ob in bpy.context.scene.objects:
  for slot in ob.material_slots:
   if not slot.material:continue
   key=slot.material.name
   if key in overrides:
    if key not in materials:
     materials[key],flags=material(overrides[key]);issues.extend(flags)
    slot.material=materials[key]
 # FBX importer interprets source axis metadata; export converts Blender Z-up to USD Y-up.
 props=bpy.ops.wm.usd_export.get_rna_type().properties
 kw=dict(filepath=str(OUT/f'{name}.usdz'),export_animation=True,export_armatures=True,export_shapekeys=True,export_materials=True,export_lights=False,export_cameras=False,generate_preview_surface=True)
 if 'convert_orientation' in props:
  kw['convert_orientation']=True
  kw['export_global_up_selection']='Y';kw['export_global_forward_selection']='NEGATIVE_Z'
 bpy.ops.wm.usd_export(**kw)
 report.append({'name':name,'source':str(p.relative_to(ROOT)),'sourceSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'outputBytes':(OUT/f'{name}.usdz').stat().st_size,'materialOverrides':{k:str(v.relative_to(ROOT)) for k,v in overrides.items()},'pendingVisualChecks':sorted(set(issues)),'objects':len(bpy.context.scene.objects),'polygons':sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')})
 (DEST/'docs/model-export-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
 print('EXPORTED',name,flush=True)
