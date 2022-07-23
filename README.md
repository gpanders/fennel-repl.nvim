# fennel-repl.nvim

This plugin provides an in-process Fennel REPL in Neovim with complete access
to the Neovim Lua API.

## Usage

Use `:FennelRepl` to create a new split with a REPL. For more direct access,
use

```lua
require("fennel-repl").open()
```

in Lua. The `open()` function takes an optional `opts` table that accepts the
following keys:

- `mods`: modifier for window placement (e.g. "vert", "botright", etc.)
- `height`: height of window in rows (if split horizontally)
- `width`: width of window in columns (if split vertically)

`open()` returns the buffer number of the repl buffer.

## License

MIT
