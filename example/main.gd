extends Node2D


@onready var _speaker: Label = $CanvasLayer/UI/SpeakerLabel
@onready var _dialogue: RichTextLabel = $CanvasLayer/UI/DialogueLabel
@onready var _options: VBoxContainer = $CanvasLayer/UI/OptionsContainer
@onready var _prompt: Label = $CanvasLayer/UI/PromptLabel
@onready var _restart_btn: Button = $CanvasLayer/UI/RestartBtn
@onready var _location: Sprite2D = $CurrentLocation
@onready var _character: Sprite2D = $CurrentCharacter


var player: ImscScriptPlayer
var _waiting_for_choice: bool = false
var _full_text: String = ""
var _reveal_index: int = 0
var _tween: Tween

func _read_script():
	var file = "res://Missing Mousse.ima.json"
	var json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(json_as_text)
	return json_as_dict["values"]["content"]


func _ready():
	_prompt.text = ""
	var graph = _read_script()
	player = ImscScriptPlayer.new(graph)
	player.on_speech.connect(_on_speech)
	player.on_action.connect(_on_action)
	player.on_load_script.connect(_on_load_script)
	player.on_end.connect(_on_end)
	player.on_error.connect(_on_error)
	player.on_choice.connect(_on_choice)
	player.on_variable_change.connect(_on_variable_change)
	player.on_node_enter.connect(_on_node_enter)
	_restart_btn.pressed.connect(_restart)
	player.play()


func _on_speech(speech: ImscScriptSpeech, node_info: Dictionary):
	_speaker.text = speech.character
	_full_text = speech.text
	_dialogue.text = ""
	_prompt.text = ""
	_reveal_index = 0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_reveal_char, 0.0, float(_full_text.length()), _full_text.length() * 0.025)
	_tween.finished.connect(_on_reveal_done)
	_clear_options()
	if speech.options.size() > 0:
		_waiting_for_choice = true
		for opt in speech.options:
			var label_text = opt.text if not opt.text.is_empty() else "Option %d" % opt.index
			var btn = Button.new()
			btn.text = label_text
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var idx = opt.index
			btn.pressed.connect(func():
				player.advance(idx)
			)
			_options.add_child(btn)
	else:
		_waiting_for_choice = false


func _reveal_char(count: float):
	var n = int(count)
	if n > _reveal_index:
		_reveal_index = n
		_dialogue.text = _full_text.left(_reveal_index)


func _on_reveal_done():
	_dialogue.text = _full_text
	if not _waiting_for_choice:
		_prompt.text = "Press Enter to continue"


func _clear_options():
	for child in _options.get_children():
		child.queue_free()


func _on_action(resume: Callable, action_type: String, subject: String, inputs: Dictionary, node_info: Dictionary):
	match subject:
		"changeLocation":
			var name: String = inputs.get("location", {}).get("Name", "")
			if not name.is_empty():
				_location.texture = load("res://images/%s.png" % name)
			_character.visible = false
		"showCharacter":
			var name: String = inputs.get("character", {}).get("Name", "")
			if not name.is_empty():
				_character.texture = load("res://images/%s.png" % name)
			_character.visible = true
		"hideCharacter":
			_character.visible = false
	resume.call({"outputs": {}})


func _on_load_script(resume: Callable, script_id: String):
	resume.call(null)


func _on_choice(option_index: int, node_info: Dictionary):
	_waiting_for_choice = false
	_prompt.text = ""
	if _tween:
		_tween.kill()


func _on_end():
	_speaker.text = ""
	_dialogue.text = "[color=gray]Dialogue ended[/color]"
	_prompt.text = ""
	_restart_btn.visible = true


func _restart():
	_restart_btn.visible = false
	_character.visible = false
	var graph = _read_script()
	player = ImscScriptPlayer.new(graph)
	player.on_speech.connect(_on_speech)
	player.on_action.connect(_on_action)
	player.on_load_script.connect(_on_load_script)
	player.on_end.connect(_on_end)
	player.on_error.connect(_on_error)
	player.on_choice.connect(_on_choice)
	player.on_variable_change.connect(_on_variable_change)
	player.on_node_enter.connect(_on_node_enter)
	player.play()


func _on_error(message: String):
	_dialogue.text = "[color=red]ERROR: %s[/color]" % message


func _on_variable_change(variable: String, new_value, old_value, frame_index: int):
	print("Var %s: %s -> %s (frame %d)" % [variable, old_value, new_value, frame_index])


func _on_node_enter(inputs: Dictionary, options_inputs: Array, node_info: Dictionary):
	print("Enter %s inputs=%s" % [node_info.node_id, inputs])


func _reveal_all():
	if _tween:
		_tween.kill()
	_dialogue.text = _full_text
	_reveal_index = _full_text.length()
	if not _waiting_for_choice:
		_prompt.text = "Press Enter to continue"

 
func _input(event):
	if not player.is_running:
		return
	if event.is_action_pressed(&"ui_accept"):
		if _waiting_for_choice:
			pass
		elif not _full_text.is_empty() and _reveal_index < _full_text.length():
			_reveal_all()
			get_viewport().set_input_as_handled()
		else:
			player.advance()
			get_viewport().set_input_as_handled()
	for i in range(10):
		if event is InputEventKey and event.pressed and event.keycode == KEY_0 + i:
			if _waiting_for_choice:
				player.advance(i)
				get_viewport().set_input_as_handled()
