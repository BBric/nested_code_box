# nested_code_box
A plugin for the [Godot game engine](https://github.com/godotengine/godot). 
It display the hidden start blocks in a frame at the top of the script editor.

The frame appears after some seconds, the displayed lines depends of the indentation of the current line.
The frame is hidden when the caret is moved, when the editor is scrolled, when the script is changed or when the frame is overed.
When the horizontal scrolling is greater than zero the frame is not displayed. When the frame is overed a vertical scrolling is required for reactivate it.

The colors used are text_editor > background_color, text_color and keyword_color.
