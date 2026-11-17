local handlers = {}
local views = {}
local kept = {}
local stopped

store = {
  read = function()
    return kept.current, kept.previous
  end,
  write = function(current, previous)
    kept = { current = current, previous = previous }
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

local function expect(name, actual, wanted)
  if actual ~= wanted then
    error(name .. ": got " .. tostring(actual) .. ", wanted " .. tostring(wanted), 2)
  end
end

focus("session:1", "block:a")
expect("the first pane seen is the current one", kept.current, "session:1 block:a")
expect("the first pane seen has none before it", kept.previous, nil)

focus("session:1", "block:a")
expect("a change that keeps the pane keeps the record", kept.current, "session:1 block:a")
expect("a change that keeps the pane keeps what came before", kept.previous, nil)

focus("session:1", "block:b")
expect("the pane of the front window becomes the current one", kept.current, "session:1 block:b")
expect("the pane left behind becomes the one before", kept.previous, "session:1 block:a")

focus("session:2", "block:z")
expect("a pane in another session becomes the current one", kept.current, "session:2 block:z")
expect("the pane left in the first session becomes the one before", kept.previous, "session:1 block:b")

handlers.session_view_changed({ session_id = "session:gone" })
expect("a session that cannot be read changes nothing", kept.current, "session:2 block:z")
expect("a session that cannot be read keeps what came before", kept.previous, "session:1 block:b")

handlers.keymap_changed({})
expect("a config reload ends this watcher", stopped, true)
expect("a config reload removes its record", kept, nil)

print("rex watcher: ok")
