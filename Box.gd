
# Box
#
#
# ** MÉTHODES *****************************************
#
# append ..............	Ajoute une ligne
# clear ...............	Supprime toutes les lignes
# compute_height ......	Récupére la hauteur utile
# reload_settings .....	Recharge les paramètres de l'éditeur
#
#.............................................................................................................

extends Panel

#.............................................................................................................

const _CAPACITY = 4
const _HIGHLIGHTED_NUMBERED_LINE = "[color=#%s]%0*d[/color] %s[color=#%s]%s[/color]%s"
const _HIGHLIGHTED_LINE = "%s[color=#%s]%s[/color]%s"
const _NUMBERED_LINE = "%0*d %s"
const _TEXT_EDITOR = "text_editor/%s"
const _CLICK = "click"
const _TOP_MARGIN = 2
const _LEFT_MARGIN = 13
const _BORDER = 1

var _plugin # WeakRef<NestedCodeBox.gd>
var _lines # [Line]
var _line_height # int
var _skin # StyleBoxFlat
var _font # Font
var _line_number_color # String
var _keyword_color # String
var _text_color # Color
var _syntax_highlighting # bool
var _show_line_numbers # bool
var _trash # [Line]

#.............................................................................................................

# Ajoute une ligne.

func append(line, code, keyword_begin, keyword_end): # int, String, int, int

	var s = code
	var d = _plugin.get_ref().digits
	var i = 0
	var l
	var n = get_child_count() # l'ordre dans lines n'a pas d'influence

	for i in _lines: # Line

		if i.get_parent() == null:

			l = i
			break

	if l == null: l = _create_new_line()

	if _syntax_highlighting:

		var k = code.substr(keyword_begin, keyword_end - keyword_begin) # mot-clef
		var e = code.substr(keyword_end, code.length() - keyword_end) # fin de ligne
		s = code.substr(0, keyword_begin) # indentation

		if _show_line_numbers:

			s = _HIGHLIGHTED_NUMBERED_LINE % [_line_number_color, d, line + 1, s, _keyword_color, k, e]

		else:

			s = _HIGHLIGHTED_LINE % [s, _keyword_color, k, e]

	elif _show_line_numbers:

		s = _NUMBERED_LINE % [d, line + 1, code]

	l.line = line
	l.label.set_bbcode(s)

	if n > 0: l.set_pos(Vector2(_BORDER, _TOP_MARGIN + n * _line_height))
	else: l.set_pos(Vector2(_BORDER, _TOP_MARGIN))

	add_child(l) # la ligne n'est jamais déjà affichée

#.............................................................................................................

# Supprime toutes les lignes.

func clear():

	var j = 0

	for i in _lines: # Line

		if i.get_parent() != null: i.get_parent().remove_child(i)
		if j >= _CAPACITY: i.free()
		j += 1

	_lines.resize(_CAPACITY)

#.............................................................................................................

# Récupére la hauteur utile.

func compute_height():

	if _line_height == 0:

		_compute_line_height()
		for i in range(get_child_count()): _lines[i].set_pos(Vector2(_BORDER, _TOP_MARGIN + i * _line_height))

	return _TOP_MARGIN + get_child_count() * _line_height + _BORDER

#.............................................................................................................

# Recharge les paramètres de l'éditeur. Doit être appelée avant append(), un appel interne dans
# compute_height() ignore tous les paramètres pour les lignes ajoutées.

func reload_settings():

	var s = _plugin.get_ref().get_editor_settings()
	_keyword_color = s.get(_TEXT_EDITOR % "keyword_color").to_html(false)
	_line_number_color = s.get(_TEXT_EDITOR % "line_number_color").to_html(false)
	_syntax_highlighting = s.get(_TEXT_EDITOR % "syntax_highlighting")
	_show_line_numbers = s.get(_TEXT_EDITOR % "show_line_numbers")

	var f = s.get(_TEXT_EDITOR % "font")
	if f.length() > 0: _font = load(f)
	if _font == null: _font = _plugin.get_ref().default_font
	if _line_height > 0: _compute_line_height()

	var c = s.get(_TEXT_EDITOR % "background_color")
	c.a = _plugin.get_ref().background_opacity
	_skin.set_bg_color(c)

	_text_color = s.get(_TEXT_EDITOR % "text_color")
	c = _text_color
	c.a = _plugin.get_ref().border_opacity
	_skin.set_light_color(c)
	_skin.set_dark_color(c)

	for i in range(_CAPACITY): _lines[i].format(_font, _text_color, _plugin.get_ref().button_opacity)

#.............................................................................................................

# PRIVATE

#.............................................................................................................

