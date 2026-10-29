class_name Barrel
extends Unit
## A breakable barrel: a piece of a pen wall, or a loose powder keg. Logic only; BarrelField draws them.
## Hits go through BarrelField.hit() (Run.damage routes them there), never through Unit HP rules.

var pen := -1          # index into BarrelField.pens, -1 = loose keg
var slot := 0
var keg := false
var idx := 0           # instance index in the field's MultiMesh
var yaw := 0.0
var wob := 0.0         # hit wobble time left (visual only)
var lit := false       # keg fuse burning (broken, about to blow)


func _init() -> void:
	team = 2
	kind = "barrel"
	radius = DB.BARREL_R
	height = 1.0
	no_push = true
	targetable = false
	max_hp = DB.BARREL_HP
	hp = max_hp
