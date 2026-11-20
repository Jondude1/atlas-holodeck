class_name Ease
## Round 2 (R2-3): ONE easing language for the whole app, so no motion
## feels mechanical by accident. Positional/scale motion uses cubic-out;
## fades and shader params use sine in-out. New tweens call Ease.mv() /
## Ease.fd() on their Tweener instead of picking curves ad hoc.
## (Deliberate exceptions stay: the panel reveal's TRANS_BACK pop and
## the boot ring's staged sine fill are designed beats, not defaults.)

static func mv(tw: Tweener) -> Tweener:
	return tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func fd(tw: Tweener) -> Tweener:
	return tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