# Calcule la hauteur d'une ligne.
#
# NestedCodeBox::editor_vscrollbar::get_page() vaut 0 au démarrage même si le script en cours a une barre
# verticale, et ne peut être utilisée qu'après le premier clic qui appelle compute_height().
# Donc pour que compute_height() renvoie la bonne hauteur dès le premier appel _line_height doit rester à 0
# pour indiquer qu'elle n'a pas été calculée au moins une fois grâce à get_page().
# Si un paramètre qui change la hauteur de ligne est modifié et que le script en cours a un get_page() 0,
# _line_height est réinitialisée à 0 pour forcer la mise à jour ultérieure.
# Les lignes sont positionnées par append() ou compute_height() et redimensionnées par _on_resized().

func _compute_line_height():

	if _plugin == null or _plugin.get_ref() == null or _plugin.get_ref().editor_script == null: return

	var p = _plugin.get_ref().editor_vscrollbar.get_page()

	if p == 0:
		_line_height = 0
		return

	if _font == null: _line_height = 20 # hauteur minimale d'un bouton
	else: _line_height = int(max(20, ceil(_font.get_height())))

	var h = _plugin.get_ref().editor_script.get_size().height
	_line_height = int(max(round(h / p), _line_height))

#.............................................................................................................

# Redimensionnement de l'occurrence.

func _on_resized():

	var s = Vector2(get_size().width - 2 * _BORDER, _line_height)
	for i in _lines: i.set_size(s)

#.............................................................................................................

func _on_mouse_over(): emit_signal("mouse_enter") # pour les survols rapides

#.............................................................................................................

# Clic sur une ligne. La ligne est supprimée sinon elle garde son état (une meilleure solution ?).

func _on_line_clicked(line): # int

	var l = _lines[line]
	var n = l.line
	_trash.append(l)

	if line < _CAPACITY: _create_new_line(true, line)

	l.get_parent().remove_child(l)
	emit_signal(_CLICK, n)
	call_deferred("_empty_trash")

#.............................................................................................................

# Supprime les lignes cliquées. Dans _on_line_clicked() elles sont verrouillées.

func _empty_trash():

	for i in _trash:

		if i.get_parent() != null: i.get_parent().remove_child(i)
		i.disconnect("pressed", self, "_on_line_clicked")
		i.free()

	_trash.clear()

#.............................................................................................................

# Crée et récupére une nouvelle ligne.
#
# resize ......	Redimensionner
# index .......	Indice de remplacement

func _create_new_line(resize = true, index = -1): # boolean, int: Line

	var l = Line.new()
	l.format(_font, _text_color, _plugin.get_ref().button_opacity)

	if not _plugin.get_ref().enable_targetting: l.set_ignore_mouse(true)
	elif index < 0: l.connect("pressed", self, "_on_line_clicked", [_lines.size()])
	else: l.connect("pressed", self, "_on_line_clicked", [index])

	if resize: l.set_size(Vector2(get_size().width - 2 * _BORDER, _line_height))
	l.connect("mouse_enter", self, "_on_mouse_over")
	if index < 0: _lines.append(l)
	else: _lines[index] = l

	return l


#.. Object ...................................................................................................

func free():

	clear()
	_plugin = null # Reference
	for i in _lines: i.free()
	_lines.clear()
	_lines = null
	_empty_trash()
	_trash = null
	_skin = null # Reference
	if is_connected("resized", self, "_on_resized"): disconnect("resized", self, "_on_resized")
	.free()

#.............................................................................................................

func _init(plugin): # NestedCodeBox.gd

	_plugin = weakref(plugin)
	add_user_signal("click", [{"name":"line", "type":TYPE_INT}])

	_skin = StyleBoxFlat.new()
	_skin.set_border_size(_BORDER)
	add_style_override("panel", _skin)
	_line_height = 0
	_lines = []
	_trash = []

	for i in range(_CAPACITY): _create_new_line(false)
	set_custom_minimum_size(Vector2(2 * _BORDER, _TOP_MARGIN + _BORDER))
	connect("resized", self, "_on_resized")

#.............................................................................................................

class Line:

	#.........................................................................................................

	extends Button

	#.........................................................................................................

	var line # int
	var label # RichTextLabel
	var skin # StyleBoxFlat

	#.........................................................................................................

	func _init():

		skin = StyleBoxFlat.new()
		set_flat(true)
		add_style_override("hover", skin)
		add_style_override("pressed", skin)
		add_style_override("focus", StyleBoxEmpty.new())

		label = RichTextLabel.new()
		label.set_use_bbcode(true)
		label.set_selection_enabled(false)
		label.set_scroll_active(false)
		label.set_ignore_mouse(true)
		label.set_pos(Vector2(_LEFT_MARGIN, 0))
		add_child(label)
		connect("resized", self, "on_resized")

	#.........................................................................................................

	func format(font, color, opacity):

		if font != null: label.add_font_override("normal_font", font)

		if color != null:

			label.add_color_override("default_color", color)
			color.a = opacity
			skin.set_bg_color(color)

	#.........................................................................................................

	func on_resized(): label.set_size(get_size())

	#.........................................................................................................

	func free():

		remove_child(label)
		label.free()
		skin = null # Reference
		if is_connected("resized", self, "on_resized"): disconnect("resized", self, "on_resized")
		.free()