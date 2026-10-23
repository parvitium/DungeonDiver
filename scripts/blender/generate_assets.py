#!/usr/bin/env python3
"""Headless Blender generator for DungeonDiver kit, props, weapons, and creatures."""

from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Euler, Vector

OUT = os.environ.get("DD_MESH_OUT", os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "meshes")))


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.engine = "CYCLES"


def shade_smooth(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.shade_smooth()
    except Exception:
        pass
    obj.select_set(False)


def bevel(obj: bpy.types.Object, width: float = 0.012, segments: int = 2) -> None:
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


def join(objects: list[bpy.types.Object], name: str) -> bpy.types.Object:
    objects = [o for o in objects if o is not None]
    if not objects:
        raise RuntimeError("join empty")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    objects[0].name = name
    return objects[0]


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


def mesh_uvsphere(r, loc=(0, 0, 0), name="Sphere", segments=16, rings=10) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=segments, ring_count=rings)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def mesh_cone(r1, r2, depth, loc=(0, 0, 0), rot=(0, 0, 0), name="Cone") -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=14)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def mesh_torus(major, minor, loc=(0, 0, 0), rot=(0, 0, 0), name="Torus") -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def apply_scale(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)


def export_glb(obj: bpy.types.Object, rel: str) -> None:
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
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
    )
    print("exported", path)


