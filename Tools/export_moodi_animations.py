import bpy,json,re
from pathlib import Path
# Reuse material reconstruction without invoking the model export loop.
module=Path(__file__).with_name('export_unity_models.py').read_text().split('names=sys.argv')[0]
exec(compile(module,'export_unity_models.py','exec'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT/'Assets/Model/Moodi_Rigged.fbx'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mat,issues=material(ROOT/INDEX['fbf7d65d3b7fc480a835804c96b02abe'])
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':
  for slot in ob.material_slots:slot.material=mat
out=DEST/'Moodium/Content/Animations';out.mkdir(parents=True,exist_ok=True)
report=[]
for action in list(bpy.data.actions):
 name=action.name.split('|')[-1]
 rig.animation_data_create();rig.animation_data.action=action
 if hasattr(action,'slots') and len(action.slots):rig.animation_data.action_slot=action.slots[0]
 bpy.context.scene.frame_start=int(action.frame_range[0]);bpy.context.scene.frame_end=int(action.frame_range[1]);bpy.context.scene.render.fps=30
 bpy.context.scene.frame_set(bpy.context.scene.frame_start)
 bpy.ops.wm.usd_export(filepath=str(out/(name+'.usdz')),export_animation=True,export_armatures=True,export_shapekeys=True,export_materials=True,export_lights=False,export_cameras=False,generate_preview_surface=True,convert_orientation=True,export_global_up_selection='Y',export_global_forward_selection='NEGATIVE_Z')
 report.append({'name':name,'source':'Assets/Model/Moodi_Rigged.fbx','frames':[bpy.context.scene.frame_start,bpy.context.scene.frame_end],'fps':30})
 print('ANIMATION',name,flush=True)
(DEST/'docs/animation-export-report.json').write_text(json.dumps(report,indent=2))
