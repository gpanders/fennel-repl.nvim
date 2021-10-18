# fennel-repl.nvim

This plugin provides an in-process Fennel REPL in Neovim with complete access
to the Neovim Lua API.

## Usage

Use `:FennelRepl` to create a new split with a REPL. For more direct access,
use

```lua
require("fennel-repl").start()
```

in Lua. The `start()` function takes optional modifiers that dictate where the
window is drawn (e.g. `vert`, `botright`, etc.).

## License

MIT
