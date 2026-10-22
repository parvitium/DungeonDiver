class_name MeshFactory
extends RefCounted
## UV-mapped primitives. UVs are world metres so PBR tiles at the material scale.

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func box(size: Vector3, tile: float = 1.0) -> ArrayMesh:
	return beveled_box(size, 0.0, tile)


static func beveled_box(size: Vector3, bevel: float = 0.035, tile: float = 1.0) -> ArrayMesh:
	var key := "bbox:%.3f:%.3f:%.3f:%.3f:%.3f" % [size.x, size.y, size.z, bevel, tile]
	if _cache.has(key):
		return _cache[key]
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var b := minf(bevel, minf(hx, minf(hy, hz)) * 0.35)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if b <= 0.001:
		_quad(st, Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3.BACK, size.x, size.y, tile)
		_quad(st, Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3.FORWARD, size.x, size.y, tile)
		_quad(st, Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3.RIGHT, size.z, size.y, tile)
		_quad(st, Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3.LEFT, size.z, size.y, tile)
		_quad(st, Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3.UP, size.x, size.z, tile)
		_quad(st, Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3.DOWN, size.x, size.z, tile)
	else:
		_bevel_box(st, hx, hy, hz, b, tile)
	st.generate_tangents()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func cylinder(radius: float, height: float, sides: int = 14, tile: float = 1.0) -> ArrayMesh:
	var key := "cyl:%.3f:%.3f:%d:%.3f" % [radius, height, sides, tile]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hy := height * 0.5
	var uv_h := height / maxf(0.05, tile)
	var uv_c := (TAU * radius) / maxf(0.05, tile)
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var n0 := Vector3(cos(a0), 0, sin(a0))
		var n1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := n0 * radius + Vector3(0, -hy, 0)
		var p1 := n1 * radius + Vector3(0, -hy, 0)
		var p2 := n1 * radius + Vector3(0, hy, 0)
		var p3 := n0 * radius + Vector3(0, hy, 0)
		var u0 := uv_c * float(i) / float(sides)
		var u1 := uv_c * float(i + 1) / float(sides)
		_tri(st, p0, p1, p2, n0, n1, n1, Vector2(u0, uv_h), Vector2(u1, uv_h), Vector2(u1, 0))
		_tri(st, p0, p2, p3, n0, n1, n0, Vector2(u0, uv_h), Vector2(u1, 0), Vector2(u0, 0))
		var top := Vector3(0, hy, 0)
		var bot := Vector3(0, -hy, 0)
		_tri(st, top, p3, p2, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0.5, 0.5), Vector2(0.5 + n0.x * 0.5, 0.5 + n0.z * 0.5), Vector2(0.5 + n1.x * 0.5, 0.5 + n1.z * 0.5))
		_tri(st, bot, p1, p0, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector2(0.5, 0.5), Vector2(0.5 + n1.x * 0.5, 0.5 + n1.z * 0.5), Vector2(0.5 + n0.x * 0.5, 0.5 + n0.z * 0.5))
	st.generate_tangents()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func visual(mesh: Mesh, material: Material, name: String = "BodyVisual") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func flagstones(size: Vector3, tile: float, seed_value: int) -> ArrayMesh:
	var key := "flags:%.2f:%.2f:%.3f:%d" % [size.x, size.z, tile, seed_value]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := maxi(5, int(size.x / 1.05))
	var rows := maxi(5, int(size.z / 1.05))
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var col_w: PackedFloat32Array = PackedFloat32Array()
	var row_h: PackedFloat32Array = PackedFloat32Array()
	var col_sum := 0.0
	var row_sum := 0.0
	for _i in cols:
		var w := rng.randf_range(0.62, 1.55)
		col_w.append(w)
		col_sum += w
	for _i in rows:
		var hgt := rng.randf_range(0.62, 1.55)
		row_h.append(hgt)
		row_sum += hgt
	var x_cursor := -hx
	for ix in cols:
		var cell_x := size.x * (col_w[ix] / col_sum)
		var z_cursor := -hz
		for iz in rows:
			var cell_z := size.z * (row_h[iz] / row_sum)
			var gap := rng.randf_range(0.04, 0.09)
			var x0 := x_cursor + gap + rng.randf_range(-0.08, 0.08)
			var z0 := z_cursor + gap + rng.randf_range(-0.08, 0.08)
			var x1 := x_cursor + cell_x - gap + rng.randf_range(-0.07, 0.07)
			var z1 := z_cursor + cell_z - gap + rng.randf_range(-0.07, 0.07)
			var y := rng.randf_range(0.0, 0.07)
			var y00 := y
			var y10 := y + rng.randf_range(-0.018, 0.018)
			var y11 := y + rng.randf_range(-0.018, 0.018)
			var y01 := y + rng.randf_range(-0.018, 0.018)
			var a := Vector3(x0, y00, z0)
			var b := Vector3(x1, y10, z0)
			var c := Vector3(x1, y11, z1)
			var d := Vector3(x0, y01, z1)
			var nrm := (b - a).cross(d - a).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			var uw := (x1 - x0) / maxf(0.05, tile)
			var uh := (z1 - z0) / maxf(0.05, tile)
			_tri(st, a, b, c, nrm, nrm, nrm, Vector2(0, uh), Vector2(uw, uh), Vector2(uw, 0))
			_tri(st, a, c, d, nrm, nrm, nrm, Vector2(0, uh), Vector2(uw, 0), Vector2(0, 0))
			var thick := 0.05
			var a2 := a + Vector3(0, -thick, 0)
			var b2 := b + Vector3(0, -thick, 0)
			var c2 := c + Vector3(0, -thick, 0)
			var d2 := d + Vector3(0, -thick, 0)
			_quad(st, a2, b2, b, a, Vector3.FORWARD, x1 - x0, thick, tile)
			_quad(st, d, c, c2, d2, Vector3.BACK, x1 - x0, thick, tile)
			_quad(st, a, d, d2, a2, Vector3.LEFT, z1 - z0, thick, tile)
			_quad(st, b2, c2, c, b, Vector3.RIGHT, z1 - z0, thick, tile)
			z_cursor += cell_z
		x_cursor += cell_x
	st.generate_tangents()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func stone_arch(span: float, rise: float, depth: float, tile: float = 0.65) -> ArrayMesh:
	var key := "arch:%.2f:%.2f:%.2f:%.2f" % [span, rise, depth, tile]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	var hz := depth * 0.5
	var thick := 0.38
	for i in segs:
		var a0 := PI * float(i) / float(segs)
		var a1 := PI * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * span * 0.5, sin(a0) * rise, 0)
		var p1 := Vector3(cos(a1) * span * 0.5, sin(a1) * rise, 0)
		var n0 := Vector3(cos(a0) * rise, sin(a0) * span * 0.5, 0).normalized()
		var n1 := Vector3(cos(a1) * rise, sin(a1) * span * 0.5, 0).normalized()
		var i0 := p0
		var i1 := p1
		var o0 := p0 + n0 * thick
		var o1 := p1 + n1 * thick
		var uw := span / maxf(0.05, tile) / float(segs)
		var uh := rise / maxf(0.05, tile)
		_quad(st, Vector3(i0.x, i0.y, hz), Vector3(i1.x, i1.y, hz), Vector3(o1.x, o1.y, hz), Vector3(o0.x, o0.y, hz), Vector3.BACK, uw, uh, tile)
		_quad(st, Vector3(o0.x, o0.y, -hz), Vector3(o1.x, o1.y, -hz), Vector3(i1.x, i1.y, -hz), Vector3(i0.x, i0.y, -hz), Vector3.FORWARD, uw, uh, tile)
		_quad(st, Vector3(o0.x, o0.y, hz), Vector3(o1.x, o1.y, hz), Vector3(o1.x, o1.y, -hz), Vector3(o0.x, o0.y, -hz), n0, uw, depth, tile)
		_quad(st, Vector3(i1.x, i1.y, hz), Vector3(i0.x, i0.y, hz), Vector3(i0.x, i0.y, -hz), Vector3(i1.x, i1.y, -hz), -n0, uw, depth, tile)
	st.generate_tangents()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func vault_ceiling(size: Vector3, rise: float, tile: float, segs: int = 8) -> ArrayMesh:
	var key := "vault:%.2f:%.2f:%.2f:%.2f:%d" % [size.x, size.z, rise, tile, segs]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	for iz in segs:
		for ix in segs:
			var u0 := float(ix) / float(segs)
			var v0 := float(iz) / float(segs)
			var u1 := float(ix + 1) / float(segs)
			var v1 := float(iz + 1) / float(segs)
			var p00 := _vault_point(u0, v0, hx, hz, rise)
			var p10 := _vault_point(u1, v0, hx, hz, rise)
			var p11 := _vault_point(u1, v1, hx, hz, rise)
			var p01 := _vault_point(u0, v1, hx, hz, rise)
			var nrm := (p10 - p00).cross(p01 - p00).normalized()
			if nrm.y > 0.0:
				nrm = -nrm
			var uw := size.x / maxf(0.05, tile) / float(segs)
			var uh := size.z / maxf(0.05, tile) / float(segs)
			_tri(st, p00, p10, p11, nrm, nrm, nrm, Vector2(u0 * uw * float(segs), v0 * uh * float(segs)), Vector2(u1 * uw * float(segs), v0 * uh * float(segs)), Vector2(u1 * uw * float(segs), v1 * uh * float(segs)))
			_tri(st, p00, p11, p01, nrm, nrm, nrm, Vector2(u0 * uw * float(segs), v0 * uh * float(segs)), Vector2(u1 * uw * float(segs), v1 * uh * float(segs)), Vector2(u0 * uw * float(segs), v1 * uh * float(segs)))
	st.generate_tangents()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func _vault_point(u: float, v: float, hx: float, hz: float, rise: float) -> Vector3:
	var arch := sin(u * PI) * sin(v * PI)
	return Vector3((u - 0.5) * hx * 2.0, rise * arch, (v - 0.5) * hz * 2.0)