def triangulate(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    mod = obj.modifiers.new(name="Tri", type="TRIANGULATE")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def finish_mesh(obj: bpy.types.Object, do_bevel: bool = True, width: float = 0.01) -> bpy.types.Object:
    if do_bevel:
        bevel(obj, width, 2)
    triangulate(obj)
    shade_smooth(obj)
    unwrap(obj)
    return obj


def add_simple_armature(meshes: list[bpy.types.Object], bones: list[tuple], actions: dict) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = "Armature"
    eb = arm.data.edit_bones
    root = eb[0]
    root.name = bones[0][0]
    root.head = Vector(bones[0][1])
    root.tail = Vector(bones[0][2])
    created = {root.name: root}
    for name, head, tail, parent in bones[1:]:
        bone = eb.new(name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        if parent in created:
            bone.parent = created[parent]
        created[name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for mesh in meshes:
        mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    arm.animation_data_create()
    for clip, keys in actions.items():
        act = bpy.data.actions.new(name=clip)
        arm.animation_data.action = act
        for bone_name, frames in keys.items():
            pb = arm.pose.bones.get(bone_name)
            if pb is None:
                continue
            for frame, euler in frames:
                bpy.context.scene.frame_set(frame)
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = euler
                pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        act.use_fake_user = True
    bpy.context.scene.frame_set(1)
    return arm


def long_bone(r: float, length: float, loc, rot, name: str) -> list[bpy.types.Object]:
    shaft = mesh_cyl(r, length, loc, rot, verts=8, name=name)
    orient = Euler(rot, "XYZ").to_matrix()
    half = orient @ Vector((0.0, 0.0, length * 0.5))
    center = Vector(loc)
    j1 = mesh_uvsphere(r * 1.38, tuple(center + half), name + "J1", 8, 6)
    j2 = mesh_uvsphere(r * 1.28, tuple(center - half), name + "J2", 8, 6)
    return [shaft, j1, j2]


def curve_rib(z: float, side: float, name: str, radius: float = 0.15, depth: float = 0.085) -> bpy.types.Object:
    curve_data = bpy.data.curves.new(name, type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.bevel_depth = 0.010
    curve_data.bevel_resolution = 1
    curve_data.fill_mode = "FULL"
    spline = curve_data.splines.new("POLY")
    count = 8
    spline.points.add(count - 1)
    for i in range(count):
        t = i / (count - 1) * math.pi
        x = side * radius * math.sin(t)
        y = depth * math.cos(t)
        zz = z + 0.012 * math.sin(t)
        spline.points[i].co = (x, y, zz, 1.0)
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def make_skull(loc, prefix: str = "Bone") -> list[bpy.types.Object]:
    x, y, z = loc
    skull = mesh_uvsphere(0.105, (x, y + 0.01, z), f"{prefix}_skull", 16, 12)
    skull.scale = (0.95, 1.16, 1.08)
    apply_scale(skull)
    jaw = mesh_cube((0.13, 0.09, 0.05), (x, y + 0.03, z - 0.12), name=f"{prefix}_jaw")
    teeth = []
    for i, sx in enumerate((-0.035, -0.012, 0.012, 0.035)):
        teeth.append(mesh_cube((0.012, 0.012, 0.018), (x + sx, y + 0.07, z - 0.145), name=f"{prefix}_tooth{i}"))
    sockets = []
    for i, sx in enumerate((-1.0, 1.0)):
        sockets.append(mesh_uvsphere(0.028, (x + sx * 0.038, y + 0.08, z + 0.012), f"Cavity_eye{i}", 8, 6))
    sockets.append(mesh_cube((0.024, 0.04, 0.03), (x, y + 0.09, z - 0.03), name="Cavity_nose"))
    return [skull, jaw, *teeth, *sockets]


def creature_actions() -> dict:
    idle = {
        "spine": [(1, (0, 0, 0)), (20, (0.06, 0, 0)), (40, (0, 0, 0))],
        "head": [(1, (0, 0, 0)), (20, (0.08, 0.04, 0)), (40, (0, 0, 0))],
    }
    walk = {
        "Larm": [(1, (0.5, 0, 0)), (10, (-0.5, 0, 0)), (20, (0.5, 0, 0))],
        "Rarm": [(1, (-0.5, 0, 0)), (10, (0.5, 0, 0)), (20, (-0.5, 0, 0))],
        "Lleg": [(1, (-0.45, 0, 0)), (10, (0.45, 0, 0)), (20, (-0.45, 0, 0))],
        "Rleg": [(1, (0.45, 0, 0)), (10, (-0.45, 0, 0)), (20, (0.45, 0, 0))],
        "spine": [(1, (0, 0, 0)), (10, (0.08, 0, 0)), (20, (0, 0, 0))],
    }
    attack = {
        "Rarm": [(1, (0, 0, 0)), (8, (-1.4, 0.2, 0.4)), (16, (0.3, 0, 0))],
        "spine": [(1, (0, 0, 0)), (8, (0.2, 0, 0.15)), (16, (0, 0, 0))],
    }
    death = {
        "spine": [(1, (0, 0, 0)), (18, (1.3, 0, 0))],
        "head": [(1, (0, 0, 0)), (18, (0.6, 0, 0))],
    }
    return {"idle": idle, "walk": walk, "attack": attack, "death": death}


def bones_humanoid() -> list:
    return [
        ("root", (0, 0, 0.05), (0, 0, 0.2)),
        ("spine", (0, 0, 0.2), (0, 0, 0.95), "root"),
        ("head", (0, 0, 0.95), (0, 0, 1.35), "spine"),
        ("Larm", (0.18, 0, 0.9), (0.18, 0, 0.45), "spine"),
        ("Rarm", (-0.18, 0, 0.9), (-0.18, 0, 0.45), "spine"),
        ("Lleg", (0.1, 0, 0.2), (0.1, 0, 0.02), "root"),
        ("Rleg", (-0.1, 0, 0.2), (-0.1, 0, 0.02), "root"),
    ]


def make_pillar() -> None:
    reset()
    base = mesh_cube((0.58, 0.58, 0.2), (0, 0, 0.1), name="Base")
    shaft = mesh_cyl(0.16, 3.55, (0, 0, 2.0), verts=12, name="Shaft")
    flute = mesh_cyl(0.175, 3.2, (0, 0, 2.0), verts=12, name="Flute")
    cap = mesh_cube((0.52, 0.52, 0.16), (0, 0, 3.92), name="Cap")
    neck = mesh_cyl(0.2, 0.18, (0, 0, 3.72), verts=12, name="Neck")
    obj = join([base, shaft, flute, cap, neck], "pillar")
    finish_mesh(obj, width=0.016)
    export_glb(obj, "kit/pillar.glb")


def make_arch() -> None:
    reset()
    parts = []
    for i in range(-5, 6):
        t = i / 5.0
        ang = math.pi * 0.5 * t
        x = math.sin(ang) * 1.48
        z = 2.58 + math.cos(ang) * 0.58
        block = mesh_cube((0.36, 0.44, 0.26), (x, 0, z), (0, 0, -ang * 0.35), name=f"V{i}")
        parts.append(block)
    left = mesh_cube((0.24, 0.44, 2.45), (-1.52, 0, 1.22), name="L")
    right = mesh_cube((0.24, 0.44, 2.45), (1.52, 0, 1.22), name="R")
    obj = join(parts + [left, right], "arch")
    finish_mesh(obj, width=0.014)
    export_glb(obj, "kit/arch.glb")


def make_beam() -> None:
    reset()
    beam = mesh_cube((13.2, 0.2, 0.18), (0, 0, 0), name="beam")
    iron = mesh_cube((0.28, 0.26, 0.22), (-5.8, 0, 0), name="BandL")
    iron2 = mesh_cube((0.28, 0.26, 0.22), (5.8, 0, 0), name="BandR")
    obj = join([beam, iron, iron2], "beam")
    finish_mesh(obj)
    export_glb(obj, "kit/beam.glb")


def make_torch() -> None:
    reset()
    plate = mesh_cube((0.16, 0.05, 0.22), (0, 0.0, 0.05), name="Plate")
    arm = mesh_cube((0.05, 0.05, 0.22), (0, 0.12, 0.12), (0.6, 0, 0), name="Arm")
    shaft = mesh_cyl(0.03, 0.5, (0, 0.28, 0.18), verts=10, name="Shaft")
    bowl = mesh_cyl(0.07, 0.07, (0, 0.54, 0.18), verts=12, name="Bowl")
    wrap = mesh_cyl(0.045, 0.12, (0, 0.42, 0.18), verts=10, name="Wrap")
    flame = mesh_cone(0.05, 0.01, 0.16, (0, 0.66, 0.18), name="Flame")
    obj = join([plate, arm, shaft, bowl, wrap, flame], "torch")
    finish_mesh(obj)
    export_glb(obj, "props/torch.glb")


def make_barrel() -> None:
    reset()
    body = mesh_cyl(0.32, 0.7, (0, 0, 0.36), verts=16, name="Body")
    top = mesh_cyl(0.30, 0.04, (0, 0, 0.72), verts=16, name="Lid")
    bot = mesh_cyl(0.30, 0.04, (0, 0, 0.02), verts=16, name="Bot")
    rings = [mesh_cyl(0.335, 0.04, (0, 0, z), verts=16, name=f"Hoop{i}") for i, z in enumerate((0.16, 0.36, 0.56))]
    obj = join([body, top, bot] + rings, "barrel")
    finish_mesh(obj)
    export_glb(obj, "props/barrel.glb")


def make_chest() -> None:
    reset()
    box = mesh_cube((0.95, 0.62, 0.5), (0, 0, 0.28), name="Box")
    lid = mesh_cube((0.97, 0.64, 0.14), (0, 0, 0.58), name="Lid")
    band1 = mesh_cube((0.99, 0.08, 0.54), (0, 0, 0.18), name="Band1")
    band2 = mesh_cube((0.99, 0.08, 0.54), (0, 0, 0.42), name="Band2")
    lock = mesh_cube((0.12, 0.08, 0.16), (0, 0.34, 0.36), name="Lock")
    obj = join([box, lid, band1, band2, lock], "chest")
    finish_mesh(obj)
    export_glb(obj, "props/chest.glb")


def make_chain() -> None:
    reset()
    links = []
    for i in range(7):
        rot = (math.pi * 0.5 * (i % 2), 0, 0.15)
        links.append(mesh_torus(0.07, 0.018, (0, 0, 0.08 + i * 0.13), rot, name=f"L{i}"))
    obj = join(links, "chain")
    finish_mesh(obj, do_bevel=False)
    export_glb(obj, "props/chain.glb")


def make_bones() -> None:
    reset()
    parts = make_skull((0, 0, 0.22), "Bone")
    f1 = mesh_cyl(0.03, 0.48, (0.16, 0.05, 0.08), (0, 1.1, 0.4), verts=8, name="Bone_f1")
    f2 = mesh_cyl(0.028, 0.42, (-0.14, -0.04, 0.1), (0.3, -0.8, 0.2), verts=8, name="Bone_f2")
    obj = join(parts + [f1, f2], "bones")
    finish_mesh(obj)
    export_glb(obj, "props/bones.glb")


def make_sword() -> None:
    reset()
    blade = mesh_cube((0.055, 0.008, 0.78), (0, 0, 0.58), name="Blade")
    tip = mesh_cone(0.028, 0.001, 0.11, (0, 0, 1.02), name="Tip")
    fuller = mesh_cube((0.012, 0.01, 0.62), (0, 0, 0.55), name="Fuller")
    guard = mesh_cube((0.24, 0.035, 0.035), (0, 0, 0.17), name="Guard")
    grip = mesh_cyl(0.018, 0.13, (0, 0, 0.08), verts=10, name="Grip")
    pommel = mesh_uvsphere(0.028, (0, 0, -0.01), name="Pommel", segments=10, rings=6)
    obj = join([blade, tip, fuller, guard, grip, pommel], "sword")
    finish_mesh(obj, width=0.006)
    export_glb(obj, "weapons/sword.glb")


def make_shield() -> None:
    reset()
    body = mesh_cube((0.42, 0.08, 0.56), (0, 0, 0), name="Body")
    rim = mesh_cube((0.46, 0.04, 0.6), (0, 0, 0), name="Rim")
    boss = mesh_uvsphere(0.07, (0, 0.05, 0.04), name="Boss", segments=12, rings=8)
    strap = mesh_cube((0.08, 0.03, 0.22), (0, -0.05, 0), name="Strap")
    obj = join([body, rim, boss, strap], "shield")
    finish_mesh(obj)
    export_glb(obj, "weapons/shield.glb")


def make_skeleton() -> None:
    reset()
    bone_parts: list[bpy.types.Object] = []
    extras: list[bpy.types.Object] = []
    bone_parts += make_skull((0, 0.02, 1.58))
    for i in range(9):
        z = 0.98 + i * 0.055
        bone_parts.append(mesh_cube((0.055, 0.045, 0.04), (0, 0.01, z), name=f"Bone_vert{i}"))
    for i in range(7):
        z = 1.08 + i * 0.055
        radius = 0.16 - i * 0.008
        bone_parts.append(curve_rib(z, 1.0, f"Bone_ribL{i}", radius, 0.09))
        bone_parts.append(curve_rib(z, -1.0, f"Bone_ribR{i}", radius, 0.09))
    sternum = mesh_cube((0.04, 0.03, 0.28), (0, 0.09, 1.22), name="Bone_sternum")
    bone_parts.append(sternum)
    pelvis_l = mesh_cube((0.13, 0.08, 0.1), (0.1, 0.01, 0.9), (0.15, 0, 0.25), name="Bone_pelvisL")
    pelvis_r = mesh_cube((0.13, 0.08, 0.1), (-0.1, 0.01, 0.9), (-0.15, 0, -0.25), name="Bone_pelvisR")
    sacrum = mesh_cube((0.08, 0.06, 0.1), (0, 0.0, 0.92), name="Bone_sacrum")
    bone_parts += [pelvis_l, pelvis_r, sacrum]
    bone_parts += long_bone(0.032, 0.30, (0.22, 0.02, 1.38), (0.15, 0.0, 0.9), "Bone_humerusL")
    bone_parts += long_bone(0.026, 0.28, (0.28, 0.03, 1.08), (0.05, 0.0, 0.15), "Bone_ulnaL")
    bone_parts += long_bone(0.032, 0.30, (-0.22, 0.02, 1.38), (0.15, 0.0, -0.9), "Bone_humerusR")
    bone_parts += long_bone(0.026, 0.28, (-0.30, 0.04, 1.10), (0.1, 0.15, -0.2), "Bone_ulnaR")
    bone_parts += long_bone(0.038, 0.38, (0.11, 0.01, 0.68), (0.08, 0, 0), "Bone_femurL")
    bone_parts += long_bone(0.032, 0.36, (0.12, 0.02, 0.30), (0.04, 0, 0), "Bone_tibiaL")
    bone_parts += long_bone(0.038, 0.38, (-0.11, 0.01, 0.68), (0.08, 0, 0), "Bone_femurR")
    bone_parts += long_bone(0.032, 0.36, (-0.12, 0.02, 0.30), (0.04, 0, 0), "Bone_tibiaR")
    bone_parts.append(mesh_cube((0.12, 0.06, 0.04), (0.13, 0.05, 0.06), name="Bone_footL"))
    bone_parts.append(mesh_cube((0.12, 0.06, 0.04), (-0.13, 0.05, 0.06), name="Bone_footR"))
    for i, sx in enumerate((-0.03, 0.0, 0.03, 0.055)):
        bone_parts.append(mesh_cyl(0.008, 0.07, (0.34 + sx * 0.4, 0.04, 0.94), (0.2, 0, 0.4), verts=6, name=f"Bone_fingerL{i}"))
        bone_parts.append(mesh_cyl(0.008, 0.07, (-0.42 + sx * 0.3, 0.08, 0.96), (0.3, 0.2, -0.3), verts=6, name=f"Bone_fingerR{i}"))
    extras.append(mesh_cube((0.18, 0.1, 0.08), (0.24, 0.04, 1.46), (0.2, 0, 0.3), name="Armor_pauldron"))
    extras.append(mesh_cube((0.22, 0.06, 0.05), (0, 0.04, 0.94), name="Armor_belt"))
    extras.append(mesh_cube((0.1, 0.05, 0.16), (0.13, 0.03, 0.22), name="Armor_greaveL"))
    blade = mesh_cube((0.04, 0.008, 0.62), (-0.48, 0.12, 0.85), (0.2, 0.35, -0.15), name="Sword_blade")
    guard = mesh_cube((0.14, 0.03, 0.03), (-0.42, 0.08, 0.58), (0.2, 0.35, -0.15), name="Sword_guard")
    extras += [blade, guard]
    body = join(bone_parts, "Bone_body")
    finish_mesh(body, width=0.006)
    for extra in extras:
        finish_mesh(extra, width=0.008)
    arm = add_simple_armature([body] + extras, bones_humanoid(), creature_actions())
    arm.name = "skeleton"
    export_glb(arm, "monsters/skeleton.glb")


def make_wolf() -> None:
    reset()
    fur: list[bpy.types.Object] = []
    extras: list[bpy.types.Object] = []
    chest = mesh_uvsphere(0.22, (0.22, 0, 0.48), "Fur_chest", 14, 10)
    chest.scale = (1.15, 0.85, 0.95)
    apply_scale(chest)
    belly = mesh_uvsphere(0.18, (-0.08, 0, 0.42), "Fur_belly", 12, 8)
    belly.scale = (1.35, 0.75, 0.8)
    apply_scale(belly)
    neck = mesh_cyl(0.09, 0.18, (0.42, 0, 0.54), (0, 1.1, 0), verts=10, name="Fur_neck")
    head = mesh_uvsphere(0.13, (0.58, 0.02, 0.58), "Fur_head", 12, 8)
    head.scale = (1.15, 0.85, 0.9)
    apply_scale(head)
    snout = mesh_cone(0.07, 0.03, 0.16, (0.74, 0.02, 0.52), (0, math.pi * 0.5, 0), name="Fur_snout")
    jaw = mesh_cube((0.12, 0.06, 0.04), (0.70, 0.02, 0.46), name="Fur_jaw")
    ear_l = mesh_cone(0.04, 0.0, 0.11, (0.54, 0.07, 0.70), (0.45, 0, 0), name="Fur_earL")
    ear_r = mesh_cone(0.04, 0.0, 0.11, (0.54, -0.07, 0.70), (-0.45, 0, 0), name="Fur_earR")
    tail = mesh_cone(0.05, 0.015, 0.42, (-0.38, 0, 0.50), (0, -1.15, 0), name="Fur_tail")
    ruff = mesh_uvsphere(0.12, (0.36, 0, 0.56), "Fur_ruff", 10, 7)
    fur += [chest, belly, neck, head, snout, jaw, ear_l, ear_r, tail, ruff]
    for i, (x, y) in enumerate(((0.30, 0.11), (0.30, -0.11), (-0.16, 0.11), (-0.16, -0.11))):
        fur += long_bone(0.04, 0.22, (x, y, 0.32), (0.15 if i < 2 else 0.05, 0, 0), f"Fur_uleg{i}")
        fur += long_bone(0.032, 0.18, (x + (0.02 if i < 2 else -0.02), y, 0.14), (0.05, 0, 0), f"Fur_lleg{i}")
        fur.append(mesh_cube((0.09, 0.05, 0.035), (x, y, 0.03), name=f"Fur_paw{i}"))
    extras.append(mesh_uvsphere(0.018, (0.64, 0.05, 0.62), "Eye_L", 8, 6))
    extras.append(mesh_uvsphere(0.018, (0.64, -0.05, 0.62), "Eye_R", 8, 6))
    extras.append(mesh_cube((0.03, 0.02, 0.02), (0.80, 0.02, 0.50), name="Bone_fang"))
    body = join(fur, "Fur_body")
    finish_mesh(body, width=0.008)
    for extra in extras:
        finish_mesh(extra, do_bevel=False)
    bones = [
        ("root", (0, 0, 0.12), (0, 0, 0.32)),
        ("spine", (0, 0, 0.32), (0.28, 0, 0.5), "root"),
        ("head", (0.28, 0, 0.5), (0.7, 0, 0.58), "spine"),
        ("Larm", (0.3, 0.11, 0.32), (0.3, 0.11, 0.04), "spine"),
        ("Rarm", (0.3, -0.11, 0.32), (0.3, -0.11, 0.04), "spine"),
        ("Lleg", (-0.16, 0.11, 0.28), (-0.16, 0.11, 0.04), "root"),
        ("Rleg", (-0.16, -0.11, 0.28), (-0.16, -0.11, 0.04), "root"),
    ]
    arm = add_simple_armature([body] + extras, bones, creature_actions())
    arm.name = "cave_wolf"
    export_glb(arm, "monsters/cave_wolf.glb")


def make_wraith() -> None:
    reset()
    robe = mesh_cone(0.46, 0.1, 1.42, (0, 0, 0.72), name="Robe_body")
    hood = mesh_uvsphere(0.2, (0, 0.02, 1.48), "Hood_cowl", 14, 9)
    hood.scale = (1.05, 1.2, 0.85)
    apply_scale(hood)
    sleeve_l = mesh_cone(0.11, 0.04, 0.58, (0.32, 0.06, 1.08), (0, 0, 1.05), name="Robe_sleeveL")
    sleeve_r = mesh_cone(0.11, 0.04, 0.58, (-0.32, 0.06, 1.08), (0, 0, -1.05), name="Robe_sleeveR")
    tatters = []
    for i, x in enumerate((-0.18, -0.05, 0.08, 0.2)):
        tatters.append(mesh_cube((0.08, 0.03, 0.35), (x, 0.05, 0.18), (0.15 * (i - 1), 0, 0.1), name=f"Tatter_{i}"))
    robe_obj = join([robe, hood, sleeve_l, sleeve_r] + tatters, "Robe_body")
    extras = make_skull((0, 0.04, 1.46))
    extras.append(mesh_uvsphere(0.02, (0.04, 0.12, 1.48), "Glow_eyeL", 8, 6))
    extras.append(mesh_uvsphere(0.02, (-0.04, 0.12, 1.48), "Glow_eyeR", 8, 6))
    extras += long_bone(0.018, 0.34, (0.42, 0.08, 0.88), (0.2, 0, 0.9), "Bone_armL")
    extras += long_bone(0.018, 0.34, (-0.42, 0.08, 0.88), (0.2, 0, -0.9), "Bone_armR")
    finish_mesh(robe_obj, width=0.012)
    bone_join = [e for e in extras if e.name.startswith("Bone") or e.name.startswith("Cavity")]
    glow = [e for e in extras if e.name.startswith("Glow")]
    body_bones = join(bone_join, "Bone_body") if bone_join else extras[0]
    finish_mesh(body_bones, width=0.005)
    for g in glow:
        finish_mesh(g, do_bevel=False)
    arm = add_simple_armature([robe_obj, body_bones] + glow, bones_humanoid(), creature_actions())
    arm.name = "wraith"
    export_glb(arm, "monsters/wraith.glb")


def make_lich() -> None:
    reset()
    bone_parts: list[bpy.types.Object] = []
    extras: list[bpy.types.Object] = []
    bone_parts += make_skull((0, 0.02, 1.68))
    for i in range(8):
        bone_parts.append(mesh_cube((0.05, 0.04, 0.04), (0, 0.01, 1.05 + i * 0.06), name=f"Bone_vert{i}"))
    for i in range(6):
        z = 1.15 + i * 0.055
        bone_parts.append(curve_rib(z, 1.0, f"Bone_ribL{i}", 0.15 - i * 0.008, 0.08))
        bone_parts.append(curve_rib(z, -1.0, f"Bone_ribR{i}", 0.15 - i * 0.008, 0.08))
    bone_parts += long_bone(0.03, 0.32, (0.22, 0.02, 1.42), (0.2, 0, 0.8), "Bone_armL")
    bone_parts += long_bone(0.03, 0.32, (-0.22, 0.02, 1.42), (0.2, 0, -0.8), "Bone_armR")
    pelvis = mesh_cube((0.2, 0.1, 0.08), (0, 0, 0.98), name="Bone_pelvis")
    bone_parts.append(pelvis)
    robe = mesh_cone(0.5, 0.14, 1.15, (0, 0, 0.62), name="Robe_skirt")
    cowl = mesh_cube((0.28, 0.16, 0.06), (0, 0.08, 1.52), name="Robe_cowl")
    extras += [robe, cowl]
    extras.append(mesh_torus(0.11, 0.018, (0, 0, 1.80), name="Crown_ring"))
    extras.append(mesh_cone(0.025, 0.0, 0.12, (0, 0, 1.92), name="Crown_spike"))
    extras.append(mesh_cone(0.02, 0.0, 0.09, (0.08, 0, 1.88), name="Crown_spike2"))
    extras.append(mesh_cone(0.02, 0.0, 0.09, (-0.08, 0, 1.88), name="Crown_spike3"))
    extras.append(mesh_cyl(0.022, 1.65, (-0.42, 0.12, 0.92), (0.18, 0, 0.15), verts=8, name="Staff_shaft"))
    extras.append(mesh_uvsphere(0.07, (-0.52, 0.18, 1.72), "Glow_orb", 10, 7))
    extras.append(mesh_cube((0.16, 0.08, 0.05), (0, 0.04, 1.02), name="Armor_belt"))
    body = join(bone_parts, "Bone_body")
    finish_mesh(body, width=0.006)
    for extra in extras:
        finish_mesh(extra, width=0.008)
    arm = add_simple_armature([body] + extras, bones_humanoid(), creature_actions())
    arm.name = "lich"
    export_glb(arm, "monsters/lich.glb")


def make_troll() -> None:
    reset()
    hide: list[bpy.types.Object] = []
    extras: list[bpy.types.Object] = []
    torso = mesh_uvsphere(0.38, (0.04, 0.06, 1.18), "Hide_torso", 14, 10)
    torso.scale = (1.2, 0.9, 1.15)
    apply_scale(torso)
    belly = mesh_uvsphere(0.34, (0.08, 0.1, 0.82), "Hide_belly", 12, 8)
    belly.scale = (1.15, 0.95, 1.05)
    apply_scale(belly)
    head = mesh_uvsphere(0.2, (0.16, 0.14, 1.68), "Hide_head", 12, 8)
    head.scale = (1.1, 0.95, 1.05)
    apply_scale(head)
    brow = mesh_cube((0.2, 0.06, 0.05), (0.22, 0.2, 1.76), name="Hide_brow")
    jaw = mesh_cube((0.18, 0.12, 0.07), (0.22, 0.16, 1.56), name="Hide_jaw")
    hide += [torso, belly, head, brow, jaw]
    hide += long_bone(0.1, 0.62, (0.52, 0.08, 1.0), (0.25, 0, 0.35), "Hide_armL")
    hide += long_bone(0.1, 0.62, (-0.48, 0.06, 1.02), (0.2, 0, -0.45), "Hide_armR")
    hide += long_bone(0.11, 0.58, (0.18, 0.05, 0.42), (0.08, 0, 0), "Hide_legL")
    hide += long_bone(0.11, 0.58, (-0.16, 0.04, 0.42), (0.08, 0, 0), "Hide_legR")
    hide.append(mesh_cube((0.18, 0.1, 0.06), (0.2, 0.1, 0.08), name="Hide_footL"))
    hide.append(mesh_cube((0.18, 0.1, 0.06), (-0.16, 0.08, 0.08), name="Hide_footR"))
    extras.append(mesh_cone(0.03, 0.0, 0.12, (0.28, 0.2, 1.58), (1.1, 0, 0), name="Bone_tuskL"))
    extras.append(mesh_cone(0.03, 0.0, 0.12, (0.16, 0.2, 1.58), (1.1, 0, 0), name="Bone_tuskR"))
    extras.append(mesh_uvsphere(0.16, (0.08, 0.02, 0.95), "Stone_back", 8, 6))
    extras.append(mesh_uvsphere(0.12, (-0.1, -0.02, 1.22), "Stone_shoulder", 8, 6))
    extras.append(mesh_cyl(0.06, 1.15, (0.72, 0.16, 0.7), (0.4, 0.2, 0.15), verts=8, name="Club_shaft"))
    extras.append(mesh_uvsphere(0.16, (0.92, 0.28, 1.18), "Club_head", 10, 7))
    extras.append(mesh_uvsphere(0.022, (0.24, 0.22, 1.72), "Eye_L", 8, 6))
    extras.append(mesh_uvsphere(0.022, (0.12, 0.22, 1.72), "Eye_R", 8, 6))
    body = join(hide, "Hide_body")
    finish_mesh(body, width=0.012)
    for extra in extras:
        finish_mesh(extra, width=0.01)
    bones = [
        ("root", (0, 0, 0.1), (0, 0, 0.4)),
        ("spine", (0, 0, 0.4), (0, 0, 1.2), "root"),
        ("head", (0, 0, 1.2), (0.14, 0.12, 1.72), "spine"),
        ("Larm", (0.4, 0, 1.28), (0.55, 0, 0.7), "spine"),
        ("Rarm", (-0.4, 0, 1.28), (-0.5, 0, 0.7), "spine"),
        ("Lleg", (0.18, 0, 0.4), (0.18, 0, 0.05), "root"),
        ("Rleg", (-0.16, 0, 0.4), (-0.16, 0, 0.05), "root"),
    ]
    arm = add_simple_armature([body] + extras, bones, creature_actions())
    arm.name = "cave_troll"
    export_glb(arm, "monsters/cave_troll.glb")


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    makers = [
        make_pillar,
        make_arch,
        make_beam,
        make_torch,
        make_barrel,
        make_chest,
        make_chain,
        make_bones,
        make_sword,
        make_shield,
    ]
    # Creatures: scripts/blender/generate_creatures.py
    for fn in makers:
        print("==", fn.__name__)
        fn()
    print("ASSET_GEN_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
