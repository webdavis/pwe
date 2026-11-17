package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local asked
package.loaded["pwe.rex"] = {
  call = function(method, payload, otherwise)
    asked = { method = method, payload = payload }
    otherwise()
  end,
}

local started
local maps
local events
local window
local floating
local closed

local function happen(event)
  for _, callback in ipairs(events[event] or {}) do
    callback()
  end
end

vim = {
  env = {},
  json = {
    encode = function(value)
      return value
    end,
  },
  system = function(command)
    started = command
  end,
  keymap = {
    set = function(modes, key, action)
      maps[key] = { modes = table.concat(modes, " "), action = action }
    end,
  },
  cmd = {
    wincmd = function() end,
  },
  api = {
    nvim_create_augroup = function(name)
      return name
    end,
    nvim_create_autocmd = function(event, options)
      events[event] = events[event] or {}
      table.insert(events[event], options.callback)
    end,
    nvim_get_current_win = function()
      return window
    end,
    nvim_set_current_win = function(id)
      window = id
      happen("WinEnter")
    end,
    nvim_win_get_config = function()
      return { relative = floating[window] and "editor" or "" }
    end,
    nvim_win_is_valid = function(id)
      return not closed[id]
    end,
  },
}

local function setup(options)
  maps = {}
  events = {}
  window, floating, closed = 1, {}, {}
  for _, name in ipairs({ "pwe", "pwe.navigate", "pwe.last_pane" }) do
    package.loaded[name] = nil
  end
  require("pwe").setup(options)
end

local function enter(split)
  window = split
  happen("WinEnter")
end

local function enter_floating(popup)
  floating[popup] = true
  enter(popup)
end

local function press(key, pane)
  started = nil
  vim.env.REX_BIN_DIR = pane and pane.folder
  vim.env.REX_SESSION = pane and pane.session
  vim.env.REX_BLOCK = pane and pane.block
  maps[key].action()
  return started
end

local function expect(name, actual, wanted)
  if actual ~= wanted then
    error(name .. ": got " .. tostring(actual) .. ", wanted " .. tostring(wanted), 2)
  end
end

local in_rex = { folder = "/rex/bin", session = "session:1", block = "block:a" }

setup()
expect("ctrl-\\ is a normal mode key", maps["<C-\\>"] and maps["<C-\\>"].modes, "n")

local command = press("<C-\\>", in_rex)
expect("it asks Rex to take a key", table.concat(command, " ", 1, 4), "/rex/bin/rex api call client.key")
local sent = command[5]
expect("the key goes to this pane's session", sent.session_id, "session:1")
expect("the key goes to this pane", sent.block_id, "block:a")
expect("the key is the one Rex keeps for Neovim", sent.key.key, "f20")
expect("with all four modifiers", sent.key.mods, "shift+ctrl+alt+super")
expect("as a press", sent.key.action, "press")

expect("outside Rex nothing is started", press("<C-\\>", nil), nil)

setup({ keys = { last = "<M-Tab>" } })
expect("a key the user chose replaces the usual one", maps["<C-\\>"], nil)
expect("the chosen key asks Rex the same way", press("<M-Tab>", in_rex)[5].key.key, "f20")

setup({ keys = { last = false } })
expect("a key the user turned off is not set", maps["<C-\\>"], nil)

setup({ modes = { "n", "i" } })
expect("the modes the user chose are the ones the key works in", maps["<C-\\>"].modes, "n i")

setup()
asked = nil
press("<C-\\>", in_rex)
expect("Rex is asked over its connection first", asked and asked.method, "client.key")
expect("for the same key", asked.payload.key.key, "f20")
expect("in this pane", asked.payload.block_id, "block:a")

setup()
enter(2)
expect("after a move between splits it starts nothing", press("<C-\\>", in_rex), nil)
expect("after a move between splits it goes back to the split before", window, 1)
press("<C-\\>", in_rex)
expect("pressed again it returns to the split it left", window, 2)

setup()
enter_floating(9)
enter(2)
expect("after a popup opened the new split, it starts nothing", press("<C-\\>", in_rex), nil)
expect("it goes back to the split before the popup, never to the popup", window, 1)

setup()
enter(2)
enter_floating(9)
enter(2)
press("<C-\\>", in_rex)
expect("a popup that came and went leaves the split before as it was", window, 1)

setup()
enter(2)
happen("FocusLost")
expect("after Neovim lost focus to another pane it asks Rex", press("<C-\\>", in_rex) ~= nil, true)
expect("after Neovim lost focus the split stays", window, 2)

setup()
enter(2)
maps["<C-l>"].action()
expect("a move key at the outer edge, where nothing moves, starts nothing on ctrl-\\", press("<C-\\>", nil), nil)
expect("and ctrl-\\ still goes to the split before", window, 1)

setup()
enter(2)
closed[1] = true
expect("with the split before closed it asks Rex", press("<C-\\>", in_rex) ~= nil, true)

setup()
expect("with one split only it asks Rex", press("<C-\\>", in_rex) ~= nil, true)

setup()
enter(2)
expect("outside Rex it still goes back to the split before", press("<C-\\>", nil), nil)
expect("outside Rex the split changes", window, 1)

setup({ last_goes_to = "pane" })
enter(2)
expect("told to go to panes only, it asks Rex after a move between splits", press("<C-\\>", in_rex) ~= nil, true)
expect("told to go to panes only, the split stays", window, 2)

setup({ last_goes_to = "split" })
enter(2)
happen("FocusLost")
expect("told to stay in Neovim, it goes to the other split even after focus was lost", press("<C-\\>", in_rex), nil)
expect("told to stay in Neovim, the split changes", window, 1)

setup({ last_goes_to = "split" })
expect("told to stay in Neovim with one split only, it asks Rex", press("<C-\\>", in_rex) ~= nil, true)

print("nvim last pane: ok")
