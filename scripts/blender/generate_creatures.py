#!/usr/bin/env python3
"""Headless Blender: sculpted, rigged dungeon creatures at real-world scale.

Humanoids are original organic meshes (subdivision, voxel remesh, displacement)
with a Mixamo-style armature and idle/walk/attack/hit/death clips.
Cave wolf is Quaternius CC0, with location/rotation/scale applied so the glTF
root is identity and the skinned mesh stands ~1 m tall on z=0.
"""

from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

OUT = os.environ.get("DD_MESH_OUT", os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "meshes")))
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WOLF_SRC = os.environ.get(
    "DD_WOLF_GLB",
    os.path.join(ROOT, "assets", "imported", "quaternius", "Wolf.glb"),
)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.engine = "CYCLES"
    scene.render.fps = 24
    scene.frame_start = 1
    scene.frame_end = 48


def _active(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_scale(obj: bpy.types.Object) -> None:
    _active(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)


def apply_all(obj: bpy.types.Object) -> None:
    _active(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)


def shade_smooth(obj: bpy.types.Object) -> None:
    _active(obj)
    try:
        bpy.ops.object.shade_smooth()
    except Exception:
        pass
    obj.select_set(False)


def unwrap(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    _active(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    except Exception:
        bpy.ops.uv.cube_project()
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def apply_mod(obj: bpy.types.Object, name: str) -> None:
    if name not in obj.modifiers:
        return
    _active(obj)
    try:
        bpy.ops.object.modifier_apply(modifier=name)
    except Exception:
        if name in obj.modifiers:
            obj.modifiers.remove(obj.modifiers[name])
    obj.select_set(False)


def triangulate(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    mod = obj.modifiers.new(name="Tri", type="TRIANGULATE")
    apply_mod(obj, mod.name)


def remesh(obj: bpy.types.Object, voxel: float = 0.012) -> None:
    if obj.type != "MESH":
        return
    kept = obj.name
    mod = obj.modifiers.new(name="Remesh", type="REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = max(0.004, voxel)
    apply_mod(obj, mod.name)
    obj.name = kept


def subdivide(obj: bpy.types.Object, levels: int = 1) -> None:
    if obj.type != "MESH" or levels < 1:
        return
    mod = obj.modifiers.new(name="Sub", type="SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    mod.subdivision_type = "CATMULL_CLARK"
    apply_mod(obj, mod.name)


def displace(obj: bpy.types.Object, strength: float = 0.006, scale: float = 0.11) -> None:
    if obj.type != "MESH" or abs(strength) < 1e-5:
        return
    tex = bpy.data.textures.new(f"disp_{obj.name}_{len(bpy.data.textures)}", type="CLOUDS")
    tex.noise_scale = scale
    tex.noise_depth = 2
    mod = obj.modifiers.new(name="Disp", type="DISPLACE")
    mod.texture = tex
    mod.strength = strength
    mod.mid_level = 0.5
    apply_mod(obj, mod.name)


def decimate(obj: bpy.types.Object, ratio: float = 0.4) -> None:
    if obj.type != "MESH" or ratio >= 0.99:
        return
    if len(obj.data.vertices) < 80:
        return
    mod = obj.modifiers.new(name="Dec", type="DECIMATE")
    mod.ratio = max(0.12, min(0.95, ratio))
    apply_mod(obj, mod.name)


def organicize(
    obj: bpy.types.Object,
    voxel: float = 0.012,
    disp: float = 0.005,
    sub: int = 1,
    collapse: float = 0.42,
    noise: float = 0.11,
) -> bpy.types.Object:
    """Melt primitives into an organic surface, then keep the file small."""
    if obj is None or obj.type != "MESH":
        return obj
    remesh(obj, voxel)
    if sub:
        subdivide(obj, sub)
    displace(obj, disp, noise)
    decimate(obj, collapse)
    triangulate(obj)
    shade_smooth(obj)
    unwrap(obj)
    return obj


def mesh_cube(size, loc=(0, 0, 0), rot=(0, 0, 0), name="Cube") -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size if len(size) == 3 else (size, size, size)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def mesh_cyl(r, depth, loc=(0, 0, 0), rot=(0, 0, 0), verts=16, name="Cyl") -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def mesh_ico(r, loc=(0, 0, 0), name="Ico", subdivisions=2) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, location=loc, subdivisions=subdivisions)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def mesh_uvsphere(r, loc=(0, 0, 0), name="Sphere", segments=16, rings=10) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=segments, ring_count=rings)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def mesh_cone(r1, r2, depth, loc=(0, 0, 0), rot=(0, 0, 0), name="Cone", verts=16) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def mesh_torus(major, minor, loc=(0, 0, 0), rot=(0, 0, 0), name="Torus") -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def boolean_diff(obj: bpy.types.Object, cutter: bpy.types.Object) -> None:
    mod = obj.modifiers.new(name="Bool", type="BOOLEAN")
    mod.operation = "DIFFERENCE"
    try:
        mod.solver = "EXACT"
    except Exception:
        mod.solver = "FAST"
    mod.object = cutter
    apply_mod(obj, mod.name)
    try:
        bpy.data.objects.remove(cutter, do_unlink=True)
    except Exception:
        pass


def join(objects: list[bpy.types.Object], name: str) -> bpy.types.Object:
    objects = [o for o in objects if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    objects[0].name = name
    return objects[0]


def export_glb(obj: bpy.types.Object, rel: str) -> None:
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for stray in list(bpy.data.objects):
        if stray == obj:
            continue
        if stray.type == "MESH" and stray.parent is None:
            bpy.data.objects.remove(stray, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for child in obj.children_recursive:
        child.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        use_selection=True,
        export_format="GLB",
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="NONE",
        export_animations=True,
        export_skins=True,
        export_yup=True,
        export_nla_strips=True,
        export_force_sampling=True,
        export_anim_single_armature=True,
        export_def_bones=False,
    )
    print("exported", path, "bytes", os.path.getsize(path))


def humanoid_bones() -> list:
    return [
        ("Hips", (0, 0, 0.90), (0, 0, 1.02)),
        ("Spine", (0, 0, 1.02), (0, 0, 1.18), "Hips"),
        ("Spine1", (0, 0, 1.18), (0, 0, 1.34), "Spine"),
        ("Spine2", (0, 0, 1.34), (0, 0, 1.48), "Spine1"),
        ("Neck", (0, 0, 1.48), (0, 0, 1.56), "Spine2"),
        ("Head", (0, 0, 1.56), (0, 0, 1.74), "Neck"),
        ("LeftShoulder", (0.04, 0, 1.46), (0.16, 0, 1.45), "Spine2"),
        ("LeftArm", (0.16, 0, 1.45), (0.20, 0.02, 1.16), "LeftShoulder"),
        ("LeftForeArm", (0.20, 0.02, 1.16), (0.22, 0.03, 0.92), "LeftArm"),
        ("LeftHand", (0.22, 0.03, 0.92), (0.23, 0.04, 0.82), "LeftForeArm"),
        ("RightShoulder", (-0.04, 0, 1.46), (-0.16, 0, 1.45), "Spine2"),
        ("RightArm", (-0.16, 0, 1.45), (-0.20, 0.02, 1.16), "RightShoulder"),
        ("RightForeArm", (-0.20, 0.02, 1.16), (-0.22, 0.03, 0.92), "RightArm"),
        ("RightHand", (-0.22, 0.03, 0.92), (-0.23, 0.04, 0.82), "RightForeArm"),
        ("LeftUpLeg", (0.10, 0, 0.90), (0.11, 0.01, 0.50), "Hips"),
        ("LeftLeg", (0.11, 0.01, 0.50), (0.12, 0.02, 0.12), "LeftUpLeg"),
        ("LeftFoot", (0.12, 0.02, 0.12), (0.12, 0.10, 0.03), "LeftLeg"),
        ("RightUpLeg", (-0.10, 0, 0.90), (-0.11, 0.01, 0.50), "Hips"),
        ("RightLeg", (-0.11, 0.01, 0.50), (-0.12, 0.02, 0.12), "RightUpLeg"),
        ("RightFoot", (-0.12, 0.02, 0.12), (-0.12, 0.10, 0.03), "RightLeg"),
    ]


def bind_mesh(obj: bpy.types.Object, arm: bpy.types.Object, bone: str) -> None:
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = arm
    mod.use_vertex_groups = True
    obj.parent = arm
    obj.parent_type = "OBJECT"


def bind_auto(mesh: bpy.types.Object, arm: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except Exception:
        bind_mesh(mesh, arm, "Hips")


def add_armature(bones: list, actions: dict) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = "Armature"
    eb = arm.data.edit_bones
    root = eb[0]
    root.name = bones[0][0]
    root.head = Vector(bones[0][1])
    root.tail = Vector(bones[0][2])
    created = {root.name: root}
    for spec in bones[1:]:
        name, head, tail, parent = spec
        bone = eb.new(name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        bone.use_connect = False
        if parent in created:
            bone.parent = created[parent]
        created[name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.animation_data_create()
    for clip, keys in actions.items():
        act = bpy.data.actions.new(name=clip)
        act.use_fake_user = True
        arm.animation_data.action = act
        for bone_name, frames in keys.items():
            pb = arm.pose.bones.get(bone_name)
            if pb is None:
                continue
            pb.rotation_mode = "XYZ"
            for frame, euler in frames:
                bpy.context.scene.frame_set(frame)
                pb.rotation_euler = Euler(euler, "XYZ")
                pb.keyframe_insert(data_path="rotation_euler", frame=frame)
            for fcu in act.fcurves:
                for kp in fcu.keyframe_points:
                    kp.interpolation = "BEZIER"
        track = arm.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 1, act)
    arm.animation_data.action = None
    bpy.context.scene.frame_set(1)
    return arm


def humanoid_actions() -> dict:
    idle = {
        "Spine": [(1, (0, 0, 0)), (24, (0.05, 0, 0)), (48, (0, 0, 0))],
        "Spine1": [(1, (0, 0, 0)), (24, (0.04, 0.02, 0)), (48, (0, 0, 0))],
        "Head": [(1, (0, 0, 0)), (24, (0.06, 0.05, 0)), (48, (0, 0, 0))],
        "LeftArm": [(1, (0.08, 0, 0)), (24, (0.14, 0, 0.04)), (48, (0.08, 0, 0))],
        "RightArm": [(1, (0.08, 0, 0)), (24, (0.12, 0, -0.04)), (48, (0.08, 0, 0))],
    }
    walk = {
        "Hips": [(1, (0, 0, 0.04)), (12, (0, 0, -0.04)), (24, (0, 0, 0.04))],
        "LeftUpLeg": [(1, (0.55, 0, 0)), (12, (-0.55, 0, 0)), (24, (0.55, 0, 0))],
        "RightUpLeg": [(1, (-0.55, 0, 0)), (12, (0.55, 0, 0)), (24, (-0.55, 0, 0))],
        "LeftLeg": [(1, (0.15, 0, 0)), (12, (0.45, 0, 0)), (24, (0.15, 0, 0))],
        "RightLeg": [(1, (0.45, 0, 0)), (12, (0.15, 0, 0)), (24, (0.45, 0, 0))],
        "LeftArm": [(1, (-0.45, 0, 0)), (12, (0.45, 0, 0)), (24, (-0.45, 0, 0))],
        "RightArm": [(1, (0.45, 0, 0)), (12, (-0.45, 0, 0)), (24, (0.45, 0, 0))],
        "Spine": [(1, (0.04, 0, 0.05)), (12, (0.04, 0, -0.05)), (24, (0.04, 0, 0.05))],
        "Head": [(1, (0, 0, -0.04)), (12, (0, 0, 0.04)), (24, (0, 0, -0.04))],
    }
    attack = {
        "RightArm": [(1, (0, 0, 0)), (8, (-1.55, 0.15, 0.35)), (14, (0.85, -0.1, -0.2)), (20, (0, 0, 0))],
        "RightForeArm": [(1, (0, 0, 0)), (8, (-0.4, 0, 0)), (14, (0.2, 0, 0)), (20, (0, 0, 0))],
        "Spine": [(1, (0, 0, 0)), (8, (0.12, 0, 0.18)), (14, (0.2, 0, -0.12)), (20, (0, 0, 0))],
        "Spine2": [(1, (0, 0, 0)), (8, (0.1, 0, 0.12)), (14, (0.05, 0, -0.08)), (20, (0, 0, 0))],
        "Head": [(1, (0, 0, 0)), (8, (0.1, 0, 0.1)), (14, (0.15, 0, -0.05)), (20, (0, 0, 0))],
        "LeftArm": [(1, (0.1, 0, 0)), (8, (0.3, 0, -0.2)), (20, (0.1, 0, 0))],
    }
    hit = {
        "Spine": [(1, (0, 0, 0)), (5, (-0.22, 0, -0.12)), (12, (0, 0, 0))],
        "Head": [(1, (0, 0, 0)), (5, (-0.18, 0.1, 0.08)), (12, (0, 0, 0))],
        "LeftArm": [(1, (0, 0, 0)), (5, (0.7, 0, 0.4)), (12, (0, 0, 0))],
        "RightArm": [(1, (0, 0, 0)), (5, (0.55, 0, -0.3)), (12, (0, 0, 0))],
        "Hips": [(1, (0, 0, 0)), (5, (-0.08, 0, 0)), (12, (0, 0, 0))],
    }
    death = {
        "Hips": [(1, (0, 0, 0)), (10, (0.4, 0, 0)), (24, (1.45, 0, 0))],
        "Spine": [(1, (0, 0, 0)), (10, (0.35, 0, 0.1)), (24, (0.55, 0, 0))],
        "Head": [(1, (0, 0, 0)), (10, (0.4, 0, 0)), (24, (0.7, 0.2, 0))],
        "LeftArm": [(1, (0, 0, 0)), (24, (0.8, 0.4, 0.3))],
        "RightArm": [(1, (0, 0, 0)), (24, (0.9, -0.3, -0.2))],
        "LeftUpLeg": [(1, (0, 0, 0)), (24, (0.5, 0, 0.2))],
        "RightUpLeg": [(1, (0, 0, 0)), (24, (0.35, 0, -0.25))],
    }
    return {"idle": idle, "walk": walk, "attack": attack, "hit": hit, "death": death}


def skin_groups(arm: bpy.types.Object, groups: dict[str, list[bpy.types.Object]]) -> None:
    for bone, meshes in groups.items():
        for mesh in meshes:
            if mesh is None or mesh.type != "MESH":
                continue
            triangulate(mesh)
            if mesh.data:
                mesh.data.name = mesh.name[:60]
            bind_mesh(mesh, arm, bone)


def deform_cranium(obj: bpy.types.Object) -> None:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for v in bm.verts:
        if v.co.y > 0.03 and abs(v.co.z) < 0.045:
            v.co.y += 0.014
            v.co.z += 0.007
        if v.co.y < -0.05:
            v.co.y -= 0.012
            v.co.z += 0.006
        if v.co.z < -0.025 and v.co.y > 0.0:
            v.co.z -= 0.01
        if abs(v.co.x) > 0.045 and v.co.y > 0.01:
            v.co.x *= 1.07
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def make_mandible(loc, prefix: str) -> bpy.types.Object:
    x, y, z = loc
    curve_data = bpy.data.curves.new(f"{prefix}_jawcurve", type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.bevel_depth = 0.011
    curve_data.bevel_resolution = 4
    curve_data.fill_mode = "FULL"
    spline = curve_data.splines.new("NURBS")
    pts = [
        (x - 0.072, y - 0.018, z + 0.085),
        (x - 0.078, y + 0.008, z + 0.028),
        (x - 0.068, y + 0.038, z - 0.018),
        (x - 0.048, y + 0.052, z - 0.038),
        (x - 0.022, y + 0.058, z - 0.046),
        (x, y + 0.062, z - 0.050),
        (x + 0.022, y + 0.058, z - 0.046),
        (x + 0.048, y + 0.052, z - 0.038),
        (x + 0.068, y + 0.038, z - 0.018),
        (x + 0.078, y + 0.008, z + 0.028),
        (x + 0.072, y - 0.018, z + 0.085),
    ]
    spline.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        spline.points[i].co = (p[0], p[1], p[2], 1.0)
    spline.use_endpoint_u = True
    spline.order_u = 4
    obj = bpy.data.objects.new(f"{prefix}_jaw", curve_data)
    bpy.context.collection.objects.link(obj)
    _active(obj)
    bpy.ops.object.convert(target="MESH")
    jaw = bpy.context.active_object
    jaw.name = f"{prefix}_jaw"
    cond_l = mesh_ico(0.016, (x - 0.07, y - 0.016, z + 0.09), f"{prefix}_condL", 2)
    cond_r = mesh_ico(0.016, (x + 0.07, y - 0.016, z + 0.09), f"{prefix}_condR", 2)
    chin = mesh_ico(0.018, (x, y + 0.055, z - 0.052), f"{prefix}_chin", 2)
    chin.scale = (1.3, 0.9, 0.7)
    apply_scale(chin)
    jaw = join([jaw, cond_l, cond_r, chin], f"{prefix}_jaw")
    organicize(jaw, voxel=0.007, disp=0.0022, sub=1, collapse=0.5, noise=0.07)
    return jaw


def make_teeth(loc, prefix: str) -> list[bpy.types.Object]:
    x, y, z = loc
    teeth = []
    for i, sx in enumerate((-0.034, -0.02, -0.008, 0.008, 0.02, 0.034)):
        t = mesh_cube((0.007, 0.007, 0.014), (x + sx, y + 0.058, z - 0.034), name=f"{prefix}_tooth{i}")
        teeth.append(t)
    return teeth


def make_skull(loc, prefix: str = "Bone") -> list[bpy.types.Object]:
    x, y, z = loc
    cranium = mesh_uvsphere(0.112, (x, y + 0.012, z + 0.028), f"{prefix}_skull", 32, 18)
    cranium.scale = (0.90, 1.20, 1.08)
    apply_scale(cranium)
    deform_cranium(cranium)
    for sx in (-1.0, 1.0):
        cutter = mesh_uvsphere(0.033, (x + sx * 0.04, y + 0.10, z + 0.018), "cut_eye", 16, 10)
        cutter.scale = (1.08, 1.45, 1.18)
        apply_scale(cutter)
        boolean_diff(cranium, cutter)
    nose_cut = mesh_cone(0.017, 0.005, 0.055, (x, y + 0.118, z - 0.022), (math.pi * 0.5, 0, 0), name="cut_nose", verts=12)
    boolean_diff(cranium, nose_cut)
    magnum = mesh_cyl(0.017, 0.05, (x, y - 0.02, z - 0.07), (math.pi * 0.5, 0, 0), verts=12, name="cut_magnum")
    boolean_diff(cranium, magnum)
    organicize(cranium, voxel=0.007, disp=0.0035, sub=1, collapse=0.48, noise=0.08)
    jaw = make_mandible((x, y + 0.012, z - 0.08), prefix)
    teeth = make_teeth((x, y + 0.012, z - 0.02), prefix)
    sockets = [
        mesh_uvsphere(0.017, (x + 0.04, y + 0.082, z + 0.016), "Cavity_eye0", 12, 8),
        mesh_uvsphere(0.017, (x - 0.04, y + 0.082, z + 0.016), "Cavity_eye1", 12, 8),
        mesh_uvsphere(0.012, (x, y + 0.10, z - 0.02), "Cavity_nose", 10, 7),
    ]
    return [cranium, jaw, *teeth, *sockets]


def make_vertebra(z: float, name: str, radius: float = 0.024) -> bpy.types.Object:
    body = mesh_ico(radius * 1.05, (0, 0.012, z), name + "_body", 2)
    body.scale = (1.15, 0.82, 0.72)
    apply_scale(body)
    arch = mesh_torus(radius * 0.95, radius * 0.28, (0, -0.012, z), (math.pi * 0.5, 0, 0), name=name + "_arch")
    obj = join([body, arch], name)
    organicize(obj, voxel=0.008, disp=0.0018, sub=0, collapse=0.55, noise=0.06)
    return obj


def curve_rib(z: float, side: float, name: str, radius: float = 0.16, depth: float = 0.11) -> bpy.types.Object:
    curve_data = bpy.data.curves.new(name, type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.bevel_depth = 0.0085
    curve_data.bevel_resolution = 3
    curve_data.fill_mode = "FULL"
    spline = curve_data.splines.new("NURBS")
    count = 11
    spline.points.add(count - 1)
    for i in range(count):
        t = i / (count - 1) * math.pi * 0.94
        x = side * radius * math.sin(t)
        y = depth * math.cos(t) * 0.88 + 0.015
        zz = z + 0.016 * math.sin(t)
        spline.points[i].co = (x, y, zz, 1.0)
    spline.use_endpoint_u = True
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    _active(obj)
    bpy.ops.object.convert(target="MESH")
    rib = bpy.context.active_object
    rib.name = name
    organicize(rib, voxel=0.007, disp=0.0016, sub=0, collapse=0.6, noise=0.05)
    return rib


def sculpt_long_bone(r: float, length: float, loc, rot, name: str) -> list[bpy.types.Object]:
    shaft = mesh_cyl(r * 0.82, length * 0.76, loc, rot, verts=18, name=name + "_shaft")
    orient = Euler(rot, "XYZ").to_matrix()
    center = Vector(loc)
    half = orient @ Vector((0.0, 0.0, length * 0.48))
    head = mesh_ico(r * 1.58, tuple(center + half), name + "_head", 3)
    head.scale = (1.18, 0.92, 0.86)
    apply_scale(head)
    tail = mesh_ico(r * 1.42, tuple(center - half), name + "_tail", 3)
    tail.scale = (1.08, 1.18, 0.9)
    apply_scale(tail)
    bump = mesh_ico(r * 0.92, tuple(center + half * 0.28), name + "_tub", 2)
    obj = join([shaft, head, tail, bump], name)
    organicize(obj, voxel=max(0.008, r * 0.32), disp=r * 0.11, sub=1, collapse=0.42, noise=0.09)
    return [obj]


def make_hand(side: float, loc, prefix: str = "Bone") -> list[bpy.types.Object]:
    x, y, z = loc
    tag = "L" if side > 0 else "R"
    palm = mesh_cube((0.048, 0.02, 0.068), (x, y, z), name=f"{prefix}_palm{tag}")
    parts = [palm]
    fingers = [(-0.018, 0.55, 3), (-0.006, 0.72, 3), (0.006, 0.68, 3), (0.016, 0.50, 2)]
    for i, (ox, length, joints) in enumerate(fingers):
        px = x + side * ox
        pz = z - 0.04
        for j in range(joints):
            seg_len = length * 0.028
            pz = pz - seg_len * 0.55
            parts.append(mesh_cyl(0.0062 - j * 0.001, seg_len, (px, y + 0.005, pz), (0.12, 0, 0), verts=8, name=f"{prefix}_finger{tag}{i}{j}"))
            parts.append(mesh_ico(0.0072 - j * 0.001, (px, y + 0.005, pz + seg_len * 0.45), f"{prefix}_knuck{tag}{i}{j}", 1))
    parts.append(mesh_cyl(0.007, 0.045, (x + side * 0.03, y + 0.015, z - 0.01), (0.6, side * 0.8, 0.2), verts=8, name=f"{prefix}_thumb{tag}"))
    obj = join(parts, f"{prefix}_hand{tag}")
    organicize(obj, voxel=0.006, disp=0.0018, sub=0, collapse=0.5, noise=0.05)
    return [obj]


def make_foot(side: float, loc, prefix: str = "Bone") -> list[bpy.types.Object]:
    x, y, z = loc
    tag = "L" if side > 0 else "R"
    heel = mesh_ico(0.03, (x, y - 0.01, z + 0.02), f"{prefix}_heel{tag}", 2)
    heel.scale = (0.95, 1.15, 0.72)
    apply_scale(heel)
    arch = mesh_cube((0.048, 0.11, 0.026), (x, y + 0.04, z + 0.012), name=f"{prefix}_arch{tag}")
    toes = []
    for i, ox in enumerate((-0.016, -0.005, 0.006, 0.016)):
        toes.append(mesh_cyl(0.006, 0.034, (x + ox, y + 0.10, z + 0.01), (math.pi * 0.5, 0, 0), verts=8, name=f"{prefix}_toe{tag}{i}"))
    obj = join([heel, arch, *toes], f"{prefix}_foot{tag}")
    organicize(obj, voxel=0.007, disp=0.002, sub=0, collapse=0.5, noise=0.05)
    return [obj]


def make_pelvis(z: float = 0.94, prefix: str = "Bone") -> list[bpy.types.Object]:
    parts = []
    for side, sx in (("L", 1.0), ("R", -1.0)):
        wing = mesh_ico(0.092, (sx * 0.09, 0.01, z), f"{prefix}_ilium{side}", 3)
        wing.scale = (0.88, 0.58, 1.18)
        wing.rotation_euler = (0.25, sx * 0.35, sx * 0.4)
        apply_scale(wing)
        apply_all(wing)
        parts.append(wing)
    sacrum = mesh_cube((0.068, 0.052, 0.12), (0, -0.01, z + 0.02), name=f"{prefix}_sacrum")
    pubis = mesh_torus(0.048, 0.011, (0, 0.04, z - 0.05), (math.pi * 0.5, 0, 0), name=f"{prefix}_pubis")
    pubis.scale = (1.12, 0.72, 0.82)
    apply_scale(pubis)
    obj = join(parts + [sacrum, pubis], f"{prefix}_pelvis")
    organicize(obj, voxel=0.009, disp=0.003, sub=1, collapse=0.45, noise=0.08)
    return [obj]


def drape_cloth(obj: bpy.types.Object, folds: int = 8, amp: float = 0.04, loc_z: float = 0.55, depth: float = 1.05) -> None:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    z0 = loc_z - depth * 0.5
    for v in bm.verts:
        ang = math.atan2(v.co.y, v.co.x)
        h = (v.co.z - z0) / max(0.01, depth)
        fold = amp * math.sin(ang * folds + h * 2.4) * (0.25 + 0.75 * (1.0 - max(0.0, min(1.0, h))))
        v.co.x += math.cos(ang) * fold
        v.co.y += math.sin(ang) * fold
        if h < 0.2:
            v.co.z -= 0.05 * abs(math.sin(ang * 5.0))
            if abs(math.sin(ang * 9.0 + h * 7.0)) > 0.62:
                v.co.z -= 0.14 * (0.2 - h)
                v.co.x += math.cos(ang) * 0.03
                v.co.y += math.sin(ang) * 0.03
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def make_robe(name: str, loc_z: float, r1: float, r2: float, depth: float, folds: int = 8) -> bpy.types.Object:
    obj = mesh_cone(r1, r2, depth, (0, 0.02, loc_z), name=name, verts=48)
    subdivide(obj, 2)
    drape_cloth(obj, folds=folds, amp=0.045, loc_z=loc_z, depth=depth)
    organicize(obj, voxel=0.016, disp=0.01, sub=1, collapse=0.34, noise=0.16)
    return obj


def make_tatters(bone_z: float = 0.22) -> list[bpy.types.Object]:
    parts = []
    for i, x in enumerate((-0.18, -0.07, 0.05, 0.16)):
        strip = mesh_cube((0.055, 0.012, 0.42), (x, 0.05, bone_z), (0.18 * (i - 1.5), 0.08 * (i % 2), 0.05), name=f"Tatter_{i}")
        subdivide(strip, 2)
        drape_cloth(strip, folds=5, amp=0.02, loc_z=bone_z, depth=0.42)
        organicize(strip, voxel=0.012, disp=0.008, sub=0, collapse=0.45, noise=0.12)
        parts.append(strip)
    return parts


def make_hood(loc, name: str = "Hood_cowl") -> bpy.types.Object:
    hood = mesh_uvsphere(0.16, loc, name, 28, 16)
    hood.scale = (1.08, 1.28, 0.92)
    apply_scale(hood)
    cutter = mesh_uvsphere(0.11, (loc[0], loc[1] + 0.13, loc[2] - 0.01), "cut_hood", 16, 10)
    boolean_diff(hood, cutter)
    organicize(hood, voxel=0.012, disp=0.008, sub=1, collapse=0.4, noise=0.14)
    return hood


def make_held_sword() -> list[bpy.types.Object]:
    # Rest-pose at the right hand so the blade follows attack/walk/death.
    x, y, z = -0.23, 0.045, 0.87
    blade = mesh_cube((0.026, 0.007, 0.58), (x + 0.01, y + 0.02, z - 0.32), (0.18, 0.08, -0.05), name="Sword_blade")
    tip = mesh_cone(0.013, 0.0, 0.09, (x + 0.02, y + 0.035, z - 0.64), (0.18, 0.08, -0.05), name="Sword_tip", verts=10)
    guard = mesh_cube((0.11, 0.022, 0.018), (x, y + 0.02, z - 0.02), (0.18, 0.08, -0.05), name="Sword_guard")
    grip = mesh_cyl(0.012, 0.09, (x - 0.005, y + 0.015, z + 0.04), (0.18, 0.08, -0.05), verts=12, name="Sword_grip")
    pommel = mesh_ico(0.016, (x - 0.01, y + 0.012, z + 0.09), "Sword_pommel", 2)
    blade = join([blade, tip], "Sword_blade")
    organicize(blade, voxel=0.008, disp=0.0012, sub=0, collapse=0.55, noise=0.04)
    organicize(guard, voxel=0.008, disp=0.001, sub=0, collapse=0.6, noise=0.04)
    return [blade, guard, grip, pommel]


def make_held_staff() -> list[bpy.types.Object]:
    x, y, z = -0.23, 0.05, 0.87
    shaft = mesh_cyl(0.016, 1.42, (x - 0.02, y + 0.04, z + 0.52), (0.12, 0.16, 0.04), verts=12, name="Staff_shaft")
    organicize(shaft, voxel=0.01, disp=0.002, sub=0, collapse=0.5, noise=0.08)
    orb = mesh_ico(0.055, (x - 0.08, y + 0.12, z + 1.22), "Glow_orb", 3)
    wrap = mesh_torus(0.042, 0.008, (x - 0.08, y + 0.12, z + 1.22), name="Metal_orbcap")
    organicize(wrap, voxel=0.008, disp=0.0015, sub=0, collapse=0.55, noise=0.05)
    return [shaft, orb, wrap]


def make_held_club() -> list[bpy.types.Object]:
    x, y, z = -0.26, 0.08, 0.90
    shaft = mesh_cyl(0.042, 0.95, (x - 0.08, y + 0.06, z - 0.12), (0.55, 0.22, 0.12), verts=12, name="Club_shaft")
    organicize(shaft, voxel=0.012, disp=0.004, sub=0, collapse=0.5, noise=0.1)
    head = mesh_ico(0.13, (x - 0.22, y + 0.16, z + 0.38), "Club_head", 3)
    head.scale = (1.15, 1.05, 0.9)
    apply_scale(head)
    organicize(head, voxel=0.014, disp=0.008, sub=1, collapse=0.4, noise=0.12)
    return [shaft, head]


def armor_shell(size, loc, rot, name: str) -> bpy.types.Object:
    obj = mesh_cube(size, loc, rot, name=name)
    organicize(obj, voxel=0.011, disp=0.0028, sub=1, collapse=0.42, noise=0.07)
    return obj


def build_skeleton_parts() -> dict[str, list[bpy.types.Object]]:
    groups: dict[str, list[bpy.types.Object]] = {b[0]: [] for b in humanoid_bones()}
    groups["Head"] += make_skull((0, 0.02, 1.62))
    for i in range(3):
        groups["Neck"].append(make_vertebra(1.50 + i * 0.022, f"Bone_cerv{i}", 0.018))
    for i in range(6):
        z = 1.20 + i * 0.045
        groups["Spine1"].append(make_vertebra(z, f"Bone_thor{i}", 0.022))
        radius = 0.17 - i * 0.008
        groups["Spine1"].append(curve_rib(z + 0.01, 1.0, f"Bone_ribL{i}", radius, 0.11))
        groups["Spine1"].append(curve_rib(z + 0.01, -1.0, f"Bone_ribR{i}", radius, 0.11))
    sternum = mesh_cube((0.032, 0.024, 0.20), (0, 0.09, 1.30), name="Bone_sternum")
    organicize(sternum, voxel=0.008, disp=0.002, sub=0, collapse=0.55, noise=0.06)
    groups["Spine1"].append(sternum)
    for i in range(4):
        groups["Spine"].append(make_vertebra(1.04 + i * 0.035, f"Bone_lumb{i}", 0.023))
    groups["Hips"] += make_pelvis(0.93)
    groups["LeftArm"] += sculpt_long_bone(0.028, 0.28, (0.18, 0.02, 1.30), (0.12, 0.0, 0.15), "Bone_humerusL")
    groups["LeftForeArm"] += sculpt_long_bone(0.022, 0.26, (0.21, 0.03, 1.04), (0.08, 0.0, 0.08), "Bone_ulnaL")
    groups["LeftHand"] += make_hand(1.0, (0.23, 0.04, 0.88))
    groups["RightArm"] += sculpt_long_bone(0.028, 0.28, (-0.18, 0.02, 1.30), (0.12, 0.0, -0.15), "Bone_humerusR")
    groups["RightForeArm"] += sculpt_long_bone(0.022, 0.26, (-0.21, 0.03, 1.04), (0.08, 0.0, -0.08), "Bone_ulnaR")
    groups["RightHand"] += make_hand(-1.0, (-0.23, 0.04, 0.88))
    groups["LeftUpLeg"] += sculpt_long_bone(0.036, 0.40, (0.11, 0.01, 0.70), (0.06, 0, 0), "Bone_femurL")
    groups["LeftLeg"] += sculpt_long_bone(0.028, 0.38, (0.12, 0.02, 0.31), (0.04, 0, 0), "Bone_tibiaL")
    groups["LeftFoot"] += make_foot(1.0, (0.12, 0.04, 0.05))
    groups["RightUpLeg"] += sculpt_long_bone(0.036, 0.40, (-0.11, 0.01, 0.70), (0.06, 0, 0), "Bone_femurR")
    groups["RightLeg"] += sculpt_long_bone(0.028, 0.38, (-0.12, 0.02, 0.31), (0.04, 0, 0), "Bone_tibiaR")
    groups["RightFoot"] += make_foot(-1.0, (-0.12, 0.04, 0.05))
    return groups


def add_warrior_kit(groups: dict[str, list[bpy.types.Object]]) -> None:
    groups["LeftShoulder"].append(armor_shell((0.14, 0.08, 0.07), (0.18, 0.03, 1.46), (0.2, 0, 0.25), "Armor_pauldronL"))
    groups["RightShoulder"].append(armor_shell((0.14, 0.08, 0.07), (-0.18, 0.03, 1.46), (0.2, 0, -0.25), "Armor_pauldronR"))
    groups["Hips"].append(armor_shell((0.22, 0.07, 0.045), (0, 0.03, 0.94), (0, 0, 0), "Armor_belt"))
    groups["LeftLeg"].append(armor_shell((0.08, 0.05, 0.14), (0.13, 0.03, 0.22), (0, 0, 0), "Armor_greaveL"))
    groups["RightLeg"].append(armor_shell((0.08, 0.05, 0.14), (-0.13, 0.03, 0.22), (0, 0, 0), "Armor_greaveR"))
    groups["RightHand"] += make_held_sword()


def add_lich_kit(groups: dict[str, list[bpy.types.Object]]) -> None:
    groups["Hips"].append(make_robe("Robe_skirt", 0.55, 0.40, 0.11, 1.08, folds=9))
    groups["Hips"] += make_tatters(0.20)
    groups["Neck"].append(make_hood((0, 0.05, 1.58), "Robe_cowl"))
    circlet = mesh_torus(0.10, 0.012, (0, 0.02, 1.76), name="Crown_ring")
    organicize(circlet, voxel=0.008, disp=0.004, sub=1, collapse=0.45, noise=0.07)
    groups["Head"].append(circlet)
    for i, sx in enumerate((0.0, 0.07, -0.07)):
        spike = mesh_cone(0.018, 0.0, 0.09 if i else 0.12, (sx, 0.02, 1.86 if i else 1.90), name=f"Crown_spike{i}", verts=8)
        organicize(spike, voxel=0.008, disp=0.002, sub=0, collapse=0.55, noise=0.05)
        groups["Head"].append(spike)
    groups["RightHand"] += make_held_staff()
    groups["Hips"].append(armor_shell((0.18, 0.055, 0.038), (0, 0.04, 0.96), (0, 0, 0), "Armor_belt"))


def add_wraith_kit(groups: dict[str, list[bpy.types.Object]]) -> None:
    groups["Hips"].append(make_robe("Robe_body", 0.70, 0.46, 0.08, 1.36, folds=10))
    groups["Hips"] += make_tatters(0.16)
    groups["Head"].append(make_hood((0, 0.04, 1.58), "Hood_cowl"))
    sleeve_l = mesh_cone(0.09, 0.028, 0.50, (0.28, 0.04, 1.12), (0, 0, 0.9), name="Robe_sleeveL", verts=20)
    sleeve_r = mesh_cone(0.09, 0.028, 0.50, (-0.28, 0.04, 1.12), (0, 0, -0.9), name="Robe_sleeveR", verts=20)
    organicize(sleeve_l, voxel=0.014, disp=0.008, sub=1, collapse=0.4, noise=0.14)
    organicize(sleeve_r, voxel=0.014, disp=0.008, sub=1, collapse=0.4, noise=0.14)
    groups["LeftArm"].append(sleeve_l)
    groups["RightArm"].append(sleeve_r)
    groups["Head"].append(mesh_uvsphere(0.015, (0.035, 0.11, 1.64), "Glow_eyeL", 10, 7))
    groups["Head"].append(mesh_uvsphere(0.015, (-0.035, 0.11, 1.64), "Glow_eyeR", 10, 7))


def make_troll_flesh() -> bpy.types.Object:
    parts = []
    torso = mesh_ico(0.36, (0.04, 0.07, 1.20), "Hide_torso", 4)
    torso.scale = (1.38, 0.98, 1.22)
    apply_scale(torso)
    parts.append(torso)
    chest = mesh_ico(0.22, (0.08, 0.14, 1.32), "Hide_chest", 3)
    chest.scale = (1.45, 0.7, 0.7)
    apply_scale(chest)
    parts.append(chest)
    belly = mesh_ico(0.30, (0.08, 0.12, 0.90), "Hide_belly", 4)
    belly.scale = (1.25, 1.05, 1.05)
    apply_scale(belly)
    parts.append(belly)
    hips = mesh_ico(0.22, (0.02, 0.04, 0.78), "Hide_hips", 3)
    hips.scale = (1.35, 0.9, 0.75)
    apply_scale(hips)
    parts.append(hips)
    head = mesh_ico(0.17, (0.12, 0.14, 1.64), "Hide_head", 4)
    head.scale = (1.18, 1.12, 1.08)
    apply_scale(head)
    parts.append(head)
    snout = mesh_ico(0.09, (0.22, 0.22, 1.54), "Hide_snout", 3)
    snout.scale = (1.35, 1.15, 0.75)
    apply_scale(snout)
    parts.append(snout)
    brow = mesh_ico(0.07, (0.16, 0.22, 1.72), "Hide_brow", 2)
    brow.scale = (1.6, 0.6, 0.45)
    apply_scale(brow)
    parts.append(brow)
    for sx, bone_x, bone_z, r in (
        (1.0, 0.28, 1.40, 0.13),
        (-1.0, -0.18, 1.38, 0.12),
    ):
        sh = mesh_ico(r, (sx * abs(bone_x), 0.04, bone_z), f"Hide_shoulder{sx}", 3)
        sh.scale = (1.1, 0.95, 1.05)
        apply_scale(sh)
        parts.append(sh)
    for name, loc, r, sc in (
        ("Hide_uarmL", (0.30, 0.04, 1.18), 0.10, (1.1, 1.0, 1.4)),
        ("Hide_farmL", (0.28, 0.06, 0.96), 0.08, (1.0, 1.0, 1.3)),
        ("Hide_uarmR", (-0.26, 0.03, 1.16), 0.10, (1.1, 1.0, 1.4)),
        ("Hide_farmR", (-0.26, 0.05, 0.94), 0.08, (1.0, 1.0, 1.3)),
        ("Hide_thighL", (0.14, 0.04, 0.62), 0.12, (1.15, 1.05, 1.45)),
        ("Hide_calfL", (0.14, 0.05, 0.28), 0.09, (1.05, 1.0, 1.4)),
        ("Hide_thighR", (-0.14, 0.04, 0.62), 0.12, (1.15, 1.05, 1.45)),
        ("Hide_calfR", (-0.14, 0.05, 0.28), 0.09, (1.05, 1.0, 1.4)),
    ):
        limb = mesh_ico(r, loc, name, 3)
        limb.scale = sc
        apply_scale(limb)
        parts.append(limb)
    pec_l = mesh_ico(0.11, (0.16, 0.16, 1.28), "Hide_pecL", 3)
    pec_r = mesh_ico(0.11, (-0.06, 0.14, 1.26), "Hide_pecR", 3)
    parts += [pec_l, pec_r]
    body = join(parts, "Hide_body")
    organicize(body, voxel=0.018, disp=0.012, sub=1, collapse=0.28, noise=0.18)
    return body


def add_troll_kit(groups: dict[str, list[bpy.types.Object]]) -> None:
    groups["Head"].append(mesh_cone(0.024, 0.0, 0.12, (0.22, 0.24, 1.48), (1.15, 0.15, 0), name="Bone_tuskL", verts=8))
    groups["Head"].append(mesh_cone(0.024, 0.0, 0.12, (0.08, 0.24, 1.48), (1.15, -0.15, 0), name="Bone_tuskR", verts=8))
    groups["Head"].append(mesh_uvsphere(0.016, (0.20, 0.24, 1.66), "Eye_L", 10, 7))
    groups["Head"].append(mesh_uvsphere(0.016, (0.08, 0.24, 1.66), "Eye_R", 10, 7))
    stone = mesh_ico(0.12, (-0.04, -0.04, 1.28), "Stone_back", 3)
    organicize(stone, voxel=0.014, disp=0.01, sub=1, collapse=0.4, noise=0.2)
    groups["Spine2"].append(stone)
    groups["RightHand"] += make_held_club()


def make_humanoid(kind: str) -> None:
    reset()
    auto_mesh = None
    if kind == "cave_troll":
        groups: dict[str, list[bpy.types.Object]] = {b[0]: [] for b in humanoid_bones()}
        add_troll_kit(groups)
        auto_mesh = make_troll_flesh()
    else:
        groups = build_skeleton_parts()
        if kind == "skeleton":
            add_warrior_kit(groups)
        elif kind == "lich":
            add_lich_kit(groups)
        elif kind == "wraith":
            add_wraith_kit(groups)
    arm = add_armature(humanoid_bones(), humanoid_actions())
    arm.name = kind
    skin_groups(arm, groups)
    if auto_mesh is not None:
        triangulate(auto_mesh)
        if auto_mesh.data:
            auto_mesh.data.name = auto_mesh.name[:60]
        bind_auto(auto_mesh, arm)
    finalize_skinned(arm)
    export_glb(arm, f"monsters/{kind}.glb")


def finalize_skinned(arm: bpy.types.Object) -> None:
    for obj in list(arm.children_recursive):
        if obj.type != "MESH":
            continue
        if obj.data:
            obj.data.name = obj.name[:60]


def evaluated_aabb(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    mesh = ev.to_mesh()
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    mw = ev.matrix_world
    for v in mesh.vertices:
        w = mw @ v.co
        mins.x = min(mins.x, w.x)
        mins.y = min(mins.y, w.y)
        mins.z = min(mins.z, w.z)
        maxs.x = max(maxs.x, w.x)
        maxs.y = max(maxs.y, w.y)
        maxs.z = max(maxs.z, w.z)
    ev.to_mesh_clear()
    return mins, maxs


def _rename_action(act: bpy.types.Action, name: str) -> None:
    act.name = name
    act.use_fake_user = True


def process_wolf() -> None:
    reset()
    if not os.path.isfile(WOLF_SRC):
        raise FileNotFoundError(f"wolf source missing: {WOLF_SRC}")
    bpy.ops.import_scene.gltf(filepath=WOLF_SRC)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    wolf = next(o for o in bpy.data.objects if o.type == "MESH" and "Wolf" in o.name)
    wolf.name = "Fur_body"
    for obj in list(bpy.data.objects):
        if obj == arm or obj == wolf:
            continue
        if obj.type in ("MESH", "EMPTY"):
            bpy.data.objects.remove(obj, do_unlink=True)

    _active(arm)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    mins, maxs = evaluated_aabb(wolf)
    height = max(0.05, maxs.z - mins.z)
    factor = 0.95 / height
    arm.scale = Vector((factor, factor, factor))
    bpy.context.view_layer.update()
    _active(arm)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    mins, maxs = evaluated_aabb(wolf)
    arm.location.z -= mins.z
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    wolf.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    wanted = {
        "idle": "Idle_AnimalArmature",
        "walk": "Walk_AnimalArmature",
        "attack": "Attack_AnimalArmature",
        "hit": "Idle_HitReact_Left_AnimalArmature",
        "death": "Death_AnimalArmature",
    }
    keep: dict[str, bpy.types.Action] = {}
    for act in list(bpy.data.actions):
        for clip, needle in wanted.items():
            if needle in act.name and clip not in keep:
                keep[clip] = act
    if arm.animation_data is None:
        arm.animation_data_create()
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    arm.animation_data.action = None
    for clip, act in keep.items():
        _rename_action(act, clip)
        track = arm.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 1, act)
    for act in list(bpy.data.actions):
        if act.name not in keep:
            bpy.data.actions.remove(act)

    arm.name = "cave_wolf"
    arm.location = (0.0, 0.0, 0.0)
    arm.scale = (1.0, 1.0, 1.0)
    wolf.scale = (1.0, 1.0, 1.0)
    mins, maxs = evaluated_aabb(wolf)
    print(
        "wolf_final",
        "scale", tuple(round(s, 4) for s in arm.scale),
        "z", round(mins.z, 4), round(maxs.z, 4),
        "h", round(maxs.z - mins.z, 4),
    )
    if abs(arm.scale.x - 1.0) > 0.02:
        raise RuntimeError(f"wolf armature scale not applied: {arm.scale[:]}")
    if mins.z < -0.12 or mins.z > 0.12:
        raise RuntimeError(f"wolf not grounded: z0={mins.z:.3f}")
    if not (0.45 <= (maxs.z - mins.z) <= 1.4):
        raise RuntimeError(f"wolf height not sane: {maxs.z - mins.z:.3f}")
    export_glb(arm, "monsters/cave_wolf.glb")


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    only = os.environ.get("DD_ONLY_CREATURE", "").strip()
    makers = [
        ("skeleton", lambda: make_humanoid("skeleton")),
        ("wraith", lambda: make_humanoid("wraith")),
        ("lich", lambda: make_humanoid("lich")),
        ("cave_troll", lambda: make_humanoid("cave_troll")),
        ("cave_wolf", process_wolf),
    ]
    for name, fn in makers:
        if only and name != only:
            continue
        print("==", name)
        fn()
    print("CREATURE_GEN_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
