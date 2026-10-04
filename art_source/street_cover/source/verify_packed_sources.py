import bpy,pathlib,json
root=pathlib.Path(__file__).resolve().parents[1]; report={}
for name in ('ruptured_water_main','shattered_road_obstruction'):
    bpy.ops.wm.open_mainfile(filepath=str(root/'source'/f'{name}.blend'))
    images=[im for im in bpy.data.images if im.type=='IMAGE' and not im.name.startswith('Render')]
    used={node.image.name:node.image for mat in bpy.data.materials if mat.use_nodes for node in mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image}
    assert all(im.packed_file is not None for im in used.values())
    parts=[ob for ob in bpy.data.objects if ob.type=='MESH']; assert len(parts)>40
    report[name]={'editable_component_objects':len(parts),'all_material_images_packed':True,'texture_images':sorted(used),'ground_contract':bpy.context.scene['normalized_size_godot']}
(root/'source_validation.json').write_text(json.dumps(report,indent=2))
print('PACKED_EDITABLE_SOURCE_PASS',json.dumps(report))
