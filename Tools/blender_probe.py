import bpy
print('EXPORT_PROPERTIES',[(p.identifier,p.type) for p in bpy.ops.wm.usd_export.get_rna_type().properties])
