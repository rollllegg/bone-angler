extends RefCounted
## Fishing, QTE and potion configurations from the Feishu playtest specifications.

enum Attribute { WISDOM, EMOTION, WILL }
enum Bait { DEFAULT, WISDOM, EMOTION, WILL, VARIANT }

const Alchemy := preload("res://scripts/systems/alchemy_rules.gd")
const POTIONS := Alchemy.POTIONS
const RULES_VERSION := 20

const FISH := [
	{"id": "fish_01", "name": "灰鳞鱼", "essence": "灰鳞原液", "primary_stat": Attribute.WISDOM, "cm": Vector2(2, 6), "water": [25, 0], "tier": 0},
	{"id": "fish_02", "name": "冥河鲫", "essence": "冥河原液", "primary_stat": Attribute.EMOTION, "cm": Vector2(8, 12), "water": [20, 10], "tier": 0},
	{"id": "fish_03", "name": "幽灯鱼", "essence": "幽灯原液", "primary_stat": Attribute.WILL, "cm": Vector2(18, 28), "water": [15, 15], "tier": 1},
	{"id": "fish_04", "name": "链颌鱼", "essence": "链颌原液", "primary_stat": Attribute.WILL, "cm": Vector2(40, 60), "water": [0, 20], "tier": 1},
	{"id": "fish_05", "name": "渡魂鲶", "essence": "渡魂原液", "primary_stat": Attribute.EMOTION, "cm": Vector2(90, 120), "water": [0, 15], "tier": 2},
	{"id": "fish_06", "name": "墨眼鳉", "essence": "墨眼原液", "primary_stat": Attribute.WISDOM, "cm": Vector2(3, 7), "water": [20, 0], "tier": 0},
	{"id": "fish_07", "name": "泪纹鲦", "essence": "泪纹原液", "primary_stat": Attribute.EMOTION, "cm": Vector2(9, 15), "water": [15, 10], "tier": 0},
	{"id": "fish_08", "name": "回声鳊", "essence": "息执原液", "primary_stat": Attribute.WILL, "cm": Vector2(22, 34), "water": [0, 15], "tier": 1},
	{"id": "fish_09", "name": "镜骨鲈", "essence": "镜骨原液", "primary_stat": Attribute.WISDOM, "cm": Vector2(45, 65), "water": [0, 10], "tier": 1},
	{"id": "fish_10", "name": "负碑鳢", "essence": "负碑原液", "primary_stat": Attribute.WISDOM, "cm": Vector2(95, 130), "water": [0, 5], "tier": 2},
	# Fish indices are saved in catches and essence inventories.
	{"id": "fish_01_variant", "name": "巨刺灰鳞鱼", "essence": "巨刺原液", "cm": Vector2(30, 38), "water": [0, 0], "tier": -1},
	{"id": "fish_11", "name": "静鳍鳅", "essence": "息执原液", "primary_stat": Attribute.WILL, "cm": Vector2(10, 18), "water": [5, 0], "tier": 0},
]
const VARIANT := 10
const RIVER_CARP := 1
const STILLFIN := 11
const LANTERN := 2
const CHAIN := 3
const SIZE_NAMES := ["小型", "正常", "大型", "异变"]
const SIZE_WEIGHTS := [20.0, 65.0, 15.0]
const RODS := ["短杆／浅水", "长杆／深水"]
const HOOKS := ["小号钩", "中号钩", "大号钩"]
const HOOK_WEIGHTS := [Vector3(4, 1, 0.1), Vector3(1, 4, 1), Vector3(0.1, 1, 4)]
const GRIP_CAPACITY := 10
const GRIP_QUICK_REPAIR_DURABILITY := 5
const GRIP_QUICK_REPAIR_COST := 6
const GRIP_FULL_REPAIR_COST := 10
const SCHOOL_SPECIES := [-1, LANTERN, 4]
const BAITS := ["素指骨饵", "智慧饵", "情感饵", "意志饵", "异刺指骨拟饵"]
const ATTRIBUTE_BAITS := {Bait.WISDOM: Vector2i(0, 0), Bait.EMOTION: Vector2i(1, 0), Bait.WILL: Vector2i(2, 0)}
const ATTRIBUTE_BAIT_MULTIPLIER := 3.0
const VARIANT_BAIT := Bait.VARIANT
const VARIANT_CRAFT_COST := 80
const LEGACY_BAIT_MAPS := {
	8: [0, 0, 0, 0, 1, 2, 3, 4],
	9: [0, 1, 2, 3, 1, 2, 3, 4, 0],
	12: [0, 0, 0, 0, 1, 2, 3, 1, 2, 3, 4, 0],
	16: [0, 0, 0, 0, 1, 2, 3, 3, 2, 1, 2, 3, 1, 1, 4, 0],
}
const VARIANT_CHANCE := 0.20
const BITE_MIN := 3.0
const BITE_MODE := 5.0
const BITE_MAX := 8.0
const STARTING_COINS := 40
const STARTING_BAIT := 10
const BAIT_PRICES := [2, 4, 4, 4, 8]
const STEADY_CHARM := 5
const CHARM_LIMIT := 2
const DEVICES := [
	["短杆", 40], ["长杆", 160],
	["小号钩", 20], ["中号钩", 50], ["大号钩", 50],
	["稳魂指骨", 70],
]
const ARRIVAL_MIN := 20.0
const ARRIVAL_MAX := 25.0
const FISH_TEXTURES := {
	"fish_01": preload("res://assets/art/fish/fish_01.png"),
	"fish_01_variant": preload("res://assets/art/fish/fish_01_variant.png"),
	"fish_02": preload("res://assets/art/fish/fish_02.png"),
	"fish_03": preload("res://assets/art/fish/fish_03.png"),
	"fish_03_condensed": preload("res://assets/art/fish/fish_03_condensed.png"),
	"fish_04": preload("res://assets/art/fish/fish_04.png"),
	"fish_05": preload("res://assets/art/fish/fish_05.png"),
	"fish_06": preload("res://assets/art/fish/fish_06.png"),
	"fish_07": preload("res://assets/art/fish/fish_07.png"),
	"fish_08": preload("res://assets/art/fish/fish_08.png"),
	"fish_09": preload("res://assets/art/fish/fish_09.png"),
	"fish_10": preload("res://assets/art/fish/fish_10.png"),
	"fish_11": preload("res://assets/art/fish/fish_11.png"),
}
const ROD_DESCS := ["浅水区 · 1 个指骨挂槽", "深水区 · 2 个指骨挂槽"]
const HOOK_DESCS := ["偏向小型鱼获", "偏向正常体型", "偏向大型鱼获"]
const STAT_NAMES := ["智慧", "情感", "意志"]
const STAT_COLORS := [Color("4eb8f7"), Color("f05b73"), Color("f2bc46")]
const TRAVEL := [0.80, 0.68, 0.56]
const NORMAL_HALF_WINDOW := [0.30, 0.23, 0.18]
const PERFECT_HALF_WINDOW := [0.12, 0.09, 0.07]
const PROGRESS := [[3, 4, 5], [5, 6, 8], [6, 8, 10]]
const PREPARATION := 0.30
const ROUND_GAP := 0.12
const FISH_TIME := 20.0
const MISTAKE_LIMIT := 3
const SLOT_BONUS := 0.10
# Four-way line control: 0 tap, 1 sustained hold, 2 hold then release for a surge.
# Each species repeats its own readable sequence; size still changes progress only.
const FISHING_ACTION_PATTERNS := [
	[0, 1, 2],
	[0, 2, 1],
	[1, 0, 2],
	[1, 2, 1, 0],
	[2, 1, 2, 0],
	[0, 0, 2, 1],
	[2, 0, 1],
	[0, 1, 2, 1],
	[2, 0, 1, 2],
	[1, 2, 0, 2],
	[], # The giant uses the true-name challenge.
	[0, 1, 2], # Stillfin.
]
const HOLD_DURATIONS := [0.75, 0.95, 1.10]
const SURGE_DURATIONS := [0.95, 1.10, 1.20]
const RELEASE_HALF_WINDOW := [0.25, 0.22, 0.20]
const RELEASE_CUE_LEAD := 0.16
const DROWNED_LYRE_PLAYER := 30
const SOULS := [
	["忘了归途的旅人", Vector3i(5, 9, 7)],
	["对旧信无动于衷的邮差", Vector3i(8, 5, 7)],
	["迟迟不肯渡河的船工", Vector3i(8, 9, 2)],
	["听见挽歌便止不住哭的乐师", Vector3i(6, 10, 4)],
	["把每件旧事都反复推演的账房", Vector3i(10, 10, 8)],
	["不敢开口的证人", Vector3i(5, 3, 6)],
	["一想起冤情就慌了神的守门人", Vector3i(3, 10, 3)],
	["执意守着空城的将领", Vector3i(7, 6, 9)],
	["只差一句安慰的裁缝", Vector3i(8, 6, 6)],
	["忘了自己为何守誓的人", Vector3i(1, 3, 1)],
	["凡事都要算到尽头的占卜师", Vector3i(10, 7, 7)],
	["死守已经作废命令的卫兵", Vector3i(6, 7, 9)],
	["弄丢钥匙的锁匠", Vector3i(4, 9, 7)],
	["收起风筝的纸匠", Vector3i(8, 5, 4)],
	["走错站台的检票员", Vector3i(7, 9, 3)],
	["记不住曲调的吹笛人", Vector3i(2, 8, 3)],
	["迟迟不熄炉火的面包师", Vector3i(7, 8, 8)],
	["忘了把伞还回去的客人", Vector3i(6, 6, 2)],
	["舍不得拆信的抄写员", Vector3i(7, 10, 6)],
	["找不到旧地图的测绘员", Vector3i(3, 9, 3)],
	["等不到换班的守塔人", Vector3i(6, 9, 8)],
	["怕忘了潮声的采珠人", Vector3i(6, 10, 7)],
	["把账簿带过河的伙计", Vector3i(9, 7, 5)],
	["还在等开场的报幕员", Vector3i(6, 9, 2)],
	["抱着空盆的花匠", Vector3i(5, 4, 5)],
	["在桥下念判词的书记", Vector3i(9, 6, 6)],
	["记得每一场雨的瓦匠", Vector3i(10, 10, 7)],
	["仍在清点旧货的仓管", Vector3i(2, 4, 3)],
	["只记得门牌号的送货人", Vector3i(5, 8, 7)],
	["害怕钟声停下的敲钟人", Vector3i(3, 5, 1)],
	["殉情的琴手", Vector3i(8, 10, 1)],
]
# Start with cases that have simple shallow-water solutions.
const SOUL_ORDER := [
	1, 2, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 8, 0,
	5, 3, 23, 6, 24, 7, 25, 10, 26, 11, 27, 28, 29, 4, 9,
]
const LEGACY_POTION_NAMES := {"potion_01": "启明药", "potion_02": "通情药", "potion_03": "明志药", "potion_04": "锐志药", "potion_05": "澄心药", "potion_07": "锐思药", "potion_29": "清执药", "potion_30": "淡情药", "potion_31": "回情药", "potion_32": "明识药", "potion_33": "碑铭药", "potion_08": "暖心药", "potion_09": "共鸣药", "potion_10": "柔韧药", "potion_11": "感性药", "potion_13": "博识药", "potion_34": "忘忧药", "potion_35": "平情药", "potion_36": "忆情药", "potion_37": "知情药", "potion_38": "怀识药", "potion_14": "定志药", "potion_15": "决心药", "potion_16": "归心药", "potion_18": "稳识药", "potion_39": "息念药", "potion_40": "静志药", "potion_41": "余响药", "potion_42": "坚识药", "potion_43": "守碑药", "potion_19": "铁志药", "potion_20": "渡厄药", "potion_22": "明断药", "potion_44": "冷志药", "potion_45": "断情药", "potion_46": "残志药", "potion_47": "砺志药", "potion_48": "刻志药", "potion_23": "浓情药", "potion_25": "慧情药", "potion_49": "释念药", "potion_50": "缓情药", "potion_51": "返情药", "potion_52": "通魂药", "potion_53": "渡忆药", "potion_28": "极识药", "potion_54": "寒识药", "potion_55": "绝情药", "potion_56": "离执药", "potion_57": "洞识药", "potion_58": "碑悟药", "potion_59": "寂念药", "potion_60": "淡念药", "potion_61": "空响药", "potion_62": "澄识药", "potion_63": "卸执药", "potion_64": "忘情药", "potion_65": "息响药", "potion_66": "冷思药", "potion_67": "淡铭药", "potion_68": "叠响药", "potion_69": "映响药", "potion_70": "碑响药", "potion_71": "明镜药", "potion_72": "照铭药", "potion_73": "双碑药", "potion_74": "清识药", "potion_75": "温情药", "potion_76": "缓志药", "potion_77": "敛锋药", "potion_78": "栖情药", "potion_79": "三息药", "potion_80": "宁情药", "potion_81": "寂响药", "potion_82": "静识药", "potion_83": "息碑药", "potion_84": "澄骨药", "potion_85": "息志药"}


