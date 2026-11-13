class_name Haptics
## Short phone vibrations. On the web this uses the browser's vibrate API (Android only; iOS ignores it).

static func buzz(ms: int, strength := 0.5) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%d)" % ms, true)
	else:
		Input.vibrate_handheld(ms, strength)


static func pattern(steps: Array) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%s)" % str(steps), true)
	else:
		Input.vibrate_handheld(int(steps[0]))


static func tap() -> void: buzz(10, 0.3)
static func land() -> void: buzz(6, 0.15)
static func hurt() -> void: buzz(40, 0.7)
static func fall() -> void: buzz(150, 0.8)
static func lose() -> void: pattern([60, 40, 120])
