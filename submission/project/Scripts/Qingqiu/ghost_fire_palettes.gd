extends RefCounted
const NAMES := ["幽碧","花青","松柏","竹青","橙金","绯红","月白","白红"]
const KEYS := ["teal","azure","pine","bamboo","amber","vermilion","moonwhite","white_red"]
# Order: outline, outer flame, inner flame, core, small glints.
# Warm white is the harmonious light shade requested for the white/red counterpart.
const HEX := [
	["003472","1685a9","1bd1a5","70f3ff","bbcdc5"],
	["392f41","003472","1685a9","70f3ff","bbcdc5"],
	["392f41","21a675","789262","96ce54","bbcdc5"],
	["3d3b4f","789262","96ce54","bbcdc5","1bd1a5"],
	["4c221b","c83c23","ffa400","f1eee8","bbcdc5"],
	["4c221b","be002f","c83c23","ffa400","bbcdc5"],
	["392f41","3d3b4f","bbcdc5","70f3ff","1bd1a5"],
	["4c221b","f1eee8","c32136","c83c23","bbcdc5"]
]
const PARAMETERS := ["outline_color","outer_color","inner_color","core_color","glint_color"]

static func apply_to(effect: Node,index: int) -> void:
	if index < 0 or index >= HEX.size(): return
	for channel in 5:
		effect.set(PARAMETERS[channel],Color("#"+HEX[index][channel]))
