
tool
extends EditorPlugin

#.............................................................................................................

const CODE_TEXT_EDITOR = "CodeTextEditor"
const TEXT_EDIT = "TextEdit"
const V_SCROLL_BAR = "VScrollBar"
const H_SCROLL_BAR = "HScrollBar"
const CFG_FILE_NAME = "/cfg.json"
const TOP_MARGIN = 2
const TEXT_CHANGED = "text_changed"
const ON_TEXT_CHANGED = "on_text_changed"
const CURSOR_CHANGED = "cursor_changed"
const ON_CURSOR_CHANGED = "on_cursor_changed"
const RESIZED = "resized"
const ON_RESIZED = "on_resized"
const VALUE_CHANGED = "value_changed"
const ON_SCROLL = "on_scroll"
const CANCEL = "cancel"

const IDLE = 0
const UPDATE = 1
const PENDING = 2

var editor_tabs # TabContainer
var editor_script # TextEdit
var editor_vscrollbar # VScrollBar
var editor_hscrollbar # HScrollBar
var box # Box.gd
var re # RegEx
var timer # Timer
var state # int
var default_font # Font
var delay # float
var max_lines # int
var from_root # bool
var hide_visible # bool
var hide_first_line # bool
var lines_gap # int
var background_opacity # float
var border_opacity # float
var digits # int
var lines # Array
var index # int
var changed # bool
var width # int

#.............................................................................................................

# Actualise l'affichage

func update():

	if state == PENDING:
		state = UPDATE
		return

	if timer != null: timer.stop()

	if state != UPDATE: return

	state = IDLE
	box.clear()
	var f = editor_vscrollbar.get_value() # première ligne visible
	if f == 0 or editor_vscrollbar.get_page() == 0: return

	var l = editor_script.cursor_get_line()
	var m = min(l - lines_gap - f, f + editor_vscrollbar.get_page()) # nombre maximal de lignes visibles

	if m < 1: return # aucune ligne ne peut être affichée

	if max_lines > 0: m = min(max_lines, m)
	find_all_lines(l)
	var s = lines.size()

	if s == 0 or index == 0: return # aucun bloc hors champ

	var d; var i
	digits = str(editor_script.get_line_count()).length()

	# 'hide_first_line' est prioritaire sur 'hide_visible', donc si la première ligne visible est un
	# bloc parent 'hide_visible' est ignorée. En mode ligne unique le bloc est masqué (c'est le seul cas où
	# un bloc visible est masqué), et en mode multiligne le bloc est ajouté comme s'il était hors champ

	if not hide_visible and index > 0: # mise à jour de m (toujours positif)

		i = lines[index][0]

		if  hide_first_line:

			if i > f: m = min(i - f, m)
			elif index < s - 1: m = min(lines[index + 1][0] - f, m)

		elif i == f: # parent en première ligne

			return

		else:

			m = min(i - f, m)

	if m == 1: # ligne unique

		if from_root: i = 0
		elif index > 0: i = index - 1
		else: i = s - 1

		d = lines[i]
		box.append(d[0], d[1], d[2], d[2] + d[3])

	else: # multiligne

		var n # nombre de lignes affichées

		if index > 0: n = index
		else: n = s
		i = n # première ligne visible

		while i < s: # étape 1 : inclure les lignes visibles cachées par le cadre

			if lines[i][0] > f + n - 1: break
			n += 1
			i += 1

		i = 0 # indice de départ

		if n > m:

			if from_root:

				n = m # indice de fin

			else:

				i = n - m

				if index > 0 and i >= index:

					i = index - 1 # minimum 1 bloc hors champ
					n = i + m # indice de fin

		while i < n: # étape 2 : lignes affichées

			d = lines[i]
			box.append(d[0], d[1], d[2], d[2] + d[3])
			i += 1

	var h = editor_script.get_size().height / editor_vscrollbar.get_page() * box.size() + TOP_MARGIN
	box.set_size(Vector2(width, h))
	add_safely(editor_script, box)

#.............................................................................................................

# Récupére l'indentation de la ligne non vide suivante la plus proche.
# Une ligne qui ne contient que des caractères blancs n'est pas considérée vide.
# Si aucune ligne n'est trouvée la méthode renvoie 0.
#
# i		Indice de départ inclus

func get_next_indent(i): # int : int

	var m = editor_script.get_line_count()
	var t

	while i < m:

		t = editor_script.get_line(i)

		if t.length() > 0:

			var c = t.ord_at(0)
			var n = 0

			if c == 9 or c == 32: # tabulation ou espace

				var j = 1
				n = 1

				while j < t.length():

					if t.ord_at(j) == c: n += 1
					else: break
					j += 1

			return n

		i += 1

	return 0

#.............................................................................................................

