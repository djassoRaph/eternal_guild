# the_cat.gd — The Cat (Story 25.15, catalogue G11). "She was not invited. She stayed. She is a cat."
#
# The one thing she does for you: stand beside her, press E, and she lets you pet her. Usually she
# pushes her head into your hand and purrs, sits a moment, then goes back to what she was doing (asleep
# in her basket, or her stroll through town). Sometimes she only says "mrrp." and carries on.
# No autoload, no name, no story entry (FR-112, AR D11, decision F0): she is a static scene element
# with this small script. In town a parent CatStroll's AnimationPlayer walks her; petting pauses it.
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

var _player_near := false
var _cooldown := 0.0
var _settle := 0.0
var _resume_clip := ""
var _stroll: AnimationPlayer = null
var _prompt_ui: Node = null
var _prompt_label: Label3D = null   # only in scenes without a ZonePromptUI


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
			_prompt_ui.register_zone(_zone, PROMPT)
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
	_prompt_label.visible = _player_near
	add_child(_prompt_label)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _settle > 0.0:
		_settle -= delta
		if _settle <= 0.0:
			_carry_on()
	if _player_near and _cooldown <= 0.0 and Input.is_action_just_pressed("interact") and _prompt_is_mine():
		pet()


func pet() -> void:
	_cooldown = COOLDOWN
	if reaction(randf()) == "mrrp":       # she says so, and carries on with what she was doing
		_say("mrrp.")
		return
	if _settle <= 0.0 and _anim.current_animation != "Pet":   # remember what she was doing, once
		_resume_clip = _anim.current_animation if _anim.current_animation != "" else "Sleep"
		if _stroll and _stroll.is_playing():
			_stroll.pause()
	_settle = 0.0
	_anim.play("Pet")
	_say("prrr…")


func _on_clip_finished(clip: StringName) -> void:
	if clip == &"Pet":
		_anim.play("Idle")
		_settle = SETTLE_SECONDS


func _carry_on() -> void:
	_anim.play(_resume_clip if _resume_clip != "" else "Sleep")
	if _stroll and not _stroll.is_playing():
		_stroll.play()                                 # resumes where it paused


func _say(text: String) -> void:
	var bubble := PatronSpeechBubble.new()
	bubble.scale = Vector3.ONE * bubble_scale
	add_child(bubble)
	bubble.position.y = BUBBLE_HEIGHT - PatronSpeechBubble.HEAD_HEIGHT * bubble_scale
	bubble.say(text, 2.0)


## Only while hers is the prompt on screen, so one E never also presses another zone.
func _prompt_is_mine() -> bool:
	return _prompt_ui == null or _prompt_ui.get_current_zone() == _zone


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_near = true
		if _prompt_label:
			_prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_near = false
		if _prompt_label:
			_prompt_label.visible = false
