import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'Moodium'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root/'Assets/Model/Moodi_Rigged.fbx'))
print('ACTIONS',[(a.name,list(a.frame_range)) for a in bpy.data.actions])
print('OBJECTS',[(o.name,o.type,list(o.dimensions)) for o in bpy.context.scene.objects])
