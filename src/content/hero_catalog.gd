class_name HeroCatalog
extends RefCounted

const IDS := ["placeholder_vanguard", "cheems_samurai", "sword_shield_dog", "bear_grylls_jungler", "nailoong", "chu_ying"]


static func display_name(id: String) -> String:
	match id:
		"cheems_samurai": return "cheems"
		"sword_shield_dog": return "刀盾狗"
		"bear_grylls_jungler": return "贝爷"
		"nailoong": return "奶龙"
		"chu_ying": return "褚赢"
		_: return "灰盒先锋"


static func create(id: String) -> HeroDefinition:
	match id:
		"cheems_samurai": return CheemsSamurai.create()
		"sword_shield_dog": return SwordShieldDog.create()
		"bear_grylls_jungler": return BearGryllsJungler.create()
		"nailoong": return Nailoong.create()
		"chu_ying": return ChuYing.create()
		_: return PlaceholderHero.create()
