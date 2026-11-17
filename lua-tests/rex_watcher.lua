local handlers = {}
local views = {}
local kept = {}
local stopped

store = {
  read = function()
    return kept
  end,
  write = function(panes)
    kept = panes
  end,
  remove = function()
    kept = nil
  end,
}

rex = {
  on = function(event, handler)
    handlers[event] = handler
  end,
  session = {
    view = function(arguments)
      local view = views[arguments.session_id]
      if not view then
        return nil, "no such session"
      end
      return view
    end,
  },
  stop = function()
    stopped = true
  end,
}

dofile("rex/watcher.lua")

local function focus(session, block)
  views[session] = {
    active_window_id = "window:front",
    windows = {
      { window_id = "window:back", focused_block_id = "block:elsewhere" },
      { window_id = "window:front", focused_block_id = block },
    },
  }
  handlers.session_view_changed({ session_id = session })
end

local expect = dofile("lua-tests/support/expect.lua")

local function recorded()
  return table.concat(kept, ", ")
end

focus("session:1", "block:a")
expect("the first pane seen is the only one recorded", recorded(), "session:1 block:a")

focus("session:1", "block:a")
expect("a change that keeps the pane keeps the record", recorded(), "session:1 block:a")

focus("session:1", "block:b")
expect("the pane of the front window goes first, the one left after it", recorded(), "session:1 block:b, session:1 block:a")

focus("session:2", "block:z")
expect(
  "a pane in another session goes first, and the earlier ones stay in order",
  recorded(),
  "session:2 block:z, session:1 block:b, session:1 block:a"
)

focus("session:1", "block:a")
expect(
  "a pane seen again moves to the front and is listed once",
  recorded(),
  "session:1 block:a, session:2 block:z, session:1 block:b"
)

handlers.session_view_changed({ session_id = "session:gone" })
expect(
  "a session that cannot be read changes nothing",
  recorded(),
  "session:1 block:a, session:2 block:z, session:1 block:b"
)

for number = 1, 30 do
  focus("session:3", "block:" .. number)
end
expect("only the twenty most recent panes are kept", #kept, 20)
expect("the newest of them is first", kept[1], "session:3 block:30")

handlers.keymap_changed({})
expect("a config reload ends this watcher", stopped, true)
expect("a config reload removes its record", kept, nil)

print("rex watcher: ok")
