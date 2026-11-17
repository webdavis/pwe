package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local asked
package.loaded["pwe.rex"] = {
  call = function(method, payload, otherwise)
    asked = { method = method, payload = payload }
    otherwise()
  end,
}

local window
local neighbours
local started
local maps

vim = {
  api = {
    nvim_get_current_win = function()
      return window
    end,
    nvim_create_augroup = function() end,
    nvim_create_autocmd = function() end,
  },
  cmd = {
    wincmd = function(key)
      if neighbours[key] == "refused" then
        error("E11: Invalid in command-line window")
      end
      window = neighbours[key] or window
    end,
  },
  env = {},
  system = function(command)
    started = command
  end,
  keymap = {
    set = function(modes, key, action)
      maps[key] = { modes = table.concat(modes, " "), action = action }
    end,
  },
}

local function setup(options)
  maps = {}
  require("pwe").setup(options)
  maps["<C-\\>"] = nil
end

local function press(key, splits, rex_folder)
  window = 1
  neighbours = splits
  started = nil
  vim.env.REX_BIN_DIR = rex_folder
  maps[key].action()
  return window, started and table.concat(started, " ")
end

local function expect(name, actual, wanted)
  if actual ~= wanted then
    error(name .. ": got " .. tostring(actual) .. ", wanted " .. tostring(wanted), 2)
  end
end

local function count(list)
  local total = 0
  for _ in pairs(list) do
    total = total + 1
  end
  return total
end

local directions = { h = "left", j = "down", k = "up", l = "right" }

setup()

for key, direction in pairs(directions) do
  local pressed = "<C-" .. key .. ">"
  expect(pressed .. " is a normal mode key", maps[pressed] and maps[pressed].modes, "n")

  local reached, command = press(pressed, { [key] = 2 }, "/rex/bin")
  expect(pressed .. " with a split that way moves to it", reached, 2)
  expect(pressed .. " with a split that way leaves Rex alone", command, nil)

  reached, command = press(pressed, {}, "/rex/bin")
  expect(pressed .. " at the last split stays in it", reached, 1)
  expect(pressed .. " at the last split asks Rex to move", command, "/rex/bin/rex focus " .. direction)
end

local reached, command = press("<C-h>", {}, nil)
expect("outside Rex the last split stays put", reached, 1)
expect("outside Rex nothing is started", command, nil)

reached, command = press("<C-l>", { l = "refused" }, "/rex/bin")
expect("a window Neovim refuses to leave stays put", reached, 1)
expect("a window Neovim refuses to leave still asks Rex to move", command, "/rex/bin/rex focus right")

setup({ keys = { left = "<M-h>", down = false } })
expect("a key the user chose replaces the usual one", maps["<C-h>"], nil)
reached, command = press("<M-h>", {}, "/rex/bin")
expect("the chosen key moves the same way", command, "/rex/bin/rex focus left")
expect("a key the user turned off is not set", maps["<C-j>"], nil)
expect("the other keys keep their usual place", count(maps), 3)

setup({ modes = { "n", "i" } })
expect("the modes the user chose are the ones the keys work in", maps["<C-h>"].modes, "n i")

setup()
vim.env.REX_SESSION = "session:1"
asked = nil
press("<C-k>", {}, "/rex/bin")
expect("at the last split Rex is asked over its connection first", asked and asked.method, "session.focus_direction")
expect("for this pane's session", asked.payload.session_id, "session:1")
expect("in the pressed direction", asked.payload.direction, "up")
expect("stopping at the outer edge", asked.payload.wrap, false)
asked = nil
press("<C-k>", { k = 2 }, "/rex/bin")
expect("with a split that way Rex is not asked at all", asked, nil)

print("nvim navigate: ok")
