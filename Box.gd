
# Box
#
#
# ** MÉTHODES *****************************************
#
# append ..............	Ajoute une ligne
# clear ...............	Supprime toutes les lignes
# reload_settings .....	Recharge les paramètres de l'éditeur
# size ................	Récupére le nombre de lignes
#
#.............................................................................................................

extends Panel

#.............................................................................................................

const _CAPACITY = 4
const _HIGHLIGHTED_NUMBERED_LINE = "[color=#%s]%0*d[/color] %s[color=#%s]%s[/color]%s"
const _HIGHLIGHTED_LINE = "%s[color=#%s]%s[/color]%s"
const _NUMBERED_LINE = "%0*d %s"
const _TEXT_EDITOR = "text_editor/%s"
const _NORMAL_FONT = "normal_font"
const _DEFAULT_COLOR = "default_color"

var _plugin # WeakRef<NestedCodeBox.gd>
var _container # VBoxContainer
var _lines # [RichTextLabel]
var _style_box # StyleBoxFlat
var _font # Font
var _line_number_color # String
var _keyword_color # String
var _text_color # Color
var _syntax_highlighting # bool
var _show_line_numbers # bool

#.............................................................................................................

# Ajoute une ligne.

func append(line, code, keyword_begin, keyword_end): # int, String, int, int

	var n = _lines.size()
	var s = code
	var d = _plugin.get_ref().digits
	var i = 0
	var l

	for i in _lines: # RichTextLabel

		if i.get_parent() == null:

			l = i
			break

	if l == null:

		l = _create_line()
		_lines.append(l)

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

	l.set_bbcode(s)
	_container.add_child(l) # la ligne n'est jamais déjà affichée

#.............................................................................................................

# Supprime toutes les lignes.

func clear():

	var j = 0

	for i in _lines: # RichTextLabel

		if i.get_parent() != null: _container.remove_child(i)
		if j >= _CAPACITY: _free_line(i)
		j += 1

	_lines.resize(_CAPACITY)

#.............................................................................................................

# Recharge les paramètres de l'éditeur.

func reload_settings():

	var s = _plugin.get_ref().get_editor_settings()
	_keyword_color = s.get(_TEXT_EDITOR % "keyword_color").to_html(false)
	_line_number_color = s.get(_TEXT_EDITOR % "line_number_color").to_html(false)
	_syntax_highlighting = s.get(_TEXT_EDITOR % "syntax_highlighting")
	_show_line_numbers = s.get(_TEXT_EDITOR % "show_line_numbers")

	var f = s.get(_TEXT_EDITOR % "font")
	if f.length() > 0: _font = load(f)
	if _font == null: _font = _plugin.get_ref().default_font

	var c = s.get(_TEXT_EDITOR % "background_color")
	c.a = _plugin.get_ref().background_opacity
	_style_box.set_bg_color(c)

	_text_color = s.get(_TEXT_EDITOR % "text_color")
	c = _text_color
	c.a = _plugin.get_ref().border_opacity
	_style_box.set_light_color(c)
	_style_box.set_dark_color(c)

	for i in range(_CAPACITY): _set_line(_lines[i])

#.............................................................................................................

# Récupére le nombre de lignes.

func size(): return _container.get_child_count()

#.............................................................................................................

func trace():

	var s

	for i in _lines:

		if i.get_parent() == null: break
		if s != null: s += "\n"
		else: s = ""
		s += i.get_text()

	if s == null: print("empty")
	else: print(s)

#.............................................................................................................

# PRIVATE

#.............................................................................................................

# Redimensionnement de l'occurrence.

func _on_resized(): _container.set_size(get_size())

#.............................................................................................................

func _free_line(l): # RichTextLabel

	l.add_font_override(_NORMAL_FONT, null)
	l.add_color_override(_DEFAULT_COLOR, null)
	l.free()

#.............................................................................................................

func _create_line(): # : RichTextLabel

	var l = RichTextLabel.new()
	l.set_use_bbcode(true)
	l.set_selection_enabled(false)
	l.set_scroll_active(false)
	l.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	l.set_ignore_mouse(true)
	return _set_line(l)

#.............................................................................................................

func _set_line(l): # RichTextLabel : RichTextLabel

	if _font != null: l.add_font_override(_NORMAL_FONT, _font)
	if _text_color != null: l.add_color_override(_DEFAULT_COLOR, _text_color)
	return l

#.. Object ...................................................................................................

func free():

	add_style_override("panel", null)
	_plugin.free()
	_container.add_constant_override("separation", Theme.INVALID_CONSTANT)

	for i in _lines: _free_line(i)
	_lines.clear()

	if is_connected("resized", self, "_on_resized"): disconnect("resized", self, "_on_resized")
	.free()

#.............................................................................................................

func _init(plugin, top_margin): # NestedCodeBox.gd, int

	_plugin = weakref(plugin)

	_style_box = StyleBoxFlat.new()
	_style_box.set_border_size(1)
	add_style_override("panel", _style_box)

	_container = VBoxContainer.new()
	_container.set_ignore_mouse(true)
	_container.set_margin(MARGIN_TOP, top_margin)
	_container.set_margin(MARGIN_LEFT, 14)
	_container.add_constant_override("separation", 1)
	add_child(_container)
	_lines = []

	for i in range(_CAPACITY): _lines.append(_create_line())

	connect("resized", self, "_on_resized")