static func fish_name(species: int, size: int) -> String:
	if species == LANTERN and size == 0:
		return "凝魂幽灯鱼"
	return FISH[species]["name"]


static func fish_texture(species: int, size: int = 1) -> Texture2D:
	if species < 0 or species >= FISH.size():
		return FISH_TEXTURES["fish_01"]
	if species == LANTERN and size == 0:
		return FISH_TEXTURES["fish_03_condensed"]
	var id: String = FISH[species]["id"]
	return FISH_TEXTURES.get(id, FISH_TEXTURES["fish_01"])


static func bait_matches_fish(index: int, species: int) -> bool:
	if not ATTRIBUTE_BAITS.has(index) or species < 0 or species >= FISH.size() or species == VARIANT:
		return false
	return int(FISH[species].primary_stat) == ATTRIBUTE_BAITS[index].x


static func bait_hint(index: int, include_targets: bool = false) -> String:
	if index == Bait.DEFAULT:
		return "通用基础鱼饵"
	if index == VARIANT_BAIT:
		return "深水巨刺出现率 20%；需先解锁异刺工艺"
	if not ATTRIBUTE_BAITS.has(index):
		return ""
	var hint := "%s方向的正反两类鱼，权重 ×3" % STAT_NAMES[ATTRIBUTE_BAITS[index].x]
	if include_targets:
		var names := PackedStringArray()
		for species in FISH.size():
			if bait_matches_fish(index, species):
				names.append(FISH[species].name)
		hint += "\n" + "、".join(names)
	return hint