# Trouves toutes les lignes. Les données précédentes sont supprimées.
#
# i			Ligne de départ exclue

func find_all_lines(i):

	lines.clear() # lignes sous la forme [numéro, code complet, indice du mot-clef, longueur du mot-clef]
	index = -1 # première ligne visible dans lines
	var r = get_next_indent(i) # indentation du bloc racine

	if r == 0: return # curseur hors bloc

	var f = editor_vscrollbar.get_value()
	var n # indentation
	var t # code
	i -= 1

	while i > -1:

		t = editor_script.get_line(i)

		if re.find(t) > -1: # bloc

			n = t.length() - re.get_capture(1).length()

			if n < r: # bloc parent

				r = n

				if index > -1 and i < f: index += 1
				elif index < 0 and i >= f: index = 0

				lines.push_front([i, t, re.get_capture_start(2), re.get_capture(2).length()])
				if r == 0: return # bloc racine

		i -= 1

#.............................................................................................................

# Déplacement du caret.

func on_cursor_changed():

	if changed == true: # déplacement par édition (après on_text_changed)

		changed = false
		return

	# déplacement par clic

	cancel()

	if editor_script.cursor_get_column() == 0: return

	var t = editor_script.get_line(editor_script.cursor_get_line())
	var n = t.length()
	var c = t.ord_at(0)
	var i = 1

	while i < n:

		if t.ord_at(i) != c: break
		i += 1

	if i != editor_script.cursor_get_column(): return

	if state == IDLE:

		state = UPDATE
		timer.start()

	elif state == UPDATE:

		state = PENDING

#.............................................................................................................

func on_resized():

	cancel()
	if editor_script != null: width = editor_script.get_size().width - editor_vscrollbar.get_size().width

#.............................................................................................................

func on_settings_changed():

	if box != null: box.reload_settings()

#.............................................................................................................

# Changement de script.

func on_tab_changed(tab): # int

	cancel()
	find_editor_script()

#.............................................................................................................

func on_text_changed():

	changed = true
	cancel()

#.............................................................................................................

func on_scroll(value): cancel()

#.............................................................................................................

func cancel():

	if timer != null: timer.stop()
	if box != null and box.get_parent() != null: box.get_parent().remove_child(box)
	state = IDLE

#.............................................................................................................

func unregister_script():

	if editor_script != null:

		remove_safely(editor_script, timer)
		disconnect_safely(editor_script, TEXT_CHANGED, ON_TEXT_CHANGED)
		disconnect_safely(editor_script, CURSOR_CHANGED, ON_CURSOR_CHANGED)
		disconnect_safely(editor_script, RESIZED, ON_RESIZED)
		editor_script = null

	if editor_vscrollbar != null:

		disconnect_safely(editor_vscrollbar, VALUE_CHANGED, ON_SCROLL)
		editor_vscrollbar = null

	if editor_hscrollbar != null:

		disconnect_safely(editor_hscrollbar, VALUE_CHANGED, ON_SCROLL)
		editor_hscrollbar = null

#.............................................................................................................

# Trouve le script et les deux barres de défilement (les trois ou aucun).

func find_editor_script():

	unregister_script()
	var t = editor_tabs.get_current_tab_control()
	if t == null: return

	for i in t.get_children():

		if i.get_type() == CODE_TEXT_EDITOR:

			for j in i.get_children():

				if j.get_type() == TEXT_EDIT:

					for k in j.get_children():

						if k.get_type() == V_SCROLL_BAR:

							editor_vscrollbar = k
							if editor_hscrollbar != null: break

						if k.get_type() == H_SCROLL_BAR:

							editor_hscrollbar = k
							if editor_vscrollbar != null: break

					if editor_vscrollbar != null and editor_hscrollbar != null:

						editor_script = j

						if default_font == null:
							default_font = j.get("custom_fonts/font")
							on_settings_changed()

						connect_safely(j, TEXT_CHANGED, ON_TEXT_CHANGED)
						connect_safely(j, CURSOR_CHANGED, ON_CURSOR_CHANGED)
						connect_safely(j, RESIZED, ON_RESIZED)
						connect_safely(editor_vscrollbar, VALUE_CHANGED, ON_SCROLL)
						connect_safely(editor_hscrollbar, VALUE_CHANGED, ON_SCROLL)
						width = j.get_size().width - editor_vscrollbar.get_size().width
						add_safely(j, timer)

					return

			return

		return

#.............................................................................................................

func find_editor_tabs():

	for i in get_editor_viewport().get_children():

		if i.get_type() == "ScriptEditor":

			for j in i.get_children():

				if j.get_type() == "HSplitContainer":

					for k in j.get_children():

						if k.get_type() == "TabContainer":

							editor_tabs = k
							return

					return

			return

