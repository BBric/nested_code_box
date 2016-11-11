
tool
extends EditorPlugin

#.............................................................................................................

const CODE_TEXT_EDITOR = "CodeTextEditor"
const TEXT_EDIT = "TextEdit"
const V_SCROLL_BAR = "VScrollBar"
const H_SCROLL_BAR = "HScrollBar"
const CFG_FILE_NAME = "/cfg.json"
const TOP_MARGIN = 2

const IDLE = 0
const UPDATE = 1
const WAIT = 2
const SLEEP = 3

var editor_tabs # TabContainer
var editor_script # TextEdit
var editor_vscrollbar # VScrollBar
var editor_hscrollbar # HScrollBar
var box # Box.gd
var re # RegEx
var timer # Timer
var state # int
var default_font # Font
var updating_delay # float
var activity_delay # float
var max_lines # int
var from_root # bool
var hide_visible # bool
var hide_first_line # bool
var background_opacity # float
var border_opacity # float
var save # bool
var lines # Array
var index # int

#.............................................................................................................

# Actualise l'affichage

func update():

	if state == WAIT:
		state = UPDATE
		return

	if timer != null: timer.stop()
	if state != UPDATE: return

	state = IDLE
	box.clear()

	var f = editor_vscrollbar.get_value() # première ligne visible
	if f == 0 or editor_vscrollbar.get_page() == 0: return show_box(false)

	var m = editor_script.cursor_get_line() - 1 - f # nombre maximal de lignes visibles
	if max_lines > 0: m = min(max_lines, m)
	if m < 1: return show_box(false)

	find_all_lines()
	var s = lines.size()

	if s == 0 or index == 0: return show_box(false) # aucune ligne cachée

	var d; var i

	# 'hide_first_line' est prioritaire sur 'hide_visible', donc si la première ligne visible est un
	# bloc parent 'hide_visible' est ignorée. En mode ligne unique le bloc est masqué (c'est le seul cas où
	# un bloc visible est masqué), et en mode multiligne le bloc est ajouté comme une ligne hors champ

	if not hide_visible and index > 0:

		i = lines[index][0]

		if  hide_first_line:

			if i > f: m = min(i - f, m)
			elif index < s - 1: m = min(lines[index + 1][0] - f, m)

		elif i == f: # parent en première ligne

			return show_box(false)

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

		while i < s: # étape 1 : lignes visibles cachées par le cadre

			if lines[i][0] > f + n - 1: break
			n += 1
			i += 1

		i = 0 # indice de départ

		if n > m:

			if from_root:

				n = m # indice de fin

			else:

				i = n - m

				if index > 0 and i >= index: # minimum 1 bloc caché

					i = index - 1
					n = i + m

		while i < n: # étape 2 : lignes affichées

			d = lines[i]
			box.append(d[0], d[1], d[2], d[2] + d[3])
			i += 1

	box.set_digits(str(editor_script.get_line_count()).length())
	show_box(true) # m > 0, index != 0

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

func find_all_lines():

	lines.clear() # lignes sous la forme [numéro, code complet, mot-clef, longueur du mot-clef]
	index = -1 # première ligne visible dans lines
	var i = editor_script.cursor_get_line()
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

func on_box_mouse_enter():

	cancel()
	state = SLEEP

#.............................................................................................................

# Déplacement du caret

func on_cursor_changed(): wait()

#.............................................................................................................

func on_hscroll(value):

	if editor_hscrollbar.get_value() == 0: wait()
	else: cancel()

#.............................................................................................................

func on_resized():	wait()

#.............................................................................................................

func on_settings_changed():

	if box == null: return

	wait()
	var p = get_editor_settings().get("text_editor/font")
	var f
	if p.length() > 0: f = load(p)
	if f == null: f = default_font
	box.reload_settings(f, background_opacity, border_opacity)

#.............................................................................................................

# Changement de script

func on_tab_changed(tab): # int

	cancel()
	find_editor_script()
	if editor_script != null: wait()

#.............................................................................................................

func on_vscroll(value):

	state = IDLE
	wait()

#.............................................................................................................

func cancel():

	timer.stop()
	state = IDLE
	show_box(false)

#.............................................................................................................

func wait():

	if state == SLEEP: return

	if state == IDLE:

		show_box(false)
		state = UPDATE
		timer.set_wait_time(updating_delay)
		timer.start()

	elif state == UPDATE:

		state = WAIT
		timer.set_wait_time(activity_delay)

#.............................................................................................................

func show_box(value):

	if timer == null or box == null: return
	timer.stop()

	if box.get_parent() != null: box.get_parent().remove_child(box)
	if not value or editor_script == null: return

	var w = editor_script.get_size().width - editor_vscrollbar.get_size().width
	var h = editor_script.get_size().height / editor_vscrollbar.get_page() * box.size() + TOP_MARGIN
	box.set_size(Vector2(w, h))
	editor_script.add_child(box)

#.............................................................................................................

