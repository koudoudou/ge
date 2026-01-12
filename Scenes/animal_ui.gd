extends CanvasLayer
class_name AnimalUi

@onready var panel: PanelContainer = $PanelContainer
@onready var name_label: Label = $PanelContainer/VBoxContainer/Name
@onready var state_label: Label = $PanelContainer/VBoxContainer/State
@onready var hunger_bar: ProgressBar = $PanelContainer/VBoxContainer/Hunger
@onready var thirst_bar: ProgressBar = $PanelContainer/VBoxContainer/Thirst
@onready var close_btn: Button = $PanelContainer/VBoxContainer/Exit

var current: Node = null

func _ready() -> void:
	panel.visible = false
	close_btn.pressed.connect(_close)

	_connect_existing()
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	_try_connect(n)

func _connect_existing() -> void:
	for g in ["Prey", "Predator"]:
		for n in get_tree().get_nodes_in_group(g):
			_try_connect(n)

func _try_connect(n: Node) -> void:
	if n == null:
		return
	if (n.is_in_group("Prey") or n.is_in_group("Predator")) and n.has_signal("selected"):
		# Avoid duplicate connections
		if not n.selected.is_connected(_on_animal_selected):
			n.selected.connect(_on_animal_selected)

func _on_animal_selected(a: Node) -> void:
	current = a
	panel.visible = true
	_refresh()

func _process(_delta: float) -> void:
	if not panel.visible:
		return
	if current == null or not is_instance_valid(current):
		_close()
		return
	_refresh()

func _refresh() -> void:
	name_label.text = current.name

	if current.has_method("get_state_name"):
		state_label.text = "State: %s" % current.call("get_state_name")
	else:
		state_label.text = "State: Unknown"

	var h := 0.0
	var t := 0.0
	if current.has_method("get_hunger_01"):
		h = float(current.call("get_hunger_01"))
	if current.has_method("get_thirst_01"):
		t = float(current.call("get_thirst_01"))

	hunger_bar.value = clamp(h, 0.0, 1.0) * 100.0
	thirst_bar.value = clamp(t, 0.0, 1.0) * 100.0

func _close() -> void:
	panel.visible = false
	current = null
