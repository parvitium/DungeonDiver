#!/usr/bin/env python3
"""Headless Blender generator for DungeonDiver kit, props, weapons, and creatures."""

from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Vector

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
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def subdivide(obj: bpy.types.Object, levels: int = 1) -> None:
    if levels <= 0:
        return
    mod = obj.modifiers.new(name="Subsurf", type="SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def unwrap(obj: bpy.types.Object) -> None:
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
    print("exported", path, "verts", len(obj.data.vertices) if obj.type == "MESH" else 0)


def finish_mesh(obj: bpy.types.Object, do_bevel: bool = True, sub: int = 0) -> bpy.types.Object:
    if do_bevel:
        bevel(obj, 0.01, 2)
    if sub:
        subdivide(obj, sub)
    shade_smooth(obj)
    unwrap(obj)
    return obj


def add_simple_armature(mesh: bpy.types.Object, bones: list[tuple], actions: dict) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = mesh.name + "_Arm"
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


def make_pillar() -> None:
    reset()
    base = mesh_cube((0.55, 0.55, 0.18), (0, 0, 0.09), name="Base")
    shaft = mesh_cyl(0.16, 3.6, (0, 0, 2.0), verts=12, name="Shaft")
    cap = mesh_cube((0.5, 0.5, 0.16), (0, 0, 3.92), name="Cap")
    neck = mesh_cyl(0.2, 0.18, (0, 0, 3.72), verts=12, name="Neck")
    obj = join([base, shaft, cap, neck], "pillar")
    finish_mesh(obj)
    export_glb(obj, "kit/pillar.glb")


def make_arch() -> None:
    reset()
    parts = []
    # horseshoe of blocks
    for i in range(-4, 5):
        t = i / 4.0
        ang = math.pi * 0.5 * t
        x = math.sin(ang) * 1.45
        z = 2.55 + math.cos(ang) * 0.55
        block = mesh_cube((0.38, 0.42, 0.28), (x, 0, z), (0, 0, -ang * 0.35), name=f"V{i}")
        parts.append(block)
    left = mesh_cube((0.22, 0.42, 2.4), (-1.5, 0, 1.2), name="L")
    right = mesh_cube((0.22, 0.42, 2.4), (1.5, 0, 1.2), name="R")
    obj = join(parts + [left, right], "arch")
    finish_mesh(obj)
    export_glb(obj, "kit/arch.glb")


def make_beam() -> None:
    reset()
    beam = mesh_cube((13.2, 0.2, 0.18), (0, 0, 0), name="beam")
    iron = mesh_cube((0.28, 0.26, 0.22), (-5.8, 0, 0), name="BandL")
    iron2 = mesh_cube((0.28, 0.26, 0.22), (5.8, 0, 0), name="BandR")
    obj = join([beam, iron, iron2], "beam")
    finish_mesh(obj, sub=0)
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
    # bulge via scale on mid
    top = mesh_cyl(0.30, 0.04, (0, 0, 0.72), verts=16, name="Lid")
    bot = mesh_cyl(0.30, 0.04, (0, 0, 0.02), verts=16, name="Bot")
    rings = [
        mesh_cyl(0.335, 0.04, (0, 0, z), verts=16, name=f"Hoop{i}")
        for i, z in enumerate((0.16, 0.36, 0.56))
    ]
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
    skull = mesh_uvsphere(0.16, (0, 0, 0.2), name="Skull", segments=14, rings=9)
    jaw = mesh_cube((0.18, 0.12, 0.07), (0, 0.04, 0.08), name="Jaw")
    f1 = mesh_cyl(0.03, 0.48, (0.16, 0.05, 0.08), (0, 1.1, 0.4), verts=8, name="F1")
    f2 = mesh_cyl(0.028, 0.42, (-0.14, -0.04, 0.1), (0.3, -0.8, 0.2), verts=8, name="F2")
    rib = mesh_torus(0.12, 0.015, (0.02, -0.12, 0.14), (1.1, 0, 0), name="Rib")
    obj = join([skull, jaw, f1, f2, rib], "bones")
    finish_mesh(obj)
    export_glb(obj, "props/bones.glb")


def make_sword() -> None:
    reset()
    blade = mesh_cube((0.045, 0.012, 0.78), (0, 0, 0.55), name="Blade")
    # taper by extra tip
    tip = mesh_cone(0.03, 0.002, 0.12, (0, 0, 0.98), rot=(0, 0, 0), name="Tip")
    fuller = mesh_cube((0.01, 0.014, 0.62), (0, 0, 0.52), name="Fuller")
    guard = mesh_cube((0.22, 0.04, 0.04), (0, 0, 0.16), name="Guard")
    grip = mesh_cyl(0.02, 0.14, (0, 0, 0.07), verts=10, name="Grip")
    pommel = mesh_uvsphere(0.03, (0, 0, -0.02), name="Pommel", segments=10, rings=6)
    obj = join([blade, tip, fuller, guard, grip, pommel], "sword")
    finish_mesh(obj, sub=1)
    export_glb(obj, "weapons/sword.glb")


def make_shield() -> None:
    reset()
    body = mesh_cube((0.42, 0.08, 0.56), (0, 0, 0), name="Body")
    # heater taper via extra plates
    rim = mesh_cube((0.46, 0.04, 0.6), (0, 0, 0), name="Rim")
    boss = mesh_uvsphere(0.07, (0, 0.05, 0.04), name="Boss", segments=12, rings=8)
    strap = mesh_cube((0.08, 0.03, 0.22), (0, -0.05, 0), name="Strap")
    obj = join([body, rim, boss, strap], "shield")
    finish_mesh(obj, sub=1)
    export_glb(obj, "weapons/shield.glb")


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


def make_skeleton() -> None:
    reset()
    parts = []
    skull = mesh_uvsphere(0.13, (0, 0.02, 1.55), name="Skull", segments=14, rings=10)
    jaw = mesh_cube((0.14, 0.1, 0.06), (0, 0.04, 1.42), name="Jaw")
    parts += [skull, jaw]
    for i in range(6):
        z = 0.7 + i * 0.12
        parts.append(mesh_cube((0.08, 0.06, 0.06), (0, 0, z), name=f"Vert{i}"))
        parts.append(mesh_torus(0.12, 0.012, (0, 0, z), (1.2, 0, 0), name=f"Rib{i}"))
    pelvis = mesh_cube((0.22, 0.12, 0.1), (0, 0, 0.62), name="Pelvis")
    parts.append(pelvis)
    for side, sx in (("L", 0.16), ("R", -0.16)):
        parts.append(mesh_cyl(0.035, 0.38, (sx, 0, 1.15), (0, 0.15 * (1 if sx > 0 else -1), 0.9), verts=8, name=f"{side}Uarm"))
        parts.append(mesh_cyl(0.03, 0.34, (sx * 1.15, 0.02, 0.82), (0, 0, 0.2), verts=8, name=f"{side}Larm"))
        parts.append(mesh_cyl(0.04, 0.4, (sx * 0.7, 0, 0.38), (0.15, 0, 0), verts=8, name=f"{side}Thigh"))
        parts.append(mesh_cyl(0.035, 0.36, (sx * 0.7, 0.02, 0.12), (0.05, 0, 0), verts=8, name=f"{side}Shin"))
    obj = join(parts, "skeleton")
    finish_mesh(obj)
    add_simple_armature(obj, bones_humanoid(), creature_actions())
    export_glb(obj, "monsters/skeleton.glb")


def make_wolf() -> None:
    reset()
    body = mesh_uvsphere(0.28, (0, 0, 0.42), name="Body", segments=16, rings=10)
    body.scale = (1.55, 0.7, 0.72)
    bpy.ops.object.transform_apply(scale=True)
    chest = mesh_uvsphere(0.22, (0.28, 0, 0.46), name="Chest", segments=12, rings=8)
    head = mesh_uvsphere(0.16, (0.55, 0, 0.52), name="Head", segments=12, rings=8)
    snout = mesh_cone(0.09, 0.03, 0.18, (0.72, 0, 0.46), rot=(0, math.pi * 0.5, 0), name="Snout")
    ear_l = mesh_cone(0.05, 0.0, 0.12, (0.52, 0.08, 0.66), rot=(0.4, 0, 0), name="EarL")
    ear_r = mesh_cone(0.05, 0.0, 0.12, (0.52, -0.08, 0.66), rot=(-0.4, 0, 0), name="EarR")
    tail = mesh_cone(0.06, 0.015, 0.42, (-0.42, 0, 0.48), rot=(0, -1.1, 0), name="Tail")
    legs = []
    for i, (x, y) in enumerate(((0.32, 0.12), (0.32, -0.12), (-0.22, 0.12), (-0.22, -0.12))):
        legs.append(mesh_cyl(0.045, 0.38, (x, y, 0.2), verts=8, name=f"Leg{i}"))
    obj = join([body, chest, head, snout, ear_l, ear_r, tail] + legs, "cave_wolf")
    finish_mesh(obj, sub=1)
    bones = [
        ("root", (0, 0, 0.15), (0, 0, 0.35)),
        ("spine", (0, 0, 0.35), (0.3, 0, 0.5), "root"),
        ("head", (0.3, 0, 0.5), (0.65, 0, 0.55), "spine"),
        ("Larm", (0.3, 0.12, 0.35), (0.3, 0.12, 0.05), "spine"),
        ("Rarm", (0.3, -0.12, 0.35), (0.3, -0.12, 0.05), "spine"),
        ("Lleg", (-0.2, 0.12, 0.3), (-0.2, 0.12, 0.05), "root"),
        ("Rleg", (-0.2, -0.12, 0.3), (-0.2, -0.12, 0.05), "root"),
    ]
    add_simple_armature(obj, bones, creature_actions())
    export_glb(obj, "monsters/cave_wolf.glb")


def make_wraith() -> None:
    reset()
    hood = mesh_uvsphere(0.18, (0, 0, 1.45), name="Hood", segments=14, rings=9)
    face = mesh_uvsphere(0.1, (0, 0.06, 1.42), name="Face", segments=10, rings=7)
    robe = mesh_cone(0.42, 0.08, 1.35, (0, 0, 0.7), name="Robe")
    sleeve_l = mesh_cone(0.1, 0.04, 0.55, (0.28, 0.05, 1.05), rot=(0, 0, 1.0), name="SL")
    sleeve_r = mesh_cone(0.1, 0.04, 0.55, (-0.28, 0.05, 1.05), rot=(0, 0, -1.0), name="SR")
    obj = join([hood, face, robe, sleeve_l, sleeve_r], "wraith")
    finish_mesh(obj, sub=1)
    add_simple_armature(obj, bones_humanoid(), creature_actions())
    export_glb(obj, "monsters/wraith.glb")


def make_lich() -> None:
    reset()
    skull = mesh_uvsphere(0.14, (0, 0.02, 1.72), name="Skull", segments=14, rings=9)
    crown = mesh_torus(0.12, 0.02, (0, 0, 1.86), name="Crown")
    spike = mesh_cone(0.03, 0.0, 0.12, (0, 0, 1.98), name="Spike")
    robe = mesh_cone(0.48, 0.12, 1.5, (0, 0, 0.78), name="Robe")
    chest = mesh_uvsphere(0.2, (0, 0, 1.25), name="Chest", segments=12, rings=8)
    staff = mesh_cyl(0.025, 1.7, (-0.42, 0.1, 0.9), (0.15, 0, 0.2), verts=8, name="Staff")
    orb = mesh_uvsphere(0.08, (-0.5, 0.16, 1.72), name="Orb", segments=10, rings=7)
    obj = join([skull, crown, spike, robe, chest, staff, orb], "lich")
    finish_mesh(obj, sub=1)
    add_simple_armature(obj, bones_humanoid(), creature_actions())
    export_glb(obj, "monsters/lich.glb")


def make_troll() -> None:
    reset()
    torso = mesh_uvsphere(0.42, (0, 0.05, 1.15), name="Torso", segments=14, rings=9)
    torso.scale = (1.15, 0.85, 1.25)
    bpy.ops.object.transform_apply(scale=True)
    belly = mesh_uvsphere(0.38, (0.05, 0.08, 0.78), name="Belly", segments=12, rings=8)
    head = mesh_uvsphere(0.22, (0.12, 0.12, 1.72), name="Head", segments=12, rings=8)
    jaw = mesh_cube((0.2, 0.14, 0.08), (0.2, 0.16, 1.58), name="Jaw")
    shoulder_l = mesh_uvsphere(0.18, (0.42, 0.05, 1.38), name="SL")
    shoulder_r = mesh_uvsphere(0.18, (-0.42, 0.05, 1.38), name="SR")
    arm_l = mesh_cyl(0.1, 0.7, (0.55, 0.08, 0.95), (0.2, 0, 0.4), verts=10, name="AL")
    arm_r = mesh_cyl(0.1, 0.7, (-0.55, 0.08, 0.95), (0.2, 0, -0.4), verts=10, name="AR")
    leg_l = mesh_cyl(0.12, 0.7, (0.18, 0.04, 0.38), verts=10, name="LL")
    leg_r = mesh_cyl(0.12, 0.7, (-0.18, 0.04, 0.38), verts=10, name="LR")
    obj = join([torso, belly, head, jaw, shoulder_l, shoulder_r, arm_l, arm_r, leg_l, leg_r], "cave_troll")
    finish_mesh(obj, sub=1)
    bones = [
        ("root", (0, 0, 0.1), (0, 0, 0.4)),
        ("spine", (0, 0, 0.4), (0, 0, 1.2), "root"),
        ("head", (0, 0, 1.2), (0.1, 0.1, 1.75), "spine"),
        ("Larm", (0.4, 0, 1.3), (0.55, 0, 0.7), "spine"),
        ("Rarm", (-0.4, 0, 1.3), (-0.55, 0, 0.7), "spine"),
        ("Lleg", (0.18, 0, 0.4), (0.18, 0, 0.05), "root"),
        ("Rleg", (-0.18, 0, 0.4), (-0.18, 0, 0.05), "root"),
    ]
    add_simple_armature(obj, bones, creature_actions())
    export_glb(obj, "monsters/cave_troll.glb")


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
        make_skeleton,
        make_wolf,
        make_wraith,
        make_lich,
        make_troll,
    ]
    for fn in makers:
        print("==", fn.__name__)
        fn()
    print("ASSET_GEN_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
