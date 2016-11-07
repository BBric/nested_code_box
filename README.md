# nested_code_box
A plugin for the [Godot game engine](https://github.com/godotengine/godot). 
It display the hidden start blocks in a frame at the top of the script editor.

The frame appears after some seconds, the displayed lines depends of the indentation of the current line and the number of availables lines above of the current line.
The frame is hidden when the caret is moved, when the script is changed, scrolled or resized, or when the frame is overed.
When the horizontal scrolling is greater than zero the frame is not displayed. When the frame is overed a vertical scrolling is required for reactivate it.

The used editor settings are:
* Text Editor > Background Color
* Text Editor > Text Color
* Text Editor > Keyword Color
* Text Editor > Line Number Color
* Text Editor > Syntax Highlighting
* Text Editor > Show Line Numbers
* Text Editor > Font
