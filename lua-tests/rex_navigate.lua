local bindings
local written
local vim_in_front
local moved
local watched

rex = {
  bind = function(key, target, arguments)
    bindings[key] = target
    written[key] = arguments and arguments.data
  end,
  session = {
    focus_direction = function(arguments)
      moved = arguments
    end,
  },
}

local function bind_with(options)
  bindings = {}
  written = {}
  watched = 0
  assert(loadfile("rex/navigate.lua"))(options, function()
    watched = watched + 1
  end, function(context)
    assert(context.block_id == "block:pressed", "asked about " .. tostring(context.block_id))
    return vim_in_front
  end)
end

local function press(key, over_vim)
  vim_in_front = over_vim
  moved = nil
  local handled = bindings[key]({ block_id = "block:pressed", session_id = "session:pressed" })
  return handled, moved
end

local expect = dofile("lua-tests/support/expect.lua")
local count = dofile("lua-tests/support/count.lua")

local directions = { ["ctrl+h"] = "left", ["ctrl+j"] = "down", ["ctrl+k"] = "up", ["ctrl+l"] = "right" }

bind_with({})

for key, direction in pairs(directions) do
  local handled, move = press(key, false)
  expect(key .. " over a shell is handled", handled, true)
  expect(key .. " over a shell moves", move and move.direction, direction)
  expect(key .. " moves in the pressed session", move and move.session_id, "session:pressed")
  expect(key .. " stops at the outer edge", move and move.wrap, false)

  handled, move = press(key, true)
  expect(key .. " over Vim is passed on", handled, false)
  expect(key .. " over Vim moves nothing", move, nil)
end

bind_with({})
press("ctrl+h", false)
press("ctrl+l", true)
expect("every press lets the pane watcher start", watched, 2)

bind_with({ keys = { left = "alt+h", down = false } })
expect("a key the user chose replaces the usual one", bindings["ctrl+h"], nil)
local _, move = press("alt+h", false)
expect("the chosen key moves the same way", move and move.direction, "left")
expect("a key the user turned off is not bound", bindings["ctrl+j"], nil)
expect("the other keys keep their usual place", count(bindings), 3)

bind_with({ send_after = "ctrl+d" })
local characters = { ["ctrl+h"] = "\8", ["ctrl+j"] = "\10", ["ctrl+k"] = "\11", ["ctrl+l"] = "\12" }
for key, character in pairs(characters) do
  local sequence = "ctrl+d>" .. key
  expect(sequence .. " writes to the program", bindings[sequence], "com.superlogical.terminal.write")
  expect(sequence .. " writes the character " .. key .. " stands for", written[sequence], character)
end
expect("the four moves stay bound beside the four sequences", count(bindings), 8)

bind_with({ send_after = "ctrl+d", keys = { left = "alt+h", down = false, up = "ctrl+shift+k", right = "ctrl+P" } })
expect("a chosen key that stands for no character gets no sequence", bindings["ctrl+d>alt+h"], nil)
expect("a key with more than control held gets no sequence", bindings["ctrl+d>ctrl+shift+k"], nil)
expect("a key the user turned off gets no sequence", bindings["ctrl+d>ctrl+j"], nil)
expect("a chosen control key writes its own character", written["ctrl+d>ctrl+P"], "\16")

print("rex navigate: ok")