func unregister_script():

	if editor_script != null:

		editor_script.remove_child(timer)
		editor_script.disconnect("cursor_changed", self, "on_cursor_changed")
		editor_script.disconnect("resized", self, "on_resized")
		editor_script = null

	if editor_vscrollbar != null:

		editor_vscrollbar.disconnect("value_changed", self, "on_vscroll")
		editor_vscrollbar = null

	if editor_hscrollbar != null:

		editor_hscrollbar.disconnect("value_changed", self, "on_hscroll")
		editor_hscrollbar = null

#.............................................................................................................

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
							editor_vscrollbar.connect("value_changed", self, "on_vscroll")
							if editor_hscrollbar != null: break

						if k.get_type() == H_SCROLL_BAR:

							editor_hscrollbar = k
							editor_hscrollbar.connect("value_changed", self, "on_hscroll")
							if editor_vscrollbar != null: break

					if editor_vscrollbar != null and editor_hscrollbar != null:

						editor_script = j

						if default_font == null:
							default_font = j.get("custom_fonts/font")
							on_settings_changed()

						j.connect("cursor_changed", self, "on_cursor_changed")
						j.connect("resized", self, "on_resized")
						j.add_child(timer)

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

#.. EditorPlugin .............................................................................................

func save_external_data():

	if not save: return

	save = false
	var f = File.new()

	if f.open(get_script().get_path().get_base_dir() + CFG_FILE_NAME, File.WRITE) == OK:

		var p = "\n\t\"%s\":%s"
		var s = "{%s,%s,%s,%s,%s,%s,%s,%s\n}"
		f.store_string(s % [p % ["max_lines", max_lines], p % ["from_root", str(from_root).to_lower()],\
							p % ["hide_visible", str(hide_visible).to_lower()],\
							p % ["hide_first_line", str(hide_first_line).to_lower()],\
							p % ["updating_delay", updating_delay], p % ["activity_delay", activity_delay],\
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
	updating_delay = 6.5
	activity_delay = 3.5
	background_opacity = 0.7
	border_opacity = 0.5
	state = IDLE
	save = false
	lines = []

	var v = get_script().get_path().get_base_dir() + CFG_FILE_NAME
	var f = File.new()

	if f.open(v, File.READ) == OK:

		var d = {}

		if d.parse_json(f.get_as_text()) == OK:

			v = d.max_lines
			if typeof(v) != TYPE_REAL: save = true # un entier donne également un float
			else: max_lines = int(max(0, v))
			v = d.from_root
			if typeof(v) != TYPE_BOOL: save = true
			else: from_root = v
			v = d.hide_visible
			if typeof(v) != TYPE_BOOL: save = true
			else: hide_visible = v
			v = d.hide_first_line
			if typeof(v) != TYPE_BOOL: save = true
			else: hide_first_line = v
			v = d.updating_delay
			if typeof(v) != TYPE_REAL: save = true
			else: updating_delay = max(1.0, v)
			v = d.activity_delay
			if typeof(v) != TYPE_REAL: save = true
			else: activity_delay = max(1.0, v)
			v = d.background_opacity
			if typeof(v) != TYPE_REAL: save = true
			else: background_opacity = clamp(v, 0.0, 1.0)
			v = d.border_opacity
			if typeof(v) != TYPE_REAL: save = true
			else: border_opacity = clamp(v, 0.0, 1.0)

		else:

			save = true

	else:

		save = true

	f.close()
	var s = get_editor_settings()
	box = Box.new(self, TOP_MARGIN)
	box.set_v_size_flags(Control.SIZE_EXPAND_FILL)

	# 0: tout, 1: code, 2: mot clef
	# (\t| )* a toujours une longueur maximale de 1 caractère quelque soit le nombre de caractères,
	# donc indentation = longueur de 0 - longueur de 1
	re = RegEx.new()
	re.compile("^(?:\t| )*((func|static func|if|for|else|elif|while|class)(?: |:|\t)*.*)")

	timer = Timer.new()
	timer.set_wait_time(updating_delay)

	editor_tabs.connect("tab_changed", self, "on_tab_changed")
	timer.connect("timeout", self, "update")
	box.connect("mouse_enter", self, "on_box_mouse_enter")
	s.connect("settings_changed", self, "on_settings_changed")

	find_editor_script()
	if editor_script != null: wait()

#.............................................................................................................

func _exit_tree():

	show_box(false)
	unregister_script() # appelle et remove_child(timer)

	if timer != null:

		timer.stop()
		timer.disconnect("timeout", self, "update")
		timer = null

	if editor_tabs != null:

		editor_tabs.disconnect("tab_changed", self, "on_tab_changed")
		editor_tabs = null

	if box != null:

		box.disconnect("mouse_enter", self, "on_box_mouse_enter")
		box.free()
		box = null

	if lines != null:

		lines.clear()
		lines = null

	get_editor_settings().disconnect("settings_changed", self, "on_settings_changed")
	re = null
	default_font = null