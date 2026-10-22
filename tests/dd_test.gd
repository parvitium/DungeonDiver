class_name DDTest
extends RefCounted

var suite_name: String = "suite"
var passed: int = 0
var failed: int = 0
var errors: PackedStringArray = []


func _init(p_name: String = "suite") -> void:
	suite_name = p_name


func assert_true(value: bool, message: String = "") -> void:
	if value:
		passed += 1
	else:
		failed += 1
		errors.append(_fmt("assert_true", message))


func assert_false(value: bool, message: String = "") -> void:
	assert_true(not value, message if not message.is_empty() else "expected false")


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		errors.append(_fmt("assert_eq", "%s  actual=%s expected=%s" % [message, str(actual), str(expected)]))


func assert_gt(actual: float, expected: float, message: String = "") -> void:
	assert_true(actual > expected, message if not message.is_empty() else "%s > %s" % [str(actual), str(expected)])


func assert_ge(actual: float, expected: float, message: String = "") -> void:
	assert_true(actual >= expected, message if not message.is_empty() else "%s >= %s" % [str(actual), str(expected)])


func assert_in_range(actual: float, lo: float, hi: float, message: String = "") -> void:
	assert_true(actual >= lo and actual <= hi, message if not message.is_empty() else "%s in [%s, %s]" % [str(actual), str(lo), str(hi)])


func _fmt(kind: String, message: String) -> String:
	return "[%s] %s: %s" % [suite_name, kind, message]
