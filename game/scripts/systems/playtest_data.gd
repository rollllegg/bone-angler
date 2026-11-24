extends RefCounted
## Fishing, QTE and potion configurations from the Feishu playtest specifications.

enum Attribute { WISDOM, EMOTION, WILL }
enum Bait { DEFAULT, WISDOM, EMOTION, WILL, FOOLISHNESS, HATRED, DAZE, VARIANT, BONE }

const FISH := [
	{"id": "fish_01", "name": "灰鳞鱼", "essence": "灰鳞原液", "effect": Vector3i(1, 0, 1), "primary_stat": Attribute.WISDOM, "cm": Vector2(2, 6), "water": [25, 0], "tier": 0},
	{"id": "fish_02", "name": "冥河鲫", "essence": "冥河原液", "effect": Vector3i(0, 2, 0), "primary_stat": Attribute.EMOTION, "cm": Vector2(8, 12), "water": [20, 10], "tier": 0},
	{"id": "fish_03", "name": "幽灯鱼", "essence": "幽灯原液", "effect": Vector3i(0, 0, 2), "primary_stat": Attribute.WILL, "cm": Vector2(18, 28), "water": [15, 15], "tier": 1},
	{"id": "fish_04", "name": "链颌鱼", "essence": "链颌原液", "effect": Vector3i(1, -1, 3), "primary_stat": Attribute.WILL, "cm": Vector2(40, 60), "water": [0, 20], "tier": 1},
	{"id": "fish_05", "name": "渡魂鲶", "essence": "渡魂原液", "effect": Vector3i(-1, 3, 1), "primary_stat": Attribute.EMOTION, "cm": Vector2(90, 120), "water": [0, 15], "tier": 2},
	{"id": "fish_06", "name": "墨眼鳉", "essence": "墨眼原液", "effect": Vector3i(-1, -1, 0), "primary_stat": Attribute.WISDOM, "cm": Vector2(3, 7), "water": [20, 0], "tier": 0},
	{"id": "fish_07", "name": "泪纹鲦", "essence": "泪纹原液", "effect": Vector3i(0, -2, 0), "primary_stat": Attribute.EMOTION, "cm": Vector2(9, 15), "water": [15, 10], "tier": 0},
	{"id": "fish_08", "name": "回声鳊", "essence": "回声原液", "effect": Vector3i(-1, 1, -2), "primary_stat": Attribute.WILL, "cm": Vector2(22, 34), "water": [5, 15], "tier": 1},
	{"id": "fish_09", "name": "镜骨鲈", "essence": "镜骨原液", "effect": Vector3i(2, 0, 1), "primary_stat": Attribute.WISDOM, "cm": Vector2(45, 65), "water": [0, 10], "tier": 1},
	{"id": "fish_10", "name": "负碑鳢", "essence": "负碑原液", "effect": Vector3i(3, 1, -1), "primary_stat": Attribute.WISDOM, "cm": Vector2(95, 130), "water": [0, 5], "tier": 2},
	# Fish indices are saved in catches and essence inventories.
	{"id": "fish_01_variant", "name": "巨刺灰鳞鱼", "essence": "巨刺原液", "effect": Vector3i(5, 0, -2), "cm": Vector2(30, 38), "water": [0, 0], "tier": -1},
	{"id": "fish_11", "name": "静鳍鳅", "essence": "静鳍原液", "effect": Vector3i(0, 0, -1), "primary_stat": Attribute.WILL, "cm": Vector2(10, 18), "water": [15, 5], "tier": 0},
]
const VARIANT := 10
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
const GRIP_QUICK_REPAIR_COST := 8
const GRIP_FULL_REPAIR_COST := 20
const SCHOOL_SPECIES := [-1, LANTERN, 4]
const BAITS := [
	"素指骨饵",
	"智慧饵", "情感饵", "意志饵", "愚笨饵", "憎恨饵", "恍惚饵",
	"异刺指骨拟饵", "遗骨饵",
]
const ATTRIBUTE_BAITS := {
	Bait.WISDOM: Vector2i(Attribute.WISDOM, 1),
	Bait.EMOTION: Vector2i(Attribute.EMOTION, 1),
	Bait.WILL: Vector2i(Attribute.WILL, 1),
	Bait.FOOLISHNESS: Vector2i(Attribute.WISDOM, -1),
	Bait.HATRED: Vector2i(Attribute.EMOTION, -1),
	Bait.DAZE: Vector2i(Attribute.WILL, -1),
}
const ATTRIBUTE_BAIT_MULTIPLIER := 3.0
const VARIANT_BAIT := Bait.VARIANT
const BONE_BAIT := Bait.BONE
# Older inventory formats, identified by the number of saved bait slots.
const LEGACY_BAIT_MAPS := {
	12: [Bait.DEFAULT, Bait.DEFAULT, Bait.DEFAULT, Bait.DEFAULT, Bait.WISDOM,
		Bait.EMOTION, Bait.WILL, Bait.FOOLISHNESS, Bait.HATRED, Bait.DAZE, Bait.VARIANT, Bait.BONE],
	16: [Bait.DEFAULT, Bait.DEFAULT, Bait.DEFAULT, Bait.DEFAULT, Bait.WISDOM,
		Bait.EMOTION, Bait.WILL, Bait.WILL, Bait.EMOTION, Bait.FOOLISHNESS,
		Bait.HATRED, Bait.DAZE, Bait.WISDOM, Bait.WISDOM, Bait.VARIANT, Bait.BONE],
}
const VARIANT_CHANCE := 0.20
const BITE_MIN := 3.0
const BITE_MODE := 5.0
const BITE_MAX := 8.0
const STARTING_COINS := 40
const STARTING_BAIT := 10
const BAIT_PRICES := [3, 9, 9, 9, 9, 9, 9, 15, 7]
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
	["忘了归途的旅人", Vector3i(5, 8, 8)],
	["对旧信无动于衷的邮差", Vector3i(8, 5, 8)],
	["迟迟不肯渡河的船工", Vector3i(8, 8, 5)],
	["听见挽歌便止不住哭的乐师", Vector3i(8, 10, 8)],
	["把每件旧事都反复推演的账房", Vector3i(10, 10, 8)],
	["不敢开口的证人", Vector3i(6, 5, 6)],
	["一想起冤情就慌了神的守门人", Vector3i(6, 10, 5)],
	["执意守着空城的将领", Vector3i(6, 6, 10)],
	["只差一句安慰的裁缝", Vector3i(8, 6, 8)],
	["忘了自己为何守誓的人", Vector3i(0, 5, 10)],
	["凡事都要算到尽头的占卜师", Vector3i(10, 8, 8)],
	["死守已经作废命令的卫兵", Vector3i(8, 8, 10)],
	["弄丢钥匙的锁匠", Vector3i(6, 8, 8)],
	["收起风筝的纸匠", Vector3i(8, 6, 8)],
	["走错站台的检票员", Vector3i(7, 8, 6)],
	["记不住曲调的吹笛人", Vector3i(6, 7, 7)],
	["迟迟不熄炉火的面包师", Vector3i(7, 9, 8)],
	["忘了把伞还回去的客人", Vector3i(6, 8, 7)],
	["舍不得拆信的抄写员", Vector3i(7, 9, 6)],
	["找不到旧地图的测绘员", Vector3i(6, 7, 8)],
	["等不到换班的守塔人", Vector3i(8, 6, 9)],
	["怕忘了潮声的采珠人", Vector3i(7, 9, 7)],
	["把账簿带过河的伙计", Vector3i(9, 6, 6)],
	["还在等开场的报幕员", Vector3i(7, 8, 9)],
	["抱着空盆的花匠", Vector3i(6, 9, 7)],
	["在桥下念判词的书记", Vector3i(9, 7, 8)],
	["记得每一场雨的瓦匠", Vector3i(9, 8, 7)],
	["仍在清点旧货的仓管", Vector3i(8, 5, 9)],
	["只记得门牌号的送货人", Vector3i(5, 8, 8)],
	["害怕钟声停下的敲钟人", Vector3i(7, 9, 9)],
	["殉情的琴手", Vector3i(8, 10, 0)],
]
# Start with cases that have simple shallow-water solutions.
const SOUL_ORDER := [
	1, 2, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 8, 0,
	5, 3, 23, 6, 24, 7, 25, 10, 26, 11, 27, 28, 29, 4, 9,
]
const RECIPES := {
	"fish_01+fish_01": {"id": "potion_01", "name": "启明药", "effect": Vector3i(2, 0, 2), "reaction": ""},
	"fish_01+fish_02": {"id": "potion_02", "name": "通情药", "effect": Vector3i(1, 2, 1), "reaction": ""},
	"fish_01+fish_03": {"id": "potion_03", "name": "明志药", "effect": Vector3i(1, 0, 3), "reaction": ""},
	"fish_01+fish_04": {"id": "potion_04", "name": "锐志药", "effect": Vector3i(2, -1, 4), "reaction": ""},
	"fish_01+fish_05": {"id": "potion_05", "name": "澄心药", "effect": Vector3i(1, 3, 2), "reaction": "中和渡魂原液智慧负值"},
	"fish_01+fish_01_variant": {"id": "potion_07", "name": "锐思药", "effect": Vector3i(6, 0, -1), "reaction": ""},
	"fish_01+fish_06": {"id": "potion_29", "name": "清执药", "effect": Vector3i(0, -1, 1), "reaction": ""},
	"fish_01+fish_07": {"id": "potion_30", "name": "淡情药", "effect": Vector3i(1, -2, 1), "reaction": ""},
	"fish_01+fish_08": {"id": "potion_31", "name": "回情药", "effect": Vector3i(0, 1, -1), "reaction": ""},
	"fish_01+fish_09": {"id": "potion_32", "name": "明识药", "effect": Vector3i(3, 0, 2), "reaction": ""},
	"fish_01+fish_10": {"id": "potion_33", "name": "碑铭药", "effect": Vector3i(4, 1, 0), "reaction": ""},
	"fish_02+fish_02": {"id": "potion_08", "name": "暖心药", "effect": Vector3i(0, 4, 0), "reaction": ""},
	"fish_02+fish_03": {"id": "potion_09", "name": "共鸣药", "effect": Vector3i(0, 2, 2), "reaction": ""},
	"fish_02+fish_04": {"id": "potion_10", "name": "柔韧药", "effect": Vector3i(1, 2, 3), "reaction": "中和链颌原液情感负值"},
	"fish_02+fish_05": {"id": "potion_11", "name": "感性药", "effect": Vector3i(-1, 5, 1), "reaction": ""},
	"fish_01_variant+fish_02": {"id": "potion_13", "name": "博识药", "effect": Vector3i(5, 2, -2), "reaction": ""},
	"fish_02+fish_06": {"id": "potion_34", "name": "忘忧药", "effect": Vector3i(-1, 1, 0), "reaction": ""},
	"fish_02+fish_07": {"id": "potion_35", "name": "平情药", "effect": Vector3i(0, 0, 0), "reaction": ""},
	"fish_02+fish_08": {"id": "potion_36", "name": "忆情药", "effect": Vector3i(-1, 3, -2), "reaction": ""},
	"fish_02+fish_09": {"id": "potion_37", "name": "知情药", "effect": Vector3i(2, 2, 1), "reaction": ""},
	"fish_02+fish_10": {"id": "potion_38", "name": "怀识药", "effect": Vector3i(3, 3, -1), "reaction": ""},
	"fish_03+fish_03": {"id": "potion_14", "name": "定志药", "effect": Vector3i(0, 0, 4), "reaction": ""},
	"fish_03+fish_04": {"id": "potion_15", "name": "决心药", "effect": Vector3i(1, -1, 5), "reaction": ""},
	"fish_03+fish_05": {"id": "potion_16", "name": "归心药", "effect": Vector3i(-1, 3, 3), "reaction": ""},
	"fish_01_variant+fish_03": {"id": "potion_18", "name": "稳识药", "effect": Vector3i(5, 0, 2), "reaction": "中和巨刺原液意志负值"},
	"fish_03+fish_06": {"id": "potion_39", "name": "息念药", "effect": Vector3i(-1, -1, 2), "reaction": ""},
	"fish_03+fish_07": {"id": "potion_40", "name": "静志药", "effect": Vector3i(0, -2, 2), "reaction": ""},
	"fish_03+fish_08": {"id": "potion_41", "name": "余响药", "effect": Vector3i(-1, 1, 0), "reaction": ""},
	"fish_03+fish_09": {"id": "potion_42", "name": "坚识药", "effect": Vector3i(2, 0, 3), "reaction": ""},
	"fish_03+fish_10": {"id": "potion_43", "name": "守碑药", "effect": Vector3i(3, 1, 1), "reaction": ""},
	"fish_04+fish_04": {"id": "potion_19", "name": "铁志药", "effect": Vector3i(2, -2, 6), "reaction": ""},
	"fish_04+fish_05": {"id": "potion_20", "name": "渡厄药", "effect": Vector3i(0, 2, 4), "reaction": ""},
	"fish_01_variant+fish_04": {"id": "potion_22", "name": "明断药", "effect": Vector3i(6, -1, 1), "reaction": ""},
	"fish_04+fish_06": {"id": "potion_44", "name": "冷志药", "effect": Vector3i(0, -2, 3), "reaction": ""},
	"fish_04+fish_07": {"id": "potion_45", "name": "断情药", "effect": Vector3i(1, -3, 3), "reaction": ""},
	"fish_04+fish_08": {"id": "potion_46", "name": "残志药", "effect": Vector3i(0, 0, 1), "reaction": ""},
	"fish_04+fish_09": {"id": "potion_47", "name": "砺志药", "effect": Vector3i(3, -1, 4), "reaction": ""},
	"fish_04+fish_10": {"id": "potion_48", "name": "刻志药", "effect": Vector3i(4, 0, 2), "reaction": ""},
	"fish_05+fish_05": {"id": "potion_23", "name": "浓情药", "effect": Vector3i(-2, 6, 2), "reaction": ""},
	"fish_01_variant+fish_05": {"id": "potion_25", "name": "慧情药", "effect": Vector3i(4, 3, -1), "reaction": ""},
	"fish_05+fish_06": {"id": "potion_49", "name": "释念药", "effect": Vector3i(-2, 2, 1), "reaction": ""},
	"fish_05+fish_07": {"id": "potion_50", "name": "缓情药", "effect": Vector3i(-1, 1, 1), "reaction": ""},
	"fish_05+fish_08": {"id": "potion_51", "name": "返情药", "effect": Vector3i(-2, 4, -1), "reaction": ""},
	"fish_05+fish_09": {"id": "potion_52", "name": "通魂药", "effect": Vector3i(1, 3, 2), "reaction": ""},
	"fish_05+fish_10": {"id": "potion_53", "name": "渡忆药", "effect": Vector3i(2, 4, 0), "reaction": ""},
	"fish_01_variant+fish_01_variant": {"id": "potion_28", "name": "极识药", "effect": Vector3i(10, 0, -4), "reaction": ""},
	"fish_01_variant+fish_06": {"id": "potion_54", "name": "寒识药", "effect": Vector3i(4, -1, -2), "reaction": ""},
	"fish_01_variant+fish_07": {"id": "potion_55", "name": "绝情药", "effect": Vector3i(5, -2, -2), "reaction": ""},
	"fish_01_variant+fish_08": {"id": "potion_56", "name": "离执药", "effect": Vector3i(4, 1, -4), "reaction": ""},
	"fish_01_variant+fish_09": {"id": "potion_57", "name": "洞识药", "effect": Vector3i(7, 0, -1), "reaction": ""},
	"fish_01_variant+fish_10": {"id": "potion_58", "name": "碑悟药", "effect": Vector3i(8, 1, -3), "reaction": ""},
	"fish_06+fish_06": {"id": "potion_59", "name": "寂念药", "effect": Vector3i(-2, -2, 0), "reaction": ""},
	"fish_06+fish_07": {"id": "potion_60", "name": "淡念药", "effect": Vector3i(-1, -3, 0), "reaction": ""},
	"fish_06+fish_08": {"id": "potion_61", "name": "空响药", "effect": Vector3i(-2, 0, -2), "reaction": ""},
	"fish_06+fish_09": {"id": "potion_62", "name": "澄识药", "effect": Vector3i(1, -1, 1), "reaction": ""},
	"fish_06+fish_10": {"id": "potion_63", "name": "卸执药", "effect": Vector3i(2, 0, -1), "reaction": ""},
	"fish_07+fish_07": {"id": "potion_64", "name": "忘情药", "effect": Vector3i(0, -4, 0), "reaction": ""},
	"fish_07+fish_08": {"id": "potion_65", "name": "息响药", "effect": Vector3i(-1, -1, -2), "reaction": ""},
	"fish_07+fish_09": {"id": "potion_66", "name": "冷思药", "effect": Vector3i(2, -2, 1), "reaction": ""},
	"fish_07+fish_10": {"id": "potion_67", "name": "淡铭药", "effect": Vector3i(3, -1, -1), "reaction": ""},
	"fish_08+fish_08": {"id": "potion_68", "name": "叠响药", "effect": Vector3i(-2, 2, -4), "reaction": ""},
	"fish_08+fish_09": {"id": "potion_69", "name": "映响药", "effect": Vector3i(1, 1, -1), "reaction": ""},
	"fish_08+fish_10": {"id": "potion_70", "name": "碑响药", "effect": Vector3i(2, 2, -3), "reaction": ""},
	"fish_09+fish_09": {"id": "potion_71", "name": "明镜药", "effect": Vector3i(4, 0, 2), "reaction": ""},
	"fish_09+fish_10": {"id": "potion_72", "name": "照铭药", "effect": Vector3i(5, 1, 0), "reaction": ""},
	"fish_10+fish_10": {"id": "potion_73", "name": "双碑药", "effect": Vector3i(6, 2, -2), "reaction": ""},
	"fish_01+fish_11": {"id": "potion_74", "name": "清识药", "effect": Vector3i(1, 0, 0), "reaction": ""},
	"fish_02+fish_11": {"id": "potion_75", "name": "温情药", "effect": Vector3i(0, 2, -1), "reaction": ""},
	"fish_03+fish_11": {"id": "potion_76", "name": "缓志药", "effect": Vector3i(0, 0, 1), "reaction": ""},
	"fish_04+fish_11": {"id": "potion_77", "name": "敛锋药", "effect": Vector3i(1, -1, 2), "reaction": ""},
	"fish_05+fish_11": {"id": "potion_78", "name": "栖情药", "effect": Vector3i(-1, 3, 0), "reaction": ""},
	"fish_06+fish_11": {"id": "potion_79", "name": "三息药", "effect": Vector3i(-1, -1, -1), "reaction": ""},
	"fish_07+fish_11": {"id": "potion_80", "name": "宁情药", "effect": Vector3i(0, -2, -1), "reaction": ""},
	"fish_08+fish_11": {"id": "potion_81", "name": "寂响药", "effect": Vector3i(-1, 1, -3), "reaction": ""},
	"fish_09+fish_11": {"id": "potion_82", "name": "静识药", "effect": Vector3i(2, 0, 0), "reaction": ""},
	"fish_10+fish_11": {"id": "potion_83", "name": "息碑药", "effect": Vector3i(3, 1, -2), "reaction": ""},
	"fish_01_variant+fish_11": {"id": "potion_84", "name": "澄骨药", "effect": Vector3i(5, 0, -3), "reaction": ""},
	"fish_11+fish_11": {"id": "potion_85", "name": "息志药", "effect": Vector3i(0, 0, -2), "reaction": ""},
}


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
	var rule: Vector2i = ATTRIBUTE_BAITS[index]
	var fish: Dictionary = FISH[species]
	var effect: Vector3i = fish.effect
	if rule.y > 0:
		return fish.primary_stat == rule.x and effect[rule.x] > 0
	return effect[rule.x] < 0


static func bait_hint(index: int, include_targets: bool = false) -> String:
	match index:
		Bait.DEFAULT:
			return "通用基础鱼饵"
		VARIANT_BAIT:
			return "深水触发巨刺异变"
		BONE_BAIT:
			return "大幅提高遗骨概率"
	if not ATTRIBUTE_BAITS.has(index):
		return ""
	var rule: Vector2i = ATTRIBUTE_BAITS[index]
	var direction := "提升" if rule.y > 0 else "降低"
	var hint := "%s%s的鱼，权重 ×%d" % [direction, STAT_NAMES[rule.x], int(ATTRIBUTE_BAIT_MULTIPLIER)]
	if not include_targets:
		return hint
	var names := PackedStringArray()
	for species in FISH.size():
		if bait_matches_fish(index, species):
			names.append(FISH[species].name)
	return hint + "\n" + "、".join(names)


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
	return RECIPES.get(recipe_key(first, second), {})


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
