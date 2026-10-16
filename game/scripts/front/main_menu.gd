extends Control



signal chosen(id: String)

var list: PkMenuList
var card: PkInfoCard
var _win: PkWindow


func _init() -> void :
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win = PkWindow.new()
	_win.position = Vector2(90, 330)
	_win.custom_minimum_size = Vector2(320, 0)
	add_child(_win)
	list = PkMenuList.new()
	list.cancellable = false
	list.chosen.connect( func(id): chosen.emit(id))
	_win.add_child(list)
	card = PkInfoCard.new()
	card.title = "CONTINUE"
	card.position = Vector2(440, 330)
	card.custom_minimum_size = Vector2(380, 0)
	card.visible = false
	add_child(card)
	visible = false


func open(save: Dictionary) -> void :
	var items: = []
	if not save.is_empty():
		items.append({"id": "continue", "label": "CONTINUE"})
	items += [{"id": "new_game", "label": "NEW GAME"}, {"id": "options", "label": "OPTIONS"}, 
		{"id": "credits", "label": "CREDITS"}]
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		items.append({"id": "quit", "label": "QUIT"})
	list.set_items(items)
	card.visible = not save.is_empty()
	if card.visible:
		card.set_rows(SaveGame.summary_rows(save))
	visible = true
	UiKit.pop_in(_win)
	if card.visible:
		UiKit.pop_in(card)
	list.active = true
