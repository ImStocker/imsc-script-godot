# ImscScript Godot

Lightweight Godot 4 addon to play dialogues and visual scripts using simple [JSON schema](./docs/graph-schema.md)

You can use [**IMS Creators**](https://ims.cr5.space/) ([Desktop version](https://github.com/ImStocker/ims-creators)) to create ready-to-use dialogue graphs in a visual editor.

Works with any Godot 4 project and provides full control over dialog flow, branching, variables, triggers, and serialization.

## Features

- 🎭 **Speech nodes** with optional choices (branching dialogs)
- 🔀 **Conditional branching** based on variables or expressions
- 📦 **Variable management** – set, get, and use in conditions
- ⚡ **Trigger / Function nodes** – invoke game logic and receive outputs
- 💾 **Serializable state** – save/load, undo/redo, replay
- 📝 **Expression evaluation** – math, comparison, and logical operators
- 🧩 **Async support** – triggers can be asynchronous
- 📜 **Sub‑scripts** – `callScript` nodes run nested graphs with isolated variables and `in`/`out` data flow
- 🧰 **Custom nodes** – register your own exec (flow) or data (expression) node types via `register_custom_node`
- ⏸️ **Pause/Resume** – pause execution during triggers or user input

## Installation

Copy the `addons/imsc_script` folder into your Godot project's `addons/` directory. The `class_name` declarations in each script make the types available globally — no plugin enabling required.

## Usage

### 1. Create a JSON graph from scratch or export script from IMS Creators

A graph is a JSON object with a `start` node ID and a `nodes` dictionary. Each node has a `type` field and an ID of the next node (`next` field, or `options` if it has multiple output variants). Nodes can have input data in a `values` field, where each value can be a fixed value or a link to another node's output via `{ "get": "nodeId", "param": "outputName" }`. See the [JSON schema](./docs/graph-schema.md) for the full specification.

Example of graph:

```json
{
  "start": "greeting",
  "nodes": {
    "greeting": {
      "type": "speech",
      "values": {
        "character": "Guard",
        "text": "Hello!"
      },
      "next": "ask"
    },
    "ask": {
      "type": "speech",
      "values": {
        "character": "Guard",
        "text": "What do you want?"
      },
      "options": [
        { "values": { "text": "I seek adventure." }, "next": "adventure" },
        { "values": { "text": "I want to trade." }, "next": "trade" },
        { "values": { "text": "Nothing, goodbye." }, "next": "end" }
      ]
    },
    "trade": {
      "type": "trigger",
      "subject": "trade",
      "next": "ask"
    },
    "adventure": {
      "type": "speech",
      "values": {
        "character": "Guard",
        "text": "Then go east, brave soul!"
      },
      "next": "end"
    },
    "end": { "type": "end" }
  }
}
```

You can also export graphs as JSON from [IMS Creators](https://ims.cr5.space/) — use the `computed` content of a script block as the graph input.

<img width="800" alt="image" src="https://github.com/user-attachments/assets/ad6d752e-f23f-4874-9d0b-71584a7d71fb" />

Example of exported file:

```js
{
  "id": "some uuid",
  "blocks": [
    {
      "id": "some uuid",
      "type": "script",
      "computed": {
        //
        // Here is a graph
        //
      }
      // ...
    }
    // ...
  ]
  // ...
}
```

### 2. Initialize and play

```gdscript
var player = ImscScriptPlayer.new(my_dialog_graph)
player.init_variables({ "customVar": 42 }) # overrides graph default values

player.on_speech.connect(func(speech, _node_info):
    # speech.character, speech.text, speech.options
    print("%s: %s" % [speech.character, speech.text])
    if speech.options.size() > 0:
        # Show choice buttons
        # Call player.advance(option_index) on button press
        pass
    else:
        # Show "Continue" button
        # Call player.advance() on button press
        pass
)

player.on_action.connect(func(resume, action_type, subject, inputs, _node_info):
    # Handle game logic (e.g., give item, play sound)
    print("Action: %s - %s" % [action_type, subject])
    # Return outputs and optionally override the next node
    resume.call({ "outputs": { "success": true, "reward": 100 } })
)

player.on_end.connect(func():
    print("Dialog finished")
)

await player.play()
```

### 3. Control the dialog from your UI

```gdscript
# When a speech node without options appears, call after user clicks "Continue"
player.advance()

# When a speech node with options appears, call with the selected option index
player.advance(selected_index)

# Jump to any node
player.goto("node_id")

# Pause/resume execution
player.pause()
player.resume()
```

## API Reference

### Constructor

```gdscript
ImscScriptPlayer.new(graph: Dictionary, script_id: String = "")
```

| Parameter | Type | Description |
| --- | --- | --- |
| `graph` | `Dictionary` | The script graph JSON. |
| `script_id` | `String` | Optional identifier for this script instance. |

### Properties

| Property | Type | Description |
| --- | --- | --- |
| `is_running` | `bool` | `true` if a dialog is currently playing (not ended). |
| `is_paused` | `bool` | `true` if the dialog is paused. |
| `current_node` | `Dictionary` or `null` | The currently active graph node. |
| `current_node_id` | `String` or `null` | ID of the currently active node. |
| `variables` | `Dictionary` | Current frame's variable values (read‑only). |
| `globals` | `Dictionary` | Global variable values shared across all frames (read‑only). |
| `frames` | `Array[ImscScriptFrame]` | Frame stack (current frame is index 0). |

### Methods

| Method | Description |
| --- | --- |
| `play(start_node_id: String = null)` | Starts the dialog from the graph's start node (or a specific node). Returns a Signal that completes when the dialog ends. |
| `pause()` | Pauses execution. The dialog will not advance until `resume()` or `advance()` is called. |
| `resume()` | Resumes execution without advancing. |
| `advance(option_index: int = null, resume_after: bool = false)` | Advances to the next node from a speech node (with `option_index` selects that choice). If `resume_after` is true, unpauses execution. |
| `goto(node_id: String)` | Jumps to a specific node (or ends if `null`). |
| `end()` | Ends the current dialog. |
| `init_variables(vars: Dictionary)` | Bulk-initializes variables before play. Globals go to `_global_variables`, others to the root frame. |
| `set_variable(key: String, value, frame_index: int = 0)` | Sets a runtime variable at the given frame index. |
| `get_variable(key: String, frame_index: int = 0)` | Gets a runtime variable. |
| `serialize()` → `Dictionary` | Returns the current state (frame stack, globals). |
| `load_state(state: Dictionary)` | Restores a previously serialized state. |
| `register_custom_node(type_name: String, kind: String, handler: Callable)` | Registers a handler for a custom node type. `kind` is `"exec"` (flow node) or `"data"` (expression node). |
| `inspect_graph(callback: Callable, start_node_id: String = null)` | Walks over script graph nodes. Allows checking consequences of a choice without actually playing. |

### Signals

Connect to these signals using `player.signal_name.connect(handler)`.

| Signal | Handler Arguments | Description |
| --- | --- | --- |
| `on_start` | `()` | Dialog started. |
| `on_end` | `()` | Dialog ended. |
| `on_node_before_enter` | `(node_info: Dictionary)` | Called before node inputs are evaluated. |
| `on_node_evaluated` | `(resume: Callable, inputs: Dictionary, options_inputs: Array, node_info: Dictionary)` | Node input values have been evaluated. Call `resume({ inputs: ..., options_inputs: ... })` to modify them. |
| `on_node_enter` | `(inputs: Dictionary, options_inputs: Array, node_info: Dictionary)` | Player entered a node. |
| `on_node_exit` | `(node_info: Dictionary)` | Exited a node. |
| `on_speech` | `(speech: ImscScriptSpeech, node_info: Dictionary)` | A speech node is active. `speech` contains `character`, `text`, `values`, and `options` (array of `ImscScriptSpeechOption`). |
| `on_choice` | `(option_index: int, node_info: Dictionary)` | User selected a choice (fired before moving to the next node). |
| `on_action` | `(resume: Callable, action_type: String, subject: String, inputs: Dictionary, node_info: Dictionary)` | A trigger or function node is active. `action_type` is `"trigger"` or `"function"`. Call `resume({ outputs: ..., next: ... })` to return outputs and optionally override the next node. |
| `on_load_script` | `(resume: Callable, script_id: String)` | Load a sub‑script by ID when a `callScript` node is activated. Call `resume(graph_dict)` with the sub‑graph. |
| `on_sub_script_enter` | `(frame: ImscScriptFrame)` | A sub‑script frame was pushed onto the stack. |
| `on_sub_script_exit` | `(frame: ImscScriptFrame)` | A sub‑script frame was popped from the stack. |
| `on_variable_change` | `(variable: String, new_value, old_value, frame_index: int)` | A variable changed in a frame. |
| `on_error` | `(error_message: String)` | An error occurred. |
| `on_state_change` | `(state: Dictionary)` | State changed (useful for auto‑saving). |

### Value-returning signals (`resume` Callable)

Signals that expect a return value pass a `resume` Callable as the first argument. You **must** call `resume(data)` to unblock the player:

```gdscript
player.on_action.connect(func(resume, action_type, subject, inputs, _node_info):
    var result = do_something(inputs)
    resume.call({ "outputs": { "value": result } })
)

player.on_load_script.connect(func(resume, script_id):
    var sub_graph = load_sub_graph(script_id)
    resume.call(sub_graph)
)

player.on_node_evaluated.connect(func(resume, inputs, options_inputs, _node_info):
    inputs.custom = "modified"
    resume.call({ "inputs": inputs })
)
```

If no handler is connected, defaults apply (no outputs, no sub‑graph, original inputs).

## State Serialization (Save / Load)

```gdscript
# Save
var saved_state = player.serialize()
var json = JSON.stringify(saved_state)
FileAccess.save_file("user://save.json", json)

# Load later
var json = FileAccess.get_file_as_string("user://save.json")
var loaded_state = JSON.parse_string(json)
player.load_state(loaded_state)
```

## License

MIT

## Links

- [IMS Creators](https://ims.cr5.space/) – The visual editor for creating dialogs and scripts (both web and [desktop](https://ims.cr5.space/desktop) version)
- [IMS Creators Desktop source code](https://github.com/ImStocker/ims-creators)
- [Original TypeScript library](https://github.com/ImStocker/imsc-script-js)

## Contributing

Issues and pull requests are welcome. Please ensure your code passes the existing tests and follows the coding style.
