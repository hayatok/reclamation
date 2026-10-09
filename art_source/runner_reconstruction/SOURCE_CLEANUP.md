# Portable editable runner source

The editable runner is saved as scene datablocks through Blender's supported
`bpy.data.libraries.write` API. This retains the complete scene, near/far meshes,
18-bone rig, vertex weights, materials, and packed owned atlas. It omits Screens,
WindowManager and Workspace data, including file-browser history. The render
output directory is relative. No mesh, pose, texture pixels or runtime GLB changed.

The cleaned file was reopened in a fresh Blender 4.3.2 process. Its active scene
contains the original rig plus both meshes. Blender emits “Library file, loading
empty scene” while making the missing UI context; the actual active scene and
editable content were verified. The library flag is intentional.

An independent reopen comparison found exact equality for scene object
transforms, all near/far vertex positions and triangles, both UV layers, vertex
groups/weights, rest bones/hierarchy, packed atlas bytes, and a freshly evaluated
run pose. A byte-level scan found no machine home/workspace/temp paths or the
previous file-browser fragments. The original input and frozen runtime files
remain unchanged.

`source/write_public_runner_source.py` can repeat the cleanup into a different
output filename. Run it with Blender and pass input/output after `--`. It uses
only supported datablock APIs, never raw binary editing. Relative image paths
stay relative, with the texture also packed into the file.

`source/generator_public_source.patch` proposes the same scene-only write for
future model regeneration. It changes only the editable-source save operation;
it is not applied to the frozen generator and has not been used to regenerate
runtime GLBs during this cleanup.
