package.path = "lua/?.lua;" .. package.path

local window
local neighbours
local started
local maps = {}

vim = {
  api = {
    nvim_get_current_win = function()
      return window
    end,
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
    set = function(mode, key, action)
      maps[key] = { mode = mode, action = action }
    end,
  },
}

require("pwe.navigate").setup()

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

local directions = { h = "left", j = "down", k = "up", l = "right" }

for key, direction in pairs(directions) do
  local pressed = "<C-" .. key .. ">"
  expect(pressed .. " is a normal mode key", maps[pressed] and maps[pressed].mode, "n")

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

print("nvim navigate: ok")
