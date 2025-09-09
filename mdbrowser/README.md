# MDbrowser

Markdown hypertext browser for OpenOS. Nothing close to complete but it's inching its way there.

## Technical stuff

The software consists of two libraries:

- First is the renderer itself, which converts Markdown text into a "rendoc", or a table of lines (or "blocks" internally... don't ask why), each line consisting of one or more segments with their own attributes. The rendoc needs to be reflowed to match the width of the screen (or wherever you'd like to display the output) before rendering it.
- Second is the browser itself, which wraps around the renderer and provides a full-screen view of the document plus customizable keybinds and hyperlink handling. 

Also provided is `mdless`, a simple wrapper for the browser library to let you view documents from the shell.

## Known issues

- So far reflowing hasn't been tested with words longer than the output width.
- No support for any formatting besides hyperlinks and level 1+2 headings. Support for lists is planned, but stuff like bold, italics, and underline will probably stay out. Not like OC has a way to render it anyhow.
- Apparently Markdown renderers are supposed to treat contiguous lines as being part of the same paragraph, without any line breaks in it. This renderer doesn't do that.
