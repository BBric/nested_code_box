
tool
extends EditorPlugin

#.............................................................................................................

const TEXT_EDIT = "TextEdit"
const V_SCROLL_BAR = "VScrollBar"
const H_SCROLL_BAR = "HScrollBar"

const CURSOR_CHANGED = "cursor_changed"
const EXIT_TREE = "exit_tree"
const RESIZED = "resized"
const TEXT_CHANGED = "text_changed"
const VALUE_CHANGED = "value_changed"

const ON_CURSOR_CHANGED = "on_cursor_changed"
const ON_RESIZED = "on_resized"
const ON_SCROLL = "on_scroll"
const ON_SCRIPT_EXIT_TREE = "on_script_exit_tree"
const ON_TEXT_CHANGED = "on_text_changed"

const REGEX_22_FIX = { "fu":4, "st":11, "if":2, "fo":3, "els":4, "eli":4, "wh":5, "cl":5 }

var editor_tabs # TabContainer
var editor_script # TextEdit
var editor_vscrollbar # VScrollBar
var editor_hscrollbar # HScrollBar
var script_path # [String]
var box # Box.gd
var re # RegEx
var timer # Timer
var idle # bool
var default_font # Font
var delay # float
var max_lines # int
var from_root # bool
var hide_visible # bool
var hide_first_line # bool
var enable_targetting # bool
var ignore_echo # bool
var ignore_white # bool
var lines_gap # int
var lines_margin # int
var background_opacity # float
var border_opacity # float
var button_opacity # float
var digits # int
var lines # Array
var index # int
var changed # bool
var width # int
var last # int
var skip # bool
var v21 # bool

#.............................................................................................................

# Actualise l'affichage

func update():

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

	last = l

	if m == 1: # ligne unique

		if from_root: i = 0
		elif index > 0: i = index - 1
		else: i = s - 1

		d = lines[i]
		box.append(d[0], d[1], d[2], d[2] + d[3])

	else: # multiligne

		var n # indice de fin

		if index < 0:

			i = 0 # indice de départ
			n = s

			if n > m:

				if from_root: n = m
				else: i = n - m

		else:

			n = get_lines_number(index)
			i = 0

			if n > m:

				if from_root:

					n = m

				else:

					while i < index - 1: # minimum 1 ligne hors champ

						n = get_lines_number(index - i)
						if n <= m: break
						i += 1

					if n > m: n = i + m
					else: n = i + n

		while i < n: # lignes affichées

			d = lines[i]
			box.append(d[0], d[1], d[2], d[2] + d[3])
			i += 1

	box.set_size(Vector2(width, box.compute_height()))
	skip = true
	add_safely(get_base_control(), box)

#.............................................................................................................

# Récupére le nombre de lignes à afficher à partir d'un nombre de lignes initial en incluant les lignes
# cachées par ce nombre de lignes (index supposé > 0).

func get_lines_number(n): # int : int

	var f = editor_vscrollbar.get_value()
	var i = index

	while i < lines.size():

		if lines[i][0] > f + n - 1: return n
		n += 1
		i += 1

	return n

#.............................................................................................................

# Trouves toutes les lignes. Les données précédentes sont supprimées.
#
# i			Ligne de départ exclue

func find_all_lines(i):

	lines.clear() # lignes sous la forme [numéro, code complet, indice du mot-clef, longueur du mot-clef]
	index = -1 # première ligne visible dans lines
	var t = editor_script.get_line(i)
	var r = 0 # indentation du bloc racine
	var n = t.length()

	if n > 0:

		var c = t.ord_at(0)

		if c == 9 or c == 32: # tabulation ou espace

			var j = 1
			r = 1

			while j < n:

				if t.ord_at(j) == c: r += 1
				else: break
				j += 1

	if r == 0: return # curseur hors bloc

	var f = editor_vscrollbar.get_value()
	var m
	i -= 1

	while i > -1:

		t = editor_script.get_line(i)
		m = search(t)

		if m != null and m[0] < r:

			r = m[0]

			if index > -1 and i < f: index += 1
			elif index < 0 and i >= f: index = 0

			lines.push_front([i, t, r, m[1]])
			if r == 0: return # bloc racine

		i -= 1

