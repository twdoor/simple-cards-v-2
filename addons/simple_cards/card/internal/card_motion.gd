## Internal motion implementation. State stays on Card; this helper owns no nodes.
@tool
class_name CardMotion extends RefCounted

func tween_scale(card: Card, desired_scale: Vector2 = Vector2.ONE, duration: float = 0.2) -> void:
	if card._scale_tween:
		card._scale_tween.kill()
	card._scale_tween = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	card._scale_tween.tween_property(card, "scale", desired_scale, duration)

func tween_rotation(card: Card, desired_rotation: float = 0, duration: float = 0.2) -> void:
	if card._rotation_tween:
		card._rotation_tween.kill()
	card._rotation_tween = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	card._rotation_tween.tween_property(card, "rotation_degrees", desired_rotation, duration)

func tween_position(card: Card, desired_position: Vector2, duration: float = .3, global: bool = false) -> void:
	if card._pos_tween:
		card._pos_tween.kill()

	if duration <= 0.0:
		if global:
			card.global_position = desired_position
		else:
			card.position = desired_position
		card._queue_interaction_state_sync()
		return

	card._pos_tween = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if global:
		card._pos_tween.tween_property(card, "global_position", desired_position, duration)
	else:
		card._pos_tween.tween_property(card, "position", desired_position, duration)
	if card._pos_tween:
		card._pos_tween.finished.connect(card._queue_interaction_state_sync, CONNECT_ONE_SHOT)

func tween_to_container_position(card: Card, target: CardContainer, target_position: Vector2, duration: float = .3, emit_complete: bool = false) -> void:
	if card._pos_tween:
		card._pos_tween.kill()
		card._pos_tween = null
	if duration <= 0.0:
		card.position = target_position
		card._queue_interaction_state_sync()
		if emit_complete:
			card.move_completed.emit(card)
		return

	var from_center := card.get_global_transform() * card.pivot_offset
	card._pos_tween = card.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	card._pos_tween.tween_method(func(weight: float) -> void:
		if !is_instance_valid(target):
			return
		# Interpolate the visual center so rotation cannot shift the path or
		# make the final local-position assignment snap at a different endpoint.
		var target_center: Vector2 = target.get_global_transform() * (target_position + card.pivot_offset)
		card.global_position = from_center.lerp(target_center, weight) - card.get_global_transform().basis_xform(card.pivot_offset)
	, 0.0, 1.0, duration)
	if card._pos_tween:
		card._pos_tween.finished.connect(func():
			card.position = target_position
			card._queue_interaction_state_sync()
			if emit_complete:
				card.move_completed.emit(card)
		, CONNECT_ONE_SHOT)

func kill_all_tweens(card: Card) -> void:
	if card._scale_tween:
		card._scale_tween.kill()
		card._scale_tween = null
	if card._rotation_tween:
		card._rotation_tween.kill()
		card._rotation_tween = null
	if card._pos_tween:
		card._pos_tween.kill()
		card._pos_tween = null
