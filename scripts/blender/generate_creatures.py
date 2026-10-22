#!/usr/bin/env python3
"""Headless Blender: rigged, animated dungeon creatures at real-world scale.

Humanoids are original meshes with a Mixamo-style armature.
Cave wolf is Quaternius CC0 (Ultimate Animated Animal Pack), retargeted clips.
"""

from __future__ import annotations

import math
import os
import sys

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


def shade_smooth(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.shade_smooth()
    except Exception:
        pass
    obj.select_set(False)


def apply_scale(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)


def apply_all(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)


def unwrap(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    except Exception:
        bpy.ops.uv.cube_project()
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def triangulate(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    mod = obj.modifiers.new(name="Tri", type="TRIANGULATE")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def bevel(obj: bpy.types.Object, width: float = 0.004, segments: int = 2) -> None:
    if obj.type != "MESH":
        return
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def remesh(obj: bpy.types.Object, voxel: float = 0.01) -> None:
    if obj.type != "MESH":
        return
    kept = obj.name
    mod = obj.modifiers.new(name="Remesh", type="REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except Exception:
        obj.modifiers.remove(mod)
    obj.name = kept
    obj.select_set(False)


def finish_mesh(obj: bpy.types.Object, do_bevel: bool = True, width: float = 0.004) -> bpy.types.Object:
    if do_bevel:
        bevel(obj, width, 2)
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
    mod.solver = "FAST"
    mod.object = cutter
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except Exception:
        if mod.name in obj.modifiers:
            obj.modifiers.remove(mod)
    obj.select_set(False)
    bpy.data.objects.remove(cutter, do_unlink=True)


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


def long_bone(r: float, length: float, loc, rot, name: str, verts: int = 14) -> list[bpy.types.Object]:
    shaft = mesh_cone(r * 1.08, r * 0.82, length, loc, rot, name=name, verts=verts)
    orient = Euler(rot, "XYZ").to_matrix()
    half = orient @ Vector((0.0, 0.0, length * 0.5))
    center = Vector(loc)
    j1 = mesh_ico(r * 1.42, tuple(center + half), name + "J1", 2)
    j2 = mesh_ico(r * 1.28, tuple(center - half), name + "J2", 2)
    return [shaft, j1, j2]


def curve_rib(z: float, side: float, name: str, radius: float = 0.16, depth: float = 0.11) -> bpy.types.Object:
    curve_data = bpy.data.curves.new(name, type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.bevel_depth = 0.009
    curve_data.bevel_resolution = 3
    curve_data.fill_mode = "FULL"
    spline = curve_data.splines.new("NURBS")
    count = 10
    spline.points.add(count - 1)
    for i in range(count):
        t = i / (count - 1) * math.pi * 0.92
        x = side * radius * math.sin(t)
        y = depth * math.cos(t) * 0.85 + 0.02
        zz = z + 0.018 * math.sin(t)
        spline.points[i].co = (x, y, zz, 1.0)
    spline.use_endpoint_u = True
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def make_skull(loc, prefix: str = "Bone") -> list[bpy.types.Object]:
    x, y, z = loc
    cranium = mesh_ico(0.112, (x, y + 0.02, z + 0.02), f"{prefix}_skull", 3)
    cranium.scale = (0.90, 1.22, 1.08)
    apply_scale(cranium)
    brow = mesh_cube((0.16, 0.05, 0.035), (x, y + 0.09, z + 0.03), name=f"{prefix}_brow")
    zyg_l = mesh_cyl(0.012, 0.08, (x + 0.07, y + 0.06, z - 0.01), (1.2, 0.3, 0.2), verts=10, name=f"{prefix}_zygL")
    zyg_r = mesh_cyl(0.012, 0.08, (x - 0.07, y + 0.06, z - 0.01), (1.2, -0.3, -0.2), verts=10, name=f"{prefix}_zygR")
    for sx in (-1.0, 1.0):
        cutter = mesh_uvsphere(0.034, (x + sx * 0.042, y + 0.095, z + 0.01), "cut_eye", 12, 8)
        cutter.scale = (1.05, 1.35, 1.15)
        apply_scale(cutter)
        boolean_diff(cranium, cutter)
    nose_cut = mesh_cone(0.018, 0.006, 0.05, (x, y + 0.11, z - 0.03), (math.pi * 0.5, 0, 0), name="cut_nose")
    boolean_diff(cranium, nose_cut)
    remesh(cranium, 0.007)
    jaw = mesh_torus(0.055, 0.013, (x, y + 0.03, z - 0.10), (math.pi * 0.5, 0, 0), name=f"{prefix}_jaw")
    jaw.scale = (1.05, 0.7, 1.15)
    apply_scale(jaw)
    chin = mesh_cube((0.07, 0.045, 0.028), (x, y + 0.055, z - 0.125), name=f"{prefix}_chin")
    teeth = []
    for i, sx in enumerate((-0.028, -0.014, 0.0, 0.014, 0.028)):
        teeth.append(mesh_cube((0.009, 0.008, 0.016), (x + sx, y + 0.07, z - 0.108), name=f"{prefix}_tooth{i}"))
    sockets = [
        mesh_uvsphere(0.018, (x + 0.04, y + 0.08, z + 0.01), "Cavity_eye0", 10, 7),
        mesh_uvsphere(0.018, (x - 0.04, y + 0.08, z + 0.01), "Cavity_eye1", 10, 7),
        mesh_cube((0.02, 0.03, 0.024), (x, y + 0.09, z - 0.028), name="Cavity_nose"),
    ]
    return [cranium, brow, zyg_l, zyg_r, jaw, chin, *teeth, *sockets]


def make_pelvis(z: float = 0.94, prefix: str = "Bone") -> list[bpy.types.Object]:
    parts = []
    for side, sx in (("L", 1.0), ("R", -1.0)):
        wing = mesh_ico(0.09, (sx * 0.09, 0.01, z), f"{prefix}_ilium{side}", 2)
        wing.scale = (0.85, 0.55, 1.15)
        wing.rotation_euler = (0.25, sx * 0.35, sx * 0.4)
        apply_scale(wing)
        apply_all(wing)
        parts.append(wing)
    sacrum = mesh_cube((0.07, 0.055, 0.12), (0, -0.01, z + 0.02), name=f"{prefix}_sacrum")
    pubis = mesh_torus(0.05, 0.012, (0, 0.04, z - 0.05), (math.pi * 0.5, 0, 0), name=f"{prefix}_pubis")
    pubis.scale = (1.1, 0.7, 0.8)
    apply_scale(pubis)
    parts += [sacrum, pubis]
    return parts


def make_hand(side: float, loc, prefix: str = "Bone") -> list[bpy.types.Object]:
    x, y, z = loc
    tag = "L" if side > 0 else "R"
    palm = mesh_cube((0.05, 0.022, 0.07), (x, y, z), name=f"{prefix}_palm{tag}")
    parts = [palm]
    fingers = [
        (-0.018, 0.55, 3),
        (-0.006, 0.72, 3),
        (0.006, 0.68, 3),
        (0.016, 0.50, 2),
    ]
    for i, (ox, length, joints) in enumerate(fingers):
        px = x + side * ox
        pz = z - 0.04
        for j in range(joints):
            seg_len = length * 0.028
            pz = pz - seg_len * 0.55
            parts.append(mesh_cyl(0.0065 - j * 0.001, seg_len, (px, y + 0.005, pz), (0.12, 0, 0), verts=8, name=f"{prefix}_finger{tag}{i}{j}"))
            parts.append(mesh_ico(0.0075 - j * 0.001, (px, y + 0.005, pz + seg_len * 0.45), f"{prefix}_knuck{tag}{i}{j}", 1))
    thumb = mesh_cyl(0.007, 0.045, (x + side * 0.03, y + 0.015, z - 0.01), (0.6, side * 0.8, 0.2), verts=8, name=f"{prefix}_thumb{tag}")
    parts.append(thumb)
    return parts


def make_foot(side: float, loc, prefix: str = "Bone") -> list[bpy.types.Object]:
    x, y, z = loc
    tag = "L" if side > 0 else "R"
    heel = mesh_ico(0.028, (x, y - 0.01, z + 0.02), f"{prefix}_heel{tag}", 2)
    heel.scale = (0.9, 1.1, 0.7)
    apply_scale(heel)
    arch = mesh_cube((0.05, 0.12, 0.028), (x, y + 0.04, z + 0.012), name=f"{prefix}_arch{tag}")
    toes = []
    for i, ox in enumerate((-0.016, -0.005, 0.006, 0.016)):
        toes.append(mesh_cyl(0.006, 0.035, (x + ox, y + 0.10, z + 0.01), (math.pi * 0.5, 0, 0), verts=7, name=f"{prefix}_toe{tag}{i}"))
    return [heel, arch, *toes]


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
            finish_mesh(mesh, width=0.003)
            bind_mesh(mesh, arm, bone)


def build_skeleton_parts() -> dict[str, list[bpy.types.Object]]:
    groups: dict[str, list[bpy.types.Object]] = {b[0]: [] for b in humanoid_bones()}
    groups["Head"] += make_skull((0, 0.02, 1.62))
    for i in range(3):
        groups["Neck"].append(mesh_cube((0.04, 0.038, 0.028), (0, 0.01, 1.50 + i * 0.022), name=f"Bone_cerv{i}"))
    for i in range(6):
        z = 1.20 + i * 0.045
        groups["Spine1"].append(mesh_cube((0.05, 0.042, 0.032), (0, 0.01, z), name=f"Bone_thor{i}"))
        radius = 0.17 - i * 0.008
        groups["Spine1"].append(curve_rib(z + 0.01, 1.0, f"Bone_ribL{i}", radius, 0.11))
        groups["Spine1"].append(curve_rib(z + 0.01, -1.0, f"Bone_ribR{i}", radius, 0.11))
    groups["Spine1"].append(mesh_cube((0.035, 0.028, 0.22), (0, 0.09, 1.30), name="Bone_sternum"))
    for i in range(4):
        groups["Spine"].append(mesh_cube((0.048, 0.04, 0.03), (0, 0.01, 1.04 + i * 0.035), name=f"Bone_lumb{i}"))
    groups["Hips"] += make_pelvis(0.93)
    groups["LeftArm"] += long_bone(0.028, 0.28, (0.18, 0.02, 1.30), (0.12, 0.0, 0.15), "Bone_humerusL")
    groups["LeftForeArm"] += long_bone(0.022, 0.26, (0.21, 0.03, 1.04), (0.08, 0.0, 0.08), "Bone_ulnaL")
    groups["LeftHand"] += make_hand(1.0, (0.23, 0.04, 0.88))
    groups["RightArm"] += long_bone(0.028, 0.28, (-0.18, 0.02, 1.30), (0.12, 0.0, -0.15), "Bone_humerusR")
    groups["RightForeArm"] += long_bone(0.022, 0.26, (-0.21, 0.03, 1.04), (0.08, 0.0, -0.08), "Bone_ulnaR")
    groups["RightHand"] += make_hand(-1.0, (-0.23, 0.04, 0.88))
    groups["LeftUpLeg"] += long_bone(0.036, 0.40, (0.11, 0.01, 0.70), (0.06, 0, 0), "Bone_femurL")
    groups["LeftLeg"] += long_bone(0.028, 0.38, (0.12, 0.02, 0.31), (0.04, 0, 0), "Bone_tibiaL")
    groups["LeftFoot"] += make_foot(1.0, (0.12, 0.04, 0.05))
    groups["RightUpLeg"] += long_bone(0.036, 0.40, (-0.11, 0.01, 0.70), (0.06, 0, 0), "Bone_femurR")
    groups["RightLeg"] += long_bone(0.028, 0.38, (-0.12, 0.02, 0.31), (0.04, 0, 0), "Bone_tibiaR")
    groups["RightFoot"] += make_foot(-1.0, (-0.12, 0.04, 0.05))
    return groups


def add_warrior_kit(groups: dict[str, list[bpy.types.Object]]) -> None:
    groups["LeftShoulder"].append(mesh_cube((0.14, 0.08, 0.07), (0.18, 0.03, 1.46), (0.2, 0, 0.25), name="Armor_pauldronL"))
    groups["RightShoulder"].append(mesh_cube((0.14, 0.08, 0.07), (-0.18, 0.03, 1.46), (0.2, 0, -0.25), name="Armor_pauldronR"))
    groups["Hips"].append(mesh_cube((0.22, 0.07, 0.045), (0, 0.03, 0.94), name="Armor_belt"))
    groups["LeftLeg"].append(mesh_cube((0.08, 0.05, 0.14), (0.13, 0.03, 0.22), name="Armor_greaveL"))
    groups["RightLeg"].append(mesh_cube((0.08, 0.05, 0.14), (-0.13, 0.03, 0.22), name="Armor_greaveR"))
    blade = mesh_cube((0.035, 0.008, 0.72), (-0.26, 0.06, 0.55), (0.15, 0.4, -0.1), name="Sword_blade")
    guard = mesh_cube((0.14, 0.03, 0.03), (-0.24, 0.05, 0.22), (0.15, 0.4, -0.1), name="Sword_guard")
    grip = mesh_cyl(0.014, 0.11, (-0.23, 0.045, 0.14), (0.15, 0.4, -0.1), verts=10, name="Sword_grip")
    groups["RightHand"] += [blade, guard, grip]


def add_lich_kit(groups: dict[str, list[bpy.types.Object]]) -> None:
    robe = mesh_cone(0.42, 0.12, 1.05, (0, 0.02, 0.55), name="Robe_skirt", verts=18)
    cowl = mesh_cube((0.22, 0.12, 0.05), (0, 0.08, 1.52), name="Robe_cowl")
    groups["Hips"].append(robe)
    groups["Neck"].append(cowl)
    groups["Head"].append(mesh_torus(0.10, 0.014, (0, 0.02, 1.78), name="Crown_ring"))
    groups["Head"].append(mesh_cone(0.022, 0.0, 0.11, (0, 0.02, 1.90), name="Crown_spike"))
    groups["Head"].append(mesh_cone(0.016, 0.0, 0.08, (0.07, 0.02, 1.86), name="Crown_spike2"))
    groups["Head"].append(mesh_cone(0.016, 0.0, 0.08, (-0.07, 0.02, 1.86), name="Crown_spike3"))
    groups["RightHand"].append(mesh_cyl(0.018, 1.55, (-0.32, 0.08, 0.85), (0.12, 0.18, 0.05), verts=10, name="Staff_shaft"))
    groups["RightHand"].append(mesh_ico(0.065, (-0.40, 0.14, 1.58), "Glow_orb", 2))
    groups["Hips"].append(mesh_cube((0.18, 0.06, 0.04), (0, 0.04, 0.96), name="Armor_belt"))


def add_wraith_kit(groups: dict[str, list[bpy.types.Object]]) -> None:
    robe = mesh_cone(0.48, 0.08, 1.38, (0, 0.02, 0.72), name="Robe_body", verts=18)
    hood = mesh_ico(0.16, (0, 0.04, 1.58), "Hood_cowl", 2)
    hood.scale = (1.05, 1.25, 0.9)
    apply_scale(hood)
    groups["Hips"].append(robe)
    groups["Head"].append(hood)
    groups["LeftArm"].append(mesh_cone(0.09, 0.03, 0.52, (0.28, 0.04, 1.12), (0, 0, 0.9), name="Robe_sleeveL"))
    groups["RightArm"].append(mesh_cone(0.09, 0.03, 0.52, (-0.28, 0.04, 1.12), (0, 0, -0.9), name="Robe_sleeveR"))
    for i, x in enumerate((-0.16, -0.05, 0.06, 0.16)):
        groups["Hips"].append(mesh_cube((0.07, 0.02, 0.38), (x, 0.04, 0.18), (0.12 * (i - 1.5), 0, 0.08), name=f"Tatter_{i}"))
    groups["Head"].append(mesh_uvsphere(0.016, (0.035, 0.11, 1.64), "Glow_eyeL", 8, 6))
    groups["Head"].append(mesh_uvsphere(0.016, (-0.035, 0.11, 1.64), "Glow_eyeR", 8, 6))


def add_troll_kit(groups: dict[str, list[bpy.types.Object]]) -> None:
    torso = mesh_ico(0.32, (0.04, 0.08, 1.22), "Hide_torso", 2)
    torso.scale = (1.25, 0.95, 1.2)
    apply_scale(torso)
    belly = mesh_ico(0.28, (0.08, 0.12, 0.88), "Hide_belly", 2)
    belly.scale = (1.2, 1.0, 1.05)
    apply_scale(belly)
    head = mesh_ico(0.18, (0.14, 0.16, 1.62), "Hide_head", 2)
    head.scale = (1.15, 1.0, 1.05)
    apply_scale(head)
    groups["Spine1"] += [torso, belly]
    groups["Head"] += [head, mesh_cube((0.18, 0.05, 0.04), (0.18, 0.22, 1.70), name="Hide_brow")]
    groups["Head"].append(mesh_cube((0.16, 0.10, 0.06), (0.18, 0.18, 1.50), name="Hide_jaw"))
    groups["Head"].append(mesh_cone(0.025, 0.0, 0.11, (0.22, 0.22, 1.48), (1.15, 0, 0), name="Bone_tuskL"))
    groups["Head"].append(mesh_cone(0.025, 0.0, 0.11, (0.10, 0.22, 1.48), (1.15, 0, 0), name="Bone_tuskR"))
    groups["Head"].append(mesh_uvsphere(0.018, (0.20, 0.24, 1.66), "Eye_L", 8, 6))
    groups["Head"].append(mesh_uvsphere(0.018, (0.10, 0.24, 1.66), "Eye_R", 8, 6))
    groups["Spine2"].append(mesh_ico(0.14, (-0.06, -0.02, 1.28), "Stone_back", 2))
    groups["LeftShoulder"].append(mesh_ico(0.11, (0.22, 0.02, 1.40), "Stone_shoulder", 2))
    groups["RightHand"].append(mesh_cyl(0.055, 1.05, (0.42, 0.12, 0.70), (0.35, 0.25, 0.1), verts=10, name="Club_shaft"))
    groups["RightHand"].append(mesh_ico(0.14, (0.62, 0.22, 1.15), "Club_head", 2))


def thicken_troll_limbs(groups: dict[str, list[bpy.types.Object]]) -> None:
    for bone in ("LeftArm", "RightArm", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"):
        for obj in groups.get(bone, []):
            obj.scale = (1.55, 1.55, 1.15)
            apply_scale(obj)


def make_humanoid(kind: str) -> None:
    reset()
    groups = build_skeleton_parts()
    if kind == "skeleton":
        add_warrior_kit(groups)
    elif kind == "lich":
        add_lich_kit(groups)
    elif kind == "wraith":
        add_wraith_kit(groups)
    elif kind == "cave_troll":
        add_troll_kit(groups)
        thicken_troll_limbs(groups)
    arm = add_armature(humanoid_bones(), humanoid_actions())
    arm.name = kind
    skin_groups(arm, groups)
    export_glb(arm, f"monsters/{kind}.glb")


def _delete_strays() -> None:
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.name.startswith("Icosphere") and obj.parent is None:
            bpy.data.objects.remove(obj, do_unlink=True)


def _world_aabb(objs: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    for obj in objs:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            mins.x = min(mins.x, w.x)
            mins.y = min(mins.y, w.y)
            mins.z = min(mins.z, w.z)
            maxs.x = max(maxs.x, w.x)
            maxs.y = max(maxs.y, w.y)
            maxs.z = max(maxs.z, w.z)
    return mins, maxs


def _rename_action(act: bpy.types.Action, name: str) -> None:
    act.name = name
    act.use_fake_user = True


def process_wolf() -> None:
    reset()
    if not os.path.isfile(WOLF_SRC):
        raise FileNotFoundError(f"wolf source missing: {WOLF_SRC}")
    bpy.ops.import_scene.gltf(filepath=WOLF_SRC)
    _delete_strays()
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    wolf = next(o for o in bpy.data.objects if o.type == "MESH" and "Wolf" in o.name)
    wolf.name = "Fur_body"
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj != wolf:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.update()
    mins, maxs = _world_aabb([wolf])
    height = max(0.01, maxs.z - mins.z)
    scale = 0.95 / height
    arm.scale = arm.scale * scale
    bpy.context.view_layer.update()
    mins, maxs = _world_aabb([wolf])
    arm.location.z -= mins.z
    bpy.context.view_layer.update()
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
    export_glb(arm, "monsters/cave_wolf.glb")


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    makers = [
        ("skeleton", lambda: make_humanoid("skeleton")),
        ("wraith", lambda: make_humanoid("wraith")),
        ("lich", lambda: make_humanoid("lich")),
        ("cave_troll", lambda: make_humanoid("cave_troll")),
        ("cave_wolf", process_wolf),
    ]
    for name, fn in makers:
        print("==", name)
        fn()
    print("CREATURE_GEN_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
