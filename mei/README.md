# Mei
Also known as "what happens when you find writing your own TUI library easier than learning to install and use mtmenu".

Anyway, the basis of everything is `newMenu`. Call it with a table of properties to set it up and return your new menu, then call `menu:run()` to start running it.

## Properties
- `base` - If this is defined, `newMenu` will use it as the __index of its metatable.
- `draw(self)` - This needs to be defined. It's where you put all the code to actually draw the menu.
- `onQuit(self)` - What to do right before `run` returns.
- `keymap` - A key-value table with the key being the, uh... key (as defined in the [keyboard API](https://ocdoc.cil.li/api:keyboard)'s `keyboard.keys`) and the value being another table with two values:
  - `func(self)` - The function to call when the key is pressed.
  - `help` - Optional help text for `showHelp`.
  - Tip: omit `keymap` to make the menu quit after any keypress.
- `miscmap` - Table of handlers for other OC events. Key is the event name, value is a function taking `self` and all the values `event.pull` normally outputs (minus the first). Currently only `scroll` and `touch` are supported.


## Methods

- `run()` - Starts running the menu.
- `quit(quitReturn)` - Tells the menu to quit next frame and return `quitReturn`.
- `callSubmenu(submenu)` - `submenu` should be another menu, which will serve as the base for the one that actually gets run.
- `showHelp()` - Lists the help text for each of the menu's keybinds. 
