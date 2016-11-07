
tool
extends EditorPlugin

#.............................................................................................................

const DELAY_1 = 4.5
const DELAY_2 = 2.5

const CODE_TEXT_EDITOR = "CodeTextEditor"
const TEXT_EDIT = "TextEdit"
const V_SCROLL_BAR = "VScrollBar"
const H_SCROLL_BAR = "HScrollBar"
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

#.............................................................................................................

# Actualise l'affichage

func update():

	if state == WAIT:
		state = UPDATE
		return

	timer.stop()
	if state != UPDATE: return

	state = IDLE
	box.clear()

	var f = editor_vscrollbar.get_value() # première ligne visible
	if f == 0 or editor_vscrollbar.get_page() == 0: return show_box(false)

	var l = max(f, editor_script.cursor_get_line()) # ligne en cours
	var i = l - 1 # ligne de départ
	var m = i - f # nombre maximal de lignes visibles
	var s = get_next_indent(l) # indentation initiale

	if m < 1 or s == 0: return show_box(false)

	var r = s # indentation du bloc racine
	var n # indentation du bloc parcouru
	var t # code du bloc parcouru
	var h = [] # historique (chaque ligne peut masquer un bloc visible donc le tri se fait après)

	while i > -1:

		t = editor_script.get_line(i)

		if re.find(t) > -1:

			n = t.length() - re.get_capture(1).length()

			if n < r: # bloc parent

				r = n
				h.push_front([i, t, re.get_capture_start(2), re.get_capture(2).length()])
				if r == 0 or h.size() == m: break # bloc racine ou nombre de lignes max

		i -= 1

	n = h.size()
	if n == 0 or h[0][0] >= f: return show_box(false) # aucun nichage
	i = max(0, n - m)

	while i < n: # du bloc racine au bloc niché

		t = h[i]

		if t[0] < f:

			box.append(t[0], t[1], t[2], t[2] + t[3])
			f += 1

		i += 1

	n = editor_script.get_line_count()
	if box.digits != n: box.set_digits(str(n).length())
	box.set_max_lines(m)
	show_box(true)

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

# Changement de script

func on_tab_changed(tab): # int

	find_editor_script() # appelle cancel()
	if editor_script != null: wait()

#.............................................................................................................

# Déplacement du caret

func on_cursor_changed(): wait()

#.............................................................................................................

func on_vscroll(value):

	state = IDLE
	wait()

#.............................................................................................................

func on_hscroll(value):

	if editor_hscrollbar.get_value() == 0: wait()
	else: cancel()

#.............................................................................................................

func on_box_mouse_enter():

	cancel()
	state = SLEEP

#.............................................................................................................

func on_resized():	wait()

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
		timer.set_wait_time(DELAY_1)
		timer.start()

	elif state == UPDATE:

		state = WAIT
		timer.set_wait_time(DELAY_2)

#.............................................................................................................

func on_settings_changed():

	if box == null: return

	wait()
	var f = get_editor_settings().get("text_editor/font")

	if f.length() > 0: box.reload_settings(load(f))
	elif default_font != null: box.reload_settings(default_font)

#.............................................................................................................

func show_box(value):

	if timer == null or editor_script == null: return
	timer.stop()

	if not value:
		if box != null and box.is_inside_tree(): editor_script.remove_child(box)

	else:

		var w = editor_script.get_size().width - editor_vscrollbar.get_size().width
		var h = editor_script.get_size().height / editor_vscrollbar.get_page() * box.size(true) + TOP_MARGIN
		box.set_size(Vector2(w, h))
		if not box.is_inside_tree(): editor_script.add_child(box)

#.............................................................................................................

func unregister_script():

	show_box(false)

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

	cancel()
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

	state = IDLE
	var s = get_editor_settings()
	box = Box.new(s, TOP_MARGIN)
	box.set_v_size_flags(Control.SIZE_EXPAND_FILL)

	# 0: tout, 1: code, 2: mot clef
	# (\t| )* a toujours une longueur maximale de 1 caractère quelque soit le nombre de caractères,
	# donc indentation = longueur de 0 - longueur de 1
	re = RegEx.new()
	re.compile("^(?:\t| )*((func|static func|if|for|else|elif|while|class)(?: |:|\t)*.*)")

	timer = Timer.new()
	timer.set_wait_time(DELAY_1)

	editor_tabs.connect("tab_changed", self, "on_tab_changed")
	timer.connect("timeout", self, "update")
	box.connect("mouse_enter", self, "on_box_mouse_enter")
	s.connect("settings_changed", self, "on_settings_changed")

	find_editor_script()
	if editor_script != null: wait()

#.............................................................................................................

func _exit_tree():

	if timer != null:

		timer.stop()
		timer.disconnect("timeout", self, "update")
		timer = null

	unregister_script()

	if editor_tabs != null:

		editor_tabs.disconnect("tab_changed", self, "on_tab_changed")
		editor_tabs = null

	if box != null:

		box.disconnect("mouse_enter", self, "on_box_mouse_enter")
		box.free()
		box = null

	get_editor_settings().disconnect("settings_changed", self, "on_settings_changed")
	re = null
	state = null
	default_font = null