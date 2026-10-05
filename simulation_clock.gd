extends RefCounted
## Reconstructed fixed-step clock. This is not a recovered historical file.
## Wall time is accepted only while running; stalls never enqueue more than 8 ticks.

const STEP: float = 0.05
const MAX_STEPS: int = 8
const MAX_CATCHUP: float = STEP * MAX_STEPS
const EPSILON: float = 0.000000001
var remainder: float = 0.0

func reset() -> void:
	remainder = 0.0

func take_steps(real_delta: float, running: bool = true) -> int:
	if not running:
		reset()
		return 0
	if not is_finite(real_delta) or real_delta <= 0.0:
		return 0
	remainder = minf(remainder + real_delta, MAX_CATCHUP)
	var count: int = mini(MAX_STEPS, int(floor((remainder + EPSILON) / STEP)))
	remainder = maxf(0.0, remainder - count * STEP)
	return count