#.............................................................................................................

func add_safely(parent, child):

	if parent == null or child == null: return

	var p = child.get_parent()
	if p == parent: return

	if p != null: p.remove_child(child) # ERROR: add_child: Can't add child, already has a parent
	parent.add_child(child)

#.............................................................................................................

func remove_safely(parent, child):

	if parent != null and child != null and child.get_parent() == parent: parent.remove_child(child)

#.............................................................................................................

func connect_safely(target, name, function): # Object, String, String

	if target != null and not target.is_connected(name, self, function): target.connect(name, self, function)

#.............................................................................................................

func disconnect_safely(target, name, function): # Object, String, String

	if target != null and target.is_connected(name, self, function): target.disconnect(name, self, function)

#.............................................................................................................

func load_config():

	var v = get_script().get_path().get_base_dir() + CFG_FILE_NAME
	var f = File.new()
	var r = false # enregistrer les paramètres

	if f.open(v, File.READ) == OK:

		var d = {}

		if d.parse_json(f.get_as_text()) == OK:

			v = d.max_lines
			if typeof(v) != TYPE_REAL: r = true # un entier donne également un float
			else: max_lines = int(max(0, v))

			v = d.from_root
			if typeof(v) != TYPE_BOOL: r = true
			else: from_root = v

			v = d.hide_visible
			if typeof(v) != TYPE_BOOL: r = true
			else: hide_visible = v

			v = d.hide_first_line
			if typeof(v) != TYPE_BOOL: r = true
			else: hide_first_line = v

			v = d.delay
			if typeof(v) != TYPE_REAL: r = true
			else: delay = max(1.0, v)

			v = d.lines_gap
			if typeof(v) != TYPE_REAL: r = true
			else: lines_gap = int(clamp(v, 0, 3))

			v = d.background_opacity
			if typeof(v) != TYPE_REAL: r = true
			else: background_opacity = clamp(v, 0.0, 1.0)

			v = d.border_opacity
			if typeof(v) != TYPE_REAL: r = true
			else: border_opacity = clamp(v, 0.0, 1.0)

		else:

			r = true

	else:

		r = true

	f.close()

	if not r: return

	if f.open(v, File.WRITE) == OK:

		var p = "\n\t\"%s\":%s"
		var c = "{%s,%s,%s,%s,%s,%s,%s,%s\n}"
		f.store_string(c % [p % ["max_lines", max_lines], p % ["from_root", str(from_root).to_lower()],\
							p % ["hide_visible", str(hide_visible).to_lower()],\
							p % ["hide_first_line", str(hide_first_line).to_lower()],\
							p % ["delay", delay],\
							p % ["lines_gap", lines_gap],\
							p % ["background_opacity", background_opacity],\
							p % ["border_opacity", border_opacity]])

	f.close()

#.. Node .....................................................................................................

func _enter_tree():

	var Box = preload("Box.gd")

	if Box == null:

		OS.alert("Box.gd not found", "Nested Code Box plugin error")
		return

	find_editor_tabs()

	if editor_tabs == null:

		OS.alert("Unable to find editor tabs", "Nested Code Box plugin error")
		return

	max_lines = 0
	from_root = false
	hide_visible = false
	hide_first_line = true
	delay = 3.5
	lines_gap = 1
	background_opacity = 0.7
	border_opacity = 0.5
	state = IDLE
	lines = []
	changed = false

	load_config()
	box = Box.new(self, TOP_MARGIN)
	box.set_v_size_flags(Control.SIZE_EXPAND_FILL)

	# 0: tout, 1: code, 2: mot clef
	# (\t| )* a toujours une longueur maximale de 1 caractère quelque soit le nombre de caractères,
	# donc indentation = longueur de 0 - longueur de 1
	re = RegEx.new()
	re.compile("^(?:\t| )*((func|static func|if|for|else|elif|while|class)(?: |:|\t)*.*)")

	timer = Timer.new()
	timer.set_wait_time(delay)
	timer.connect("timeout", self, "update")

	connect_safely(editor_tabs, "tab_changed", "on_tab_changed")
	connect_safely(box, "mouse_enter", CANCEL)
	connect_safely(get_editor_settings(), "settings_changed", "on_settings_changed")

	find_editor_script()

#.............................................................................................................

func _exit_tree():

	cancel()
	unregister_script()

	if timer != null:

		disconnect_safely(timer, "timeout", "update")
		timer.free()

	if editor_tabs != null:

		disconnect_safely(editor_tabs, "tab_changed", "on_tab_changed")

	if box != null:

		disconnect_safely(box, "mouse_enter", CANCEL)
		box.free()

	if lines != null: lines.clear()

	disconnect_safely(get_editor_settings(), "settings_changed", "on_settings_changed")