#............................................................................................................

# Récupére une recherche multi versions sous la forme [indice du mot-clef, longueur du mot-clef].

func search(s): # String : []

	if not v21:

		if s.length() == 0: return
		var r = re.search(s) # Condition ' p_start >= p_text.length() ' is true. returned: __null
		if r == null: return
		var a = [r.get_start(2), r.get_string(2).length()]

		if a[1] == 0: # [2.2A]

			var k = r.get_string(1).substr(0, 2)
			if not REGEX_22_FIX.has(k): k = r.get_string(1).substr(0, 3) # else, elif
			a[1] = REGEX_22_FIX[k]

		return a

	elif re.find(s) >= 0:

		return [re.get_capture_start(2), re.get_capture(2).length()]

#.............................................................................................................

# Déplacement du caret. Appelée automatiquement au démarrage à la colonne 0.

func on_cursor_changed():

	if changed: # déplacement par édition (après on_text_changed)

		changed = false
		if last > -1: return # on_text_changed() est appelée au démarrage ce qui annule le 1er clic

	# déplacement par clic

	cancel()
	if editor_script.is_selection_active(): return # texte sélectionné (appels multiples)

	var l = editor_script.cursor_get_line()

	# column == 0 évite un affichage trop fréquent sur une ligne vide
	# le défilement horizontal peut être 1+ alors que la barre n'est pas visible [2.1]
	# une unité H ne correspond pas à 1 caractère, le désalignement se voit un peu plus à partir de 3
	if editor_script.cursor_get_column() == 0 or (ignore_echo and l == last) or\
	   (not editor_hscrollbar.is_hidden() and editor_hscrollbar.get_value() > 2): return

	if l != last: last = 0 # réinitialise la dernière ligne

	var t = editor_script.get_line(editor_script.cursor_get_line())
	var n = t.length() # > 0
	var c = t.ord_at(0)
	var i = 1

	# une suite de caractères qui n'est pas une indentation lance update() mais la box n'est pas
	# affichée à cause de l'indentation qui est 0, donc il est facultatif de contrôler le caractère ici

	while i < n:

		if t.ord_at(i) != c: break
		i += 1

	if i != editor_script.cursor_get_column() or (ignore_white and i == n): return

	idle = false # cancel() retourne si idle true, ce qui empêche d'annuler
	if delay > 0: timer.start()
	else: update() # le passage par timer donne un délai de mini 1s [2.1]

#.............................................................................................................

func on_line_clicked(line): # int

	cancel()
	editor_script.grab_focus()
	var m = max(0, line - editor_vscrollbar.get_page() + 1)
	editor_script.cursor_set_line(max(m, line - lines_margin), true)
	editor_script.cursor_set_line(line)
	editor_script.cursor_set_column(editor_script.get_line(line).length())

#.............................................................................................................

func on_resized():

	cancel()

	if editor_script != null:

		box.set_pos(editor_script.get_global_rect().pos)
		width = int(round(editor_script.get_size().width - editor_vscrollbar.get_size().width))

#.............................................................................................................

# Modification des paramètres de l'éditeur.
# Appelée sans appel explicite au démarrage uniquement si le plugin est activé.

func on_settings_changed():

	if box != null: box.reload_settings()

#.............................................................................................................

func on_mouse_over():

	if not enable_targetting: cancel()
	elif not is_processing(): set_process(true)

#.............................................................................................................

# Fermeture d'un script.
#
# Lorsqu'un script est fermé et que la boîte est affichée dans ce script l'accès à une méthode de box ferme
# directement Godot [2.1]. Cet écouteur est appelé avant on_tab_changed() et permet d'éviter ce problème.
# Le même écouteur sur box ferme aussi Godot mais affiche un message qui conseille d'appeler
# call_deferred("remove_child", child) car le parent est indisponible.

func on_script_exit_tree():

	cancel()
	unregister_script()

#.............................................................................................................

func on_scroll(value): cancel()

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

