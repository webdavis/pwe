local bindings = {}
local foreground
local moved

rex = {
  bind = function(key, target)
    bindings[key] = target
  end,
  block = {
    call = function(creator, method, arguments)
      assert(creator == "com.superlogical.terminal", "asked " .. tostring(creator))
      assert(method == "process", "called " .. tostring(method))
      assert(arguments.block_id == "block:pressed", "asked about " .. tostring(arguments.block_id))
      return { foreground = foreground }
    end,
  },
  session = {
    focus_direction = function(arguments)
      moved = arguments
    end,
  },
}

dofile("rex/navigate.lua")

local function press(key, program_in_front)
  foreground = program_in_front
  moved = nil
  local handled = bindings[key]({ block_id = "block:pressed", session_id = "session:pressed" })
  return handled, moved
end

local function expect(name, actual, wanted)
  if actual ~= wanted then
    error(name .. ": got " .. tostring(actual) .. ", wanted " .. tostring(wanted), 2)
  end
end

local directions = { ["ctrl+h"] = "left", ["ctrl+j"] = "down", ["ctrl+k"] = "up", ["ctrl+l"] = "right" }

for key, direction in pairs(directions) do
  local handled, move = press(key, { name = "zsh", argv0 = "-zsh" })
  expect(key .. " over a shell is handled", handled, true)
  expect(key .. " over a shell moves", move and move.direction, direction)
  expect(key .. " moves in the pressed session", move and move.session_id, "session:pressed")
  expect(key .. " stops at the outer edge", move and move.wrap, false)
end

for key in pairs(directions) do
  local handled, move = press(key, { name = "nvim", argv0 = "nvim" })
  expect(key .. " over Neovim is passed on", handled, false)
  expect(key .. " over Neovim moves nothing", move, nil)
end

local handled, move = press("ctrl+h", { name = "vim", argv0 = "/usr/bin/vim" })
expect("Vim by name is passed on", handled, false)
expect("Vim by name moves nothing", move, nil)

handled, move = press("ctrl+h", { name = "editor", argv0 = "/opt/homebrew/bin/nvim" })
expect("Neovim started under another name is passed on", handled, false)
expect("Neovim started under another name moves nothing", move, nil)

handled, move = press("ctrl+l", nil)
expect("a pane reporting no program is handled", handled, true)
expect("a pane reporting no program moves", move and move.direction, "right")

handled, move = press("ctrl+l", { name = "notvim", argv0 = "/usr/local/bin/notvim" })
expect("a program whose name only contains vim is handled", handled, true)
expect("a program whose name only contains vim moves", move and move.direction, "right")

print("rex navigate: ok")
