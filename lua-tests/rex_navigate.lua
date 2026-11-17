local bindings
local vim_in_front
local moved
local watched

rex = {
  bind = function(key, target)
    bindings[key] = target
  end,
  session = {
    focus_direction = function(arguments)
      moved = arguments
    end,
  },
}

local function bind_with(options)
  bindings = {}
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

print("rex navigate: ok")
