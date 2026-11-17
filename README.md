# pwe

One set of keys for moving between Neovim splits and Rex panes, and one key to go back to the last place you were.

## Install

```sh
cargo install --git https://github.com/webdavis/pwe
pwe rex get loader > ~/.config/rex/pwe.lua
```

In `~/.config/rex/init.lua`:

```lua
require("pwe").setup()
```

In Neovim, add this repo as a plugin and call the same thing:

```lua
require("pwe").setup()
```

## Keys

| Key | What it does |
| --- | --- |
| `ctrl-h` `ctrl-j` `ctrl-k` `ctrl-l` | Move left, down, up or right, to the next split or the next pane |
| `ctrl-\` | Go back to the last split or pane |

## Settings

Both sides take a table in `setup`. A setting left out keeps its default.

### Rex

| Setting | Default | What it does |
| --- | --- | --- |
| `keys.left`, `keys.down`, `keys.up`, `keys.right` | `"ctrl+h"`, `"ctrl+j"`, `"ctrl+k"`, `"ctrl+l"` | The key for each move. `false` turns one off. |
| `keys.last` | `"ctrl+\\"` | The key that goes back. `false` turns it off. |
| `send_after` | not set | A prefix key, such as `"ctrl+d"`. The prefix then a move key sends that key to the program in the pane. Works for move keys made of ctrl and one letter. |

### Neovim

| Setting | Default | What it does |
| --- | --- | --- |
| `keys.left`, `keys.down`, `keys.up`, `keys.right` | `"<C-h>"`, `"<C-j>"`, `"<C-k>"`, `"<C-l>"` | The key for each move. `false` turns one off. |
| `keys.last` | `"<C-\\>"` | The key that goes back. `false` turns it off. |
| `modes` | `{ "n" }` | The modes the keys work in. |
| `last_goes_to` | not set | `"split"` keeps the back key inside Neovim while another split exists. `"pane"` always asks Rex. Left out, it goes wherever you were last. |
| `last_includes_popups` | `true` | `false` stops the back key from returning to a popup. |

## Example

```lua
require("pwe").setup({
  keys = { last = "alt+tab" },
  send_after = "ctrl+d",
})
```
