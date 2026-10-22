class_name MeshFactory
extends RefCounted
## UV-mapped primitives. UVs tile in world metres so PBR maps do not stretch.

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func box(size: Vector3, tile: float = 1.0) -> ArrayMesh:
	var key := "box:%.3f:%.3f:%.3f:%.3f" % [size.x, size.y, size.z, tile]
	if _cache.has(key):
		return _cache[key]
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# +Z, -Z, +X, -X, +Y, -Y
	_quad(st, Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), Vector3.BACK, size.x, size.y, tile)
	_quad(st, Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3.FORWARD, size.x, size.y, tile)
	_quad(st, Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3.RIGHT, size.z, size.y, tile)
	_quad(st, Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz), Vector3.LEFT, size.z, size.y, tile)
	_quad(st, Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3.UP, size.x, size.z, tile)
	_quad(st, Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3.DOWN, size.x, size.z, tile)
	st.generate_tangents()
	mesh = st.commit()
	_cache[key] = mesh
	return mesh


static func cylinder(radius: float, height: float, sides: int = 14, tile: float = 1.0) -> ArrayMesh:
	var key := "cyl:%.3f:%.3f:%d:%.3f" % [radius, height, sides, tile]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hy := height * 0.5
	var uv_h := height / tile
	var uv_c := (TAU * radius) / tile
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
		# caps
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
