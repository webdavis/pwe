# pwe

One set of keys for moving between Neovim splits and Rex panes, and one key to go back to the last place you were.

## Install

Install pwe:

```sh
cargo install --git https://github.com/webdavis/pwe
```

Save its Rex loader:

```sh
pwe rex get loader > ~/.config/rex/pwe.lua
```

Add this line to `~/.config/rex/init.lua`:

```lua
require("pwe").setup()
```

In Neovim, add this plugin spec to [lazy.nvim](https://lazy.folke.io):

```lua
{ "webdavis/pwe", lazy = false, opts = {} }
```

## Keys

| Key                                 | What it does                                                     |
| ----------------------------------- | ---------------------------------------------------------------- |
| `ctrl-h` `ctrl-j` `ctrl-k` `ctrl-l` | Move left, down, up or right, to the next split or the next pane |
| `ctrl-\`                            | Go back to the last split or pane                                |

To change a key, set it in the settings below.

## Settings

Rex takes its settings as a table in `require("pwe").setup({ ... })`. Neovim takes them in the plugin spec's `opts`. Any setting you leave out keeps its default.

### Rex

| Setting                                           | Default                                        | What it does                                                                                                                                             |
| ------------------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `keys.left`, `keys.down`, `keys.up`, `keys.right` | `"ctrl+h"`, `"ctrl+j"`, `"ctrl+k"`, `"ctrl+l"` | The key for each move. `false` turns one off.                                                                                                            |
| `keys.last`                                       | `"ctrl+\\"`                                    | The key that goes back. `false` turns it off.                                                                                                            |
| `send_after`                                      | not set                                        | A prefix key, such as `"ctrl+d"`. The prefix then a move key sends that key to the program in the pane. Works for move keys made of ctrl and one letter. |

### Neovim

| Setting                                           | Default                                    | What it does                                                                                                                               |
| ------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `keys.left`, `keys.down`, `keys.up`, `keys.right` | `"<C-h>"`, `"<C-j>"`, `"<C-k>"`, `"<C-l>"` | The key for each move. `false` turns one off.                                                                                              |
| `keys.last`                                       | `"<C-\\>"`                                 | The key that goes back. `false` turns it off.                                                                                              |
| `modes`                                           | `{ "n" }`                                  | The modes the keys work in.                                                                                                                |
| `last_goes_to`                                    | not set                                    | `"split"` keeps the back key inside Neovim while another split exists. `"pane"` always asks Rex. Left out, it goes wherever you were last. |
| `last_includes_popups`                            | `true`                                     | `false` stops the back key from returning to a popup.                                                                                      |

## Examples

In `~/.config/rex/init.lua`:

```lua
require("pwe").setup({
  keys = { last = "alt+tab" },
  send_after = "ctrl+d",
})
```

In Neovim:

```lua
{
  "webdavis/pwe",
  lazy = false,
  opts = {
    keys = { last = "<M-Tab>" },
  },
}
```
