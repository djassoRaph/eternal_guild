# the_cat.gd — The Cat (Story 25.15, catalogue G11). "She was not invited. She stayed. She is a cat."
#
# The one thing she does for you: stand beside her, press E, and she lets you pet her. Usually she
# pushes her head into your hand and purrs, sits a moment, then goes back to what she was doing (asleep
# in her basket, or her stroll through town). Sometimes she only says "mrrp." and carries on.
# No autoload, no name, no story entry (FR-112, AR D11, decision F0): she is a static scene element
# with this small script. In town a parent CatStroll's AnimationPlayer walks her; petting pauses it.
#
# One E never does two things (Story 25.10, J6): she claims her PetZone with the scene's ZonePromptUI,
# which gives E and the prompt to the NEAREST zone the player stands in (the hearth's fire and Den Fa
# are a step away) and closes E for everyone while a patron waits in range, the tree is paused, it is
# Game Over or a mission screen is open. She pets only while owns_e(PetZone); her own live checks stay
# as a second guard. Where there's no ZonePromptUI, a Label3D over her is her prompt.
extends Node3D

const PURR_CHANCE := 0.75        # the rest of the time: "mrrp."
const PROMPT := "Press E - Pet the cat"
const COOLDOWN := 3.0            # seconds before she can be petted again
const SETTLE_SECONDS := 4.0      # she sits up (Idle) this long after the pet, then carries on
const BUBBLE_HEIGHT := 1.0       # metres above her origin (the patron bubble is set for a head at 2.45)

## The town camera is about twice as wide as the tavern's: her town instance sets 1.5, as villagers use.
@export var bubble_scale := 1.0

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _zone: Area3D = $PetZone

var _player: Node3D = null         # the player, while inside her PetZone
var _cooldown := 0.0
var _settle := 0.0
var _resume_clip := ""
var _stroll: AnimationPlayer = null
var _paused_stroll := false        # true only while SHE holds the stroll paused
var _prompt_ui: Node = null
var _prompt_label: Label3D = null  # only in scenes without a ZonePromptUI
var _prompt_shown := false


## "purr" below PURR_CHANCE, else "mrrp" (roll in [0, 1)).
static func reaction(roll: float) -> String:
	return "purr" if roll < PURR_CHANCE else "mrrp"


func _ready() -> void:
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)
	_anim.animation_finished.connect(_on_clip_finished)
	for c in get_parent().get_children():            # in town: CatStroll's player moves her
		if c is AnimationPlayer:
			_stroll = c
	# The scene adds its ZonePromptUI in its own _ready (the tavern after two frames), so look for a while.
	for i in 30:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_prompt_ui = preload("res://scripts/game/ZonePromptUI.gd").find(get_tree())
		if _prompt_ui:
			_prompt_ui.claim(_zone, PROMPT, self)
			return
	# No ZonePromptUI in this scene: a small prompt over her instead, in its yellow.
	_prompt_label = Label3D.new()
	_prompt_label.text = PROMPT
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.pixel_size = 0.005
	_prompt_label.font_size = 40
	_prompt_label.outline_size = 10
	_prompt_label.modulate = Color(1, 1, 0)
	_prompt_label.position = Vector3(0, 1.3, 0)
	_prompt_label.visible = false
	add_child(_prompt_label)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _settle > 0.0:
		_settle -= delta
		if _settle <= 0.0:
			_carry_on()
	_show_prompt(can_be_petted())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and _cooldown <= 0.0 and can_be_petted():
		get_viewport().set_input_as_handled()
		pet()


## The player is beside her and E is hers: the prompt UI's owner (nearest zone, gate open), and her
## own live checks agree.
func can_be_petted() -> bool:
	if _player == null or not is_instance_valid(_player) or not is_inside_tree() or get_tree().paused:
		return false
	if _prompt_ui != null and is_instance_valid(_prompt_ui) and not _prompt_ui.owns_e(_zone):
		return false
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("game_over_active"):
		return false
	for board in get_tree().get_nodes_in_group("mission_board"):
		if board.visible:
			return false
	for p in get_tree().get_nodes_in_group("patrons"):   # zone_interactions serves them first on E
		if p.has_method("can_be_served_by") and p.can_be_served_by(_player.global_position):
			return false
	return true


func pet() -> void:
	_cooldown = COOLDOWN
	if reaction(randf()) == "mrrp":       # she says so, and carries on with what she was doing
		_say("mrrp.")
		return
	if _settle <= 0.0 and _anim.current_animation != "Pet":   # remember what she was doing, once
		_resume_clip = _anim.current_animation if _anim.current_animation != "" else "Sleep"
		if _stroll and _stroll.is_playing():
			_stroll.pause()
			_paused_stroll = true
	_settle = 0.0
	_anim.play("Pet")
	_say("prrr…")


func _on_clip_finished(clip: StringName) -> void:
	if clip == &"Pet":
		_anim.play("Idle")
		_settle = SETTLE_SECONDS


func _carry_on() -> void:
	_anim.play(_resume_clip if _resume_clip != "" else "Sleep")
	if _paused_stroll and _stroll:
		_paused_stroll = false
		_stroll.play()                                 # resumes where it paused


func _say(text: String) -> void:
	var bubble := PatronSpeechBubble.new()
	bubble.scale = Vector3.ONE * bubble_scale
	add_child(bubble)
	bubble.position.y = BUBBLE_HEIGHT - PatronSpeechBubble.HEAD_HEIGHT * bubble_scale
	bubble.say(text, 2.0)


## Her Label3D prompt, only in scenes without a ZonePromptUI (with one, the UI shows her claimed prompt).
func _show_prompt(want: bool) -> void:
	# With a ZonePromptUI the prompt is its job (she claimed PetZone); this is only the Label3D fallback.
	if want == _prompt_shown:
		return
	_prompt_shown = want
	if _prompt_label:
		_prompt_label.visible = want


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