static func size_label(catch: Dictionary) -> String:
	var bounds: Vector2 = FISH[catch.species]["cm"]
	var length := roundf(float(catch.cm) * 10.0) / 10.0
	match int(catch.size):
		0:
			length = minf(length, bounds.x - 0.1)
		2:
			length = maxf(length, bounds.y + 0.1)
		3:
			length = maxf(length, bounds.x + 0.1)
	return "%s %.1f cm" % [SIZE_NAMES[catch.size], length]


static func recipe(first: int, second: int) -> Dictionary:
	# Mixed brewing is intentionally outside this release.
	return {}


static func recipe_key(first: int, second: int) -> String:
	if first < 0 or second < 0 or first >= FISH.size() or second >= FISH.size():
		return ""
	var ids := [FISH[first]["id"], FISH[second]["id"]]
	ids.sort()
	return "+".join(ids)


static func fish_index(id: String) -> int:
	for index in FISH.size():
		if FISH[index].id == id:
			return index
	return -1


static func effect_text(effect: Vector3i) -> String:
	var values := PackedStringArray()
	for index in 3:
		var number := effect[index]
		values.append("%s %s%d" % [STAT_NAMES[index], "+" if number > 0 else "", number])
	return "　".join(values)


static func essence_source(species: int) -> int:
	return 7 if species == STILLFIN else species


static func essence_indices() -> Array[int]:
	var result: Array[int] = []
	for species in FISH.size():
		if species != STILLFIN:
			result.append(species)
	return result


static func source_data(species: int) -> Dictionary:
	if species < 0 or species >= FISH.size():
		return {}
	var source: Dictionary = Alchemy.SOURCES.get(FISH[essence_source(species)].name, {}).duplicate(true)
	if not source.is_empty():
		source.essence = FISH[essence_source(species)].essence
	return source


static func potion_by_name(title: String) -> Dictionary:
	for potion in POTIONS.values():
		if potion.name == title:
			return potion
	return {}