func on_viewport_draw():

	if skip: skip = false # actualisation pour l'affichage de la boîte
	else: cancel() # autre actualisation (menu, bulle d'aide...)

#.............................................................................................................

# Arrête le timer, masque la boîte et revient au repos.

func cancel():

	if idle: return

	set_process(false)
	if timer != null: timer.stop()
	if box != null and box.get_parent() != null: box.get_parent().remove_child(box)
	skip = false
	idle = true

#.............................................................................................................

func unregister_script():

	if editor_script != null:

		disconnect_safely(editor_script, EXIT_TREE, ON_SCRIPT_EXIT_TREE)
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
	var o = editor_tabs.get_current_tab_control()
	for i in script_path: o = find_node(o, i)

	if o == null: return

	var v = find_node(o, V_SCROLL_BAR)
	var h = find_node(o, H_SCROLL_BAR)

	if v == null or h == null: return

	editor_script = o
	editor_vscrollbar = v
	editor_hscrollbar = h

	if default_font == null: default_font = o.get("custom_fonts/font")

	connect_safely(o, EXIT_TREE, ON_SCRIPT_EXIT_TREE)
	connect_safely(o, TEXT_CHANGED, ON_TEXT_CHANGED)
	connect_safely(o, CURSOR_CHANGED, ON_CURSOR_CHANGED)
	connect_safely(o, RESIZED, ON_RESIZED)
	connect_safely(v, VALUE_CHANGED, ON_SCROLL)
	connect_safely(h, VALUE_CHANGED, ON_SCROLL)
	box.set_pos(o.get_global_rect().pos)
	width = int(round(o.get_size().width - v.get_size().width))

#.............................................................................................................

func find_editor_tabs():

	editor_tabs = get_editor_viewport()
	for i in ["ScriptEditor", "HSplitContainer", "TabContainer"]: editor_tabs = find_node(editor_tabs, i)

#.............................................................................................................

func find_node(node, type): # Node, String

	if node != null: for i in node.get_children(): if i.get_type() == type: return i

#.............................................................................................................

func add_safely(parent, child):

	if parent == null or child == null: return

	var p = child.get_parent()
	if p == parent: return
	if p != null: p.remove_child(child) # ERROR: add_child: Can't add child, already has a parent [2.1]

	parent.add_child(child)

#.............................................................................................................

func remove_safely(child):

	if child != null and child.get_parent() != null: child.get_parent().remove_child(child)

#.............................................................................................................

func connect_safely(target, name, function): # Object, String, String

	if target != null and not target.is_connected(name, self, function): target.connect(name, self, function)

#.............................................................................................................

func disconnect_safely(target, name, function): # Object, String, String

	if target != null and target.is_connected(name, self, function): target.disconnect(name, self, function)

#.............................................................................................................

func load_config():

	var s = get_script().get_path().get_base_dir() + "/cfg.json"
	var f = File.new()
	var r = false # enregistrer les paramètres

	if f.open(s, File.READ) == OK:

		var d = {}
		var v

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

			v = d.enable_targetting
			if typeof(v) != TYPE_BOOL: r = true
			else: enable_targetting = v

			v = d.ignore_echo
			if typeof(v) != TYPE_BOOL: r = true
			else: ignore_echo = v

			v = d.ignore_white
			if typeof(v) != TYPE_BOOL: r = true
			else: ignore_white = v

			v = d.delay
			if typeof(v) != TYPE_REAL: r = true
			else: delay = max(0.0, v)

			v = d.lines_gap
			if typeof(v) != TYPE_REAL: r = true
			else: lines_gap = int(clamp(v, 0, 3))

			v = d.lines_margin
			if typeof(v) != TYPE_REAL: r = true
			else: lines_margin = int(clamp(v, 0, 10))

			v = d.background_opacity
			if typeof(v) != TYPE_REAL: r = true
			else: background_opacity = clamp(v, 0.0, 1.0)

			v = d.border_opacity
			if typeof(v) != TYPE_REAL: r = true
			else: border_opacity = clamp(v, 0.0, 1.0)

			v = d.button_opacity
			if typeof(v) != TYPE_REAL: r = true
			else: button_opacity = clamp(v, 0.0, 1.0)

		else:

			r = true

	else:

		r = true

	f.close()

	if not r: return

	if f.open(s, File.WRITE) == OK:

		var p = "\n\t\"%s\":%s"
		var c = "{%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n}"
		f.store_string(c % [p % ["max_lines", max_lines], p % ["from_root", str(from_root).to_lower()],\
							p % ["hide_visible", str(hide_visible).to_lower()],\
							p % ["hide_first_line", str(hide_first_line).to_lower()],\
							p % ["enable_targetting", str(enable_targetting).to_lower()],\
							p % ["ignore_echo", str(ignore_echo).to_lower()],\
							p % ["ignore_white", str(ignore_white).to_lower()], p % ["delay", delay],\
							p % ["lines_gap", lines_gap], p % ["lines_margin", lines_margin],\
							p % ["background_opacity", background_opacity],\
							p % ["border_opacity", border_opacity],\
							p % ["button_opacity", button_opacity]])

	f.close()

