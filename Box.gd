
# Box
#
#
# ** MÉTHODES *****************************************
#
# append ..............	Ajoute une ligne
# clear ...............	Supprime toutes les lignes
# reload_settings .....	Recharge les paramètres de l'éditeur
# set_digits ..........	Définit le nombre de chiffres des numéros de lignes
# size ................	Récupére le nombre de lignes
#
#.............................................................................................................

extends Panel

#.............................................................................................................

const _CAPACITY = 4
const _HIGHLIGHTED_NUMBERED_LINE = "[color=#%s]%0*d[/color] %s[color=#%s]%s[/color]%s"
const _HIGHLIGHTED_LINE = "%s[color=#%s]%s[/color]%s"
const _NUMBERED_LINE = "%0*d %s%s%s"
const _LINE = "%s%s%s"

var _plugin # WeakRef<NestedCodeBox.gd>
var _container # VBoxContainer
var _lines # [Line]
var _theme # Theme
var _digits # int
var _line_number_color # String
var _keyword_color # String
var _syntax_highlighting # bool
var _show_line_numbers # bool

#.............................................................................................................

# Ajoute une ligne.

func append(line, code, keyword_begin, keyword_end): # int, String, int, int

	var l

	for i in _lines: # Line
		if i.line < 0:
			l = i
			break

	if l == null:
		l = Line.new(_theme)
		_lines.append(l)

	l.line = line
	l.code = code
	l.begin = keyword_begin
	l.end = keyword_end
	_update_line(l)
	_container.add_child(l.label) # la ligne n'est jamais déjà affichée

#.............................................................................................................

# Supprime toutes les lignes.

func clear():

	for i in _lines:

		if i.label.get_parent() == _container: _container.remove_child(i.label)
		i.line = -1

	_lines.resize(_CAPACITY)

#.............................................................................................................

# Recharge les paramètres de l'éditeur.

func reload_settings(font, background_alpha, border_alpha):

	var s = _plugin.get_ref().get_editor_settings()
	var g = "text_editor/%s"
	_keyword_color = s.get(g % "keyword_color").to_html(false)
	_line_number_color = s.get(g % "line_number_color").to_html(false)
	_syntax_highlighting = s.get(g % "syntax_highlighting")
	_show_line_numbers = s.get(g % "show_line_numbers")

	_theme.set_font("normal_font", "RichTextLabel", font)
	var b = _theme.get_stylebox("panel", "Panel")
	var c = s.get(g % "background_color")
	c.a = background_alpha
	b.set_bg_color(c)
	var c = s.get(g % "text_color")
	_theme.set_color("default_color", "RichTextLabel", c)
	c.a = border_alpha
	b.set_light_color(c)
	b.set_dark_color(c)
	set_theme(_theme)

	for i in _lines:

		i.label.set_theme(_theme)
		_update_line(i)

#.........................................................................................................

# Définit le nombre de chiffres des numéros de lignes

func set_digits(value): # int

	if value == _digits: return
	_digits = value
	for i in _lines: _update_line(i)

#.............................................................................................................

func set_font(font): # Font

	_theme.set_font("normal_font", "RichTextLabel", font)
	for i in _lines: _update_line(i)

#.............................................................................................................

# Récupére le nombre de lignes.

func size(): # : int

	var n = 0

	for i in range(_lines.size() - 1, -1, -1):

		if _lines[i].line < 0: continue
		n += 1

	return n

#.............................................................................................................

func trace():

	var s

	for i in _lines:

		if i.line < 0: break
		if s != null: s += "\n"
		else: s = ""
		s += str(i.line + 1) + " " + i.code

	if s == null: print("empty")
	else: print(s)

#.............................................................................................................

# PRIVATE

#.............................................................................................................

# Redimensionnement de l'occurrence.

func _on_resized():

	_container.set_size(get_size())

#.............................................................................................................

# Actualise le format d'une ligne.

func _update_line(l):

	if l.line < 0: return

	var s = l.code.substr(0, l.begin) # indentation
	var k = l.code.substr(l.begin, l.end - l.begin) # mot-clef
	var e = l.code.substr(l.end, l.code.length() - l.end) # fin de ligne

	if _syntax_highlighting:

		if _show_line_numbers:

			s = _HIGHLIGHTED_NUMBERED_LINE % [_line_number_color, _digits, l.line, s, _keyword_color, k, e]

		else:

			s = _HIGHLIGHTED_LINE % [s, _keyword_color, k, e]

	elif _show_line_numbers:

		s = _NUMBERED_LINE % [_digits, l.line, s, k, e]

	else:

		s = _LINE % [s, k, e]

	l.label.set_bbcode(s)

#.. Object ...................................................................................................

func free():

	clear()
	_plugin = null
	_lines.clear()
	_lines = null
	_theme = null
	_container = null

#.............................................................................................................

func _init(plugin, top_margin): # NestedCodeBox.gd, int

	_plugin = weakref(plugin)

	_theme = Theme.new()
	_theme.set_constant("separation", "VBoxContainer", 1)

	var b = StyleBoxFlat.new()
	b.set_border_size(1)
	_theme.set_stylebox("panel", "Panel", b)
	set_theme(_theme)

	_container = VBoxContainer.new()
	_container.set_ignore_mouse(true)
	_container.set_margin(MARGIN_TOP, top_margin)
	_container.set_margin(MARGIN_LEFT, 14)
	_container.set_theme(_theme)
	add_child(_container)
	_digits = 1
	_lines = []

	for i in range(_CAPACITY): _lines.append(Line.new(_theme))
	self.connect("resized", self, "_on_resized")

#.............................................................................................................

class Line:

	#.........................................................................................................

	var line
	var code
	var label
	var begin
	var end

	#.........................................................................................................

	func _init(theme):

		line = -1
		code = ""
		begin = 0
		end = 0
		label = RichTextLabel.new()
		label.set_use_bbcode(true)
		label.set_selection_enabled(false)
		label.set_v_size_flags(Control.SIZE_EXPAND_FILL)
		label.set_theme(theme)
		label.set_ignore_mouse(true)