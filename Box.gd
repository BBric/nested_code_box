
# Box
#
#
# ** MÉTHODES *****************************************
#
# append ..............	Ajoute une ligne nichée dans la précédente
# clear ...............	Supprime toutes les lignes
# set_digits ..........	Définit le nombre de chiffres des numéros de lignes
# set_max_lines .......	Définit le nombre maximal de lignes affichées
# size ................	Récupére le nombre de lignes
#
#.............................................................................................................

tool
extends Panel

#.............................................................................................................

const _CAPACITY = 4
const _RICH_TEXT_LABEL = "RichTextLabel"
const _TEXT_EDITOR = "text_editor/%s"
const _KEYWORD_COLOR = _TEXT_EDITOR % "keyword_color"
const _SHOW_LINE_NUMBERS = _TEXT_EDITOR % "show_line_numbers"
const _LINE_NUMBER_COLOR = _TEXT_EDITOR % "line_number_color"
const _COLOR_FORMAT = "[color=#%s]%s[/color]"
const _NUMBERED_LINE = "[color=#%s]%0*d[/color] %s[color=#%s]%s[/color]%s"
const _NO_NUMBERED_LINE = "%s[color=#%s]%s[/color]%s"

var digits setget set_digits

var _container # VBoxContainer
var _lines # Array
var _max_lines # int
var _settings # EditorSettings
var _theme # Theme

#.............................................................................................................

# Ajoute une ligne nichée dans la précédente.

func append(line, code, keyword_begin, keyword_end): # int, String, int, int

	var l

	for i in _lines:

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
	_update_display()

#.............................................................................................................

# Supprime toutes les lignes.

func clear():

	if _max_lines < 0: return

	_remove_all()
	_lines.resize(_CAPACITY)

	for i in _lines: i.line = -1

	_max_lines = -1
	_update_display()

#.........................................................................................................

# Définit le nombre de chiffres des numéros de lignes

func set_digits(value): # setter

	value = max(1, int(value))
	if value == digits: return
	digits = value
	for i in _lines: _update_line(i)

#.............................................................................................................

# Définit le nombre maximal de lignes affichées.
# Il intervient quand le nombre de lignes à afficher est supérieur au nombre de lignes disponibles au-dessus
# de la ligne en cours.

func set_max_lines(value): # int

	value = max(0, int(value))
	if value == _max_lines: return
	_max_lines = value
	_update_display()

#.............................................................................................................

# Récupére le nombre de lignes.
#
# visible 	Uniquement les lignes visibles

func size(visible = false):

	var n = 0

	for i in range(_lines.size() - 1, -1, -1):

		if _lines[i].line < 0: continue
		n += 1
		if visible and n == _max_lines: break

	return n

#.............................................................................................................

func trace():

	var s

	for i in _lines:

		if i.line < 0: break
		if s != null: s += "\n"
		else: s = ""
		s += str(i.line + 1) + " " + i.code

	print(s)

#.............................................................................................................

# PRIVATE

#.............................................................................................................

# Redimensionnement de l'occurrence.

func _on_resized():

	_container.set_size(get_size())

#.............................................................................................................

func _on_settings_changed():

	var b = get_theme().get_stylebox("panel", "Panel")
	var c = _settings.get(_TEXT_EDITOR % "background_color")
	c.a = 0.7
	b.set_bg_color(c)
	var c = _settings.get(_TEXT_EDITOR % "text_color")
	_theme.set_color("default_color", _RICH_TEXT_LABEL, c)
	c.a = 0.5
	b.set_light_color(c)
	b.set_dark_color(c)
	for i in _lines: _update_line(i)

#.............................................................................................................

func _remove_all():

	for i in _lines:
		if i.label.get_parent() == _container: _container.remove_child(i.label)

#.............................................................................................................

# Actualise le format d'une ligne.

func _update_line(l):

	if l.line < 0: return

	var s = l.code.substr(0, l.begin) # indentation
	var k = l.code.substr(l.begin, l.end - l.begin) # mot-clef
	var e = l.code.substr(l.end, l.code.length() - l.end) # fin de la ligne
	var kc = _settings.get(_KEYWORD_COLOR).to_html()

	if _settings.get(_SHOW_LINE_NUMBERS):

		var nc = _settings.get(_LINE_NUMBER_COLOR).to_html()
		s = _NUMBERED_LINE % [nc, digits, l.line, s, kc, k, e]

	else:

		s = _NO_NUMBERED_LINE % [s, kc, k, e]

	l.label.set_bbcode(s)

#.............................................................................................................

# Actualise l'affichage des lignes.

func _update_display():

	_remove_all()

	if _max_lines == 0: return

	var n = 0
	var l

	for i in range(_lines.size() - 1, -1, -1):

		if _lines[i].line < 0: continue
		n += 1

		if i == 0 or (_max_lines > -1 and n == _max_lines):

			for j in range(i, _lines.size()):

				l = _lines[j]
				if l.line < 0: return
				if l.label.get_parent() != _container: _container.add_child(l.label)

			return

#.............................................................................................................

func _init(settings, top_margin): # EditorSettings

	_settings = settings

	_theme = Theme.new()
	_theme.set_font("normal_font", _RICH_TEXT_LABEL, load(_settings.get(_TEXT_EDITOR % "font")))
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
	_max_lines = -1
	digits = 1
	_lines = []

	for i in range(_CAPACITY): _lines.append(Line.new(_theme))

	_on_settings_changed()
	settings.connect("settings_changed", self, "_on_settings_changed")
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