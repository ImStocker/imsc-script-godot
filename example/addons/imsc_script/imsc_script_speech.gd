class_name ImscScriptSpeech
extends RefCounted

var character: String
var text: String
var values: Dictionary
var options: Array[ImscScriptSpeechOption]


func _init(p_values: Dictionary, p_options: Array = []):
	character = ""
	text = ""
	values = p_values
	options = []
	for opt in p_options:
		if opt is ImscScriptSpeechOption:
			options.append(opt)
