extends RefCounted
## Supplementary display feedback only. BVN shake pulses, source freeze,
## actor clocks, input and HitVOs remain owned by their original adapters.
const CONTACT_TAIL_SECONDS: float = .055

static func contact_gain(remaining: float) -> float:
	var t: float = clampf(remaining / CONTACT_TAIL_SECONDS, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func needs_air_fit(actors: Array) -> bool:
	for actor: Variant in actors:
		if actor.visible and not actor.grounded and actor.state in ["hurt", "juggle", "launch", "slam"] and not actor.last_source_hurt_hit.is_empty():
			return true
	return false