static func _bevel_box(st: SurfaceTool, hx: float, hy: float, hz: float, b: float, tile: float) -> void:
	var ix := hx - b
	var iy := hy - b
	var iz := hz - b
	# Inset faces
	_quad(st, Vector3(-ix, -iy, hz), Vector3(ix, -iy, hz), Vector3(ix, iy, hz), Vector3(-ix, iy, hz), Vector3.BACK, ix * 2.0, iy * 2.0, tile)
	_quad(st, Vector3(ix, -iy, -hz), Vector3(-ix, -iy, -hz), Vector3(-ix, iy, -hz), Vector3(ix, iy, -hz), Vector3.FORWARD, ix * 2.0, iy * 2.0, tile)
	_quad(st, Vector3(hx, -iy, iz), Vector3(hx, -iy, -iz), Vector3(hx, iy, -iz), Vector3(hx, iy, iz), Vector3.RIGHT, iz * 2.0, iy * 2.0, tile)
	_quad(st, Vector3(-hx, -iy, -iz), Vector3(-hx, -iy, iz), Vector3(-hx, iy, iz), Vector3(-hx, iy, -iz), Vector3.LEFT, iz * 2.0, iy * 2.0, tile)
	_quad(st, Vector3(-ix, hy, iz), Vector3(ix, hy, iz), Vector3(ix, hy, -iz), Vector3(-ix, hy, -iz), Vector3.UP, ix * 2.0, iz * 2.0, tile)
	_quad(st, Vector3(-ix, -hy, -iz), Vector3(ix, -hy, -iz), Vector3(ix, -hy, iz), Vector3(-ix, -hy, iz), Vector3.DOWN, ix * 2.0, iz * 2.0, tile)
	# Edge bevels
	var n_zp := (Vector3.BACK + Vector3.RIGHT).normalized()
	_quad(st, Vector3(ix, -iy, hz), Vector3(hx, -iy, iz), Vector3(hx, iy, iz), Vector3(ix, iy, hz), n_zp, b * 1.4, iy * 2.0, tile)
	var n_zn := (Vector3.BACK + Vector3.LEFT).normalized()
	_quad(st, Vector3(-hx, -iy, iz), Vector3(-ix, -iy, hz), Vector3(-ix, iy, hz), Vector3(-hx, iy, iz), n_zn, b * 1.4, iy * 2.0, tile)
	var n_fn := (Vector3.FORWARD + Vector3.RIGHT).normalized()
	_quad(st, Vector3(hx, -iy, -iz), Vector3(ix, -iy, -hz), Vector3(ix, iy, -hz), Vector3(hx, iy, -iz), n_fn, b * 1.4, iy * 2.0, tile)
	var n_fp := (Vector3.FORWARD + Vector3.LEFT).normalized()
	_quad(st, Vector3(-ix, -iy, -hz), Vector3(-hx, -iy, -iz), Vector3(-hx, iy, -iz), Vector3(-ix, iy, -hz), n_fp, b * 1.4, iy * 2.0, tile)
	var n_zu := (Vector3.BACK + Vector3.UP).normalized()
	_quad(st, Vector3(-ix, iy, hz), Vector3(ix, iy, hz), Vector3(ix, hy, iz), Vector3(-ix, hy, iz), n_zu, ix * 2.0, b * 1.4, tile)
	var n_zd := (Vector3.BACK + Vector3.DOWN).normalized()
	_quad(st, Vector3(-ix, -hy, iz), Vector3(ix, -hy, iz), Vector3(ix, -iy, hz), Vector3(-ix, -iy, hz), n_zd, ix * 2.0, b * 1.4, tile)
	var n_fu := (Vector3.FORWARD + Vector3.UP).normalized()
	_quad(st, Vector3(ix, iy, -hz), Vector3(-ix, iy, -hz), Vector3(-ix, hy, -iz), Vector3(ix, hy, -iz), n_fu, ix * 2.0, b * 1.4, tile)
	var n_fd := (Vector3.FORWARD + Vector3.DOWN).normalized()
	_quad(st, Vector3(ix, -iy, -hz), Vector3(-ix, -iy, -hz), Vector3(-ix, -hy, -iz), Vector3(ix, -hy, -iz), n_fd, ix * 2.0, b * 1.4, tile)
	var n_ru := (Vector3.RIGHT + Vector3.UP).normalized()
	_quad(st, Vector3(hx, iy, iz), Vector3(hx, iy, -iz), Vector3(ix, hy, -iz), Vector3(ix, hy, iz), n_ru, iz * 2.0, b * 1.4, tile)
	var n_rd := (Vector3.RIGHT + Vector3.DOWN).normalized()
	_quad(st, Vector3(hx, -iy, -iz), Vector3(hx, -iy, iz), Vector3(ix, -hy, iz), Vector3(ix, -hy, -iz), n_rd, iz * 2.0, b * 1.4, tile)
	var n_lu := (Vector3.LEFT + Vector3.UP).normalized()
	_quad(st, Vector3(-hx, iy, -iz), Vector3(-hx, iy, iz), Vector3(-ix, hy, iz), Vector3(-ix, hy, -iz), n_lu, iz * 2.0, b * 1.4, tile)
	var n_ld := (Vector3.LEFT + Vector3.DOWN).normalized()
	_quad(st, Vector3(-hx, -iy, iz), Vector3(-hx, -iy, -iz), Vector3(-ix, -hy, -iz), Vector3(-ix, -hy, iz), n_ld, iz * 2.0, b * 1.4, tile)
	# Corners
	_tri(st, Vector3(ix, iy, hz), Vector3(hx, iy, iz), Vector3(ix, hy, iz), (Vector3.BACK + Vector3.RIGHT + Vector3.UP).normalized(), (Vector3.BACK + Vector3.RIGHT + Vector3.UP).normalized(), (Vector3.BACK + Vector3.RIGHT + Vector3.UP).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1))
	_tri(st, Vector3(-ix, iy, hz), Vector3(-ix, hy, iz), Vector3(-hx, iy, iz), (Vector3.BACK + Vector3.LEFT + Vector3.UP).normalized(), (Vector3.BACK + Vector3.LEFT + Vector3.UP).normalized(), (Vector3.BACK + Vector3.LEFT + Vector3.UP).normalized(), Vector2(0, 0), Vector2(0, 1), Vector2(1, 0))
	_tri(st, Vector3(ix, iy, -hz), Vector3(ix, hy, -iz), Vector3(hx, iy, -iz), (Vector3.FORWARD + Vector3.RIGHT + Vector3.UP).normalized(), (Vector3.FORWARD + Vector3.RIGHT + Vector3.UP).normalized(), (Vector3.FORWARD + Vector3.RIGHT + Vector3.UP).normalized(), Vector2(0, 0), Vector2(0, 1), Vector2(1, 0))
	_tri(st, Vector3(-ix, iy, -hz), Vector3(-hx, iy, -iz), Vector3(-ix, hy, -iz), (Vector3.FORWARD + Vector3.LEFT + Vector3.UP).normalized(), (Vector3.FORWARD + Vector3.LEFT + Vector3.UP).normalized(), (Vector3.FORWARD + Vector3.LEFT + Vector3.UP).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1))
	_tri(st, Vector3(ix, -iy, hz), Vector3(ix, -hy, iz), Vector3(hx, -iy, iz), (Vector3.BACK + Vector3.RIGHT + Vector3.DOWN).normalized(), (Vector3.BACK + Vector3.RIGHT + Vector3.DOWN).normalized(), (Vector3.BACK + Vector3.RIGHT + Vector3.DOWN).normalized(), Vector2(0, 0), Vector2(0, 1), Vector2(1, 0))
	_tri(st, Vector3(-ix, -iy, hz), Vector3(-hx, -iy, iz), Vector3(-ix, -hy, iz), (Vector3.BACK + Vector3.LEFT + Vector3.DOWN).normalized(), (Vector3.BACK + Vector3.LEFT + Vector3.DOWN).normalized(), (Vector3.BACK + Vector3.LEFT + Vector3.DOWN).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1))
	_tri(st, Vector3(ix, -iy, -hz), Vector3(hx, -iy, -iz), Vector3(ix, -hy, -iz), (Vector3.FORWARD + Vector3.RIGHT + Vector3.DOWN).normalized(), (Vector3.FORWARD + Vector3.RIGHT + Vector3.DOWN).normalized(), (Vector3.FORWARD + Vector3.RIGHT + Vector3.DOWN).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1))
	_tri(st, Vector3(-ix, -iy, -hz), Vector3(-ix, -hy, -iz), Vector3(-hx, -iy, -iz), (Vector3.FORWARD + Vector3.LEFT + Vector3.DOWN).normalized(), (Vector3.FORWARD + Vector3.LEFT + Vector3.DOWN).normalized(), (Vector3.FORWARD + Vector3.LEFT + Vector3.DOWN).normalized(), Vector2(0, 0), Vector2(0, 1), Vector2(1, 0))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, w: float, h: float, tile: float) -> void:
	var uw := w / maxf(0.05, tile)
	var uh := h / maxf(0.05, tile)
	_tri(st, a, b, c, normal, normal, normal, Vector2(0, uh), Vector2(uw, uh), Vector2(uw, 0))
	_tri(st, a, c, d, normal, normal, normal, Vector2(0, uh), Vector2(uw, 0), Vector2(0, 0))


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_normal(na)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(nc)
	st.set_uv(uc)
	st.add_vertex(c)
