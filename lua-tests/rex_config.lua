local function source(name)
  local file = assert(io.open("rex/" .. name .. ".lua"))
  local text = file:read("*a")
  file:close()
  return text
end

local sources = string.format(
  "local sources = { watch = %q, record = %q, front = %q, navigate = %q, last_pane = %q, watcher = %q }\n",
  source("watch"),
  source("record"),
  source("front"),
  source("navigate"),
  source("last_pane"),
  source("watcher")
)
local config = assert(loadstring(sources .. source("config"), "=config"))

local bindings

rex = {
  bind = function(key, target)
    bindings[key] = target
  end,
}

local function keys_with(options)
  bindings = {}
  config(options)
  local keys = {}
  for key in pairs(bindings) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return table.concat(keys, " ")
end

local expect = dofile("lua-tests/support/expect.lua")

expect(
  "the config binds the four moves, the last pane, and the key Neovim sends back",
  keys_with({}),
  "ctrl+\\ ctrl+alt+shift+super+f20 ctrl+h ctrl+j ctrl+k ctrl+l"
)
expect(
  "the keys the user chose reach both features",
  keys_with({ keys = { left = "alt+h", last = "alt+tab" } }),
  "alt+h alt+tab ctrl+alt+shift+super+f20 ctrl+j ctrl+k ctrl+l"
)

print("rex config: ok")