#.. Node .....................................................................................................

func _process(delta):

	var r = box.get_global_rect() # Rect2::has_point() exclus les limites [2.1]
	var p = box.get_global_mouse_pos()
	if p.x < r.pos.x or p.y < r.pos.y or p.x > r.end.x or p.y > r.end.y: cancel()

#.............................................................................................................

func _enter_tree():

	var Box = preload("Box.gd")

	if Box == null:

		OS.alert("Box.gd not found", "Nested Code Box plugin error")
		return

	find_editor_tabs()

	if editor_tabs == null:

		OS.alert("Unable to find editor tabs", "Nested Code Box plugin error")
		return

	script_path = ["CodeTextEditor", "TextEdit"]
	var v = OS.get_engine_version()
	v21 = float(v.major + "." + v.minor) < 2.2
	if v21: script_path.pop_front()

	max_lines = 0
	from_root = false
	hide_visible = false
	hide_first_line = true
	enable_targetting = true
	ignore_echo = false
	ignore_white = true
	delay = 3.5
	lines_gap = 1
	lines_margin = 2
	background_opacity = 0.7
	border_opacity = 0.5
	button_opacity = 0.05
	idle = true
	changed = false
	lines = []
	width = 0
	skip = false
	last = -1 # -1: non initialisée, 0: aucune valeur

	load_config()
	box = Box.new(self)

	# 0: tout, 1: code, 2: mot clef
	# (\t| )* a toujours une longueur maximale de 1 caractère quelque soit le nombre de caractères [2.1],
	# donc indentation = longueur de 0 - longueur de 1
	re = RegEx.new()
	re.compile("^(?:\t| )*((func|static func|if|for|else|elif|while|class)(?: |:|\t)*.*)")

	timer = Timer.new()
	timer.set_wait_time(delay) # mini 1s [2.1]
	timer.set_one_shot(true)
	timer.connect("timeout", self, "update")
	add_safely(get_base_control(), timer)

	connect_safely(get_editor_viewport(), "draw", "on_viewport_draw")
	connect_safely(editor_tabs, "tab_changed", "on_tab_changed")
	connect_safely(get_editor_settings(), "settings_changed", "on_settings_changed")
	connect_safely(box, "mouse_enter", "on_mouse_over")
	connect_safely(box, "click", "on_line_clicked")

	find_editor_script()
	on_settings_changed()

#.............................................................................................................

func _exit_tree():

	cancel()
	unregister_script()

	if timer != null:

		remove_safely(timer)
		disconnect_safely(timer, "timeout", "update")
		timer.free()
		timer = null

	if editor_tabs != null:

		disconnect_safely(editor_tabs, "tab_changed", "on_tab_changed")
		editor_tabs = null

	if box != null:

		disconnect_safely(box, "mouse_enter", "on_mouse_over")
		disconnect_safely(box, "click", "on_line_clicked")
		box.free()
		box = null

	if lines != null: lines.clear()
	re = null
	default_font = null

	disconnect_safely(get_editor_settings(), "settings_changed", "on_settings_changed")
	disconnect_safely(get_editor_viewport(), "draw", "on_viewport_draw")