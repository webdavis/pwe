local bindings
local tracked
local watched
local kept
local vim_in_front
local focused
local focus_failure
local performed
local asked

local store = {
  read = function()
    return kept.current, kept.previous
  end,
  write = function(current, previous)
    kept = { current = current, previous = previous }
  end,
}

local views = {
  ["session:1"] = {
    windows = {
      { window_id = "window:front", blocks = "block:a block:b" },
      { window_id = "window:tab2", blocks = "block:t" },
    },
  },
  ["session:2"] = { windows = { { window_id = "window:z", blocks = "block:z" } } },
}

rex = {
  bind = function(key, target)
    bindings[key] = target
  end,
  json = {
    encode = function(window)
      return window.blocks
    end,
  },
  session = {
    focus_block = function(arguments)
      focused = arguments
      if focus_failure then
        return nil, focus_failure
      end
      return {}
    end,
    view = function(arguments)
      return views[arguments.session_id]
    end,
  },
  call = function(method, arguments)
    if method == "client.list" then
      return {
        clients = {
          { client_id = "client:cli", info = { kind = "cli" } },
          { client_id = "client:app", info = { kind = "app" } },
          { client_id = "client:nameless" },
        },
      }
    end
    assert(method == "client.perform", "called " .. tostring(method))
    performed = arguments
    asked[#asked + 1] = arguments.client_id
    return {}
  end,
}

local function bind_with(options)
  bindings = {}
  assert(loadfile("rex/last_pane.lua"))(options, function()
    watched = watched + 1
    return tracked
  end, function()
    return vim_in_front
  end)
end

local from_vim = "ctrl+alt+shift+super+f20"

local function press(current, previous, conditions)
  conditions = conditions or {}
  kept = { current = current, previous = previous }
  tracked = not conditions.untracked and store or nil
  watched = 0
  vim_in_front = conditions.over_vim or false
  focused = nil
  focus_failure = conditions.pane_is_gone and "no such block" or nil
  performed = nil
  asked = {}
  return bindings[conditions.key or "ctrl+\\"]({
    session_id = "session:1",
    block_id = "block:a",
    client_id = conditions.client,
  })
end

local function expect(name, actual, wanted)
  if actual ~= wanted then
    error(name .. ": got " .. tostring(actual) .. ", wanted " .. tostring(wanted), 2)
  end
end

bind_with({})

expect("the key is handled", press("session:1 block:a", "session:1 block:b"), true)
expect("it goes to the pane before this one", focused and focused.block_id, "block:b")
expect("it names that pane's session", focused and focused.session_id, "session:1")
expect("a pane in the same tab asks no client for anything", performed, nil)
expect("the pane gone to becomes the current one", kept.current, "session:1 block:b")
expect("the pane left becomes the one before, so the key goes back", kept.previous, "session:1 block:a")

press("session:1 block:a", "session:2 block:z", { client = "client:me" })
expect("a pane in another session is focused there", focused and focused.session_id, "session:2")
expect("the client that pressed the key is asked", performed and performed.client_id, "client:me")
expect("it is asked to show a session", performed and performed.action, "session.select")
expect("it is asked for the other session", performed and performed.args.session_id, "session:2")
expect("and for the tab the pane is in", performed and performed.args.window_id, "window:z")

press("session:1 block:a", "session:1 block:t", { client = "client:me" })
expect("a pane in another tab of the same session is focused", focused and focused.block_id, "block:t")
expect("the client is asked to show that session", performed and performed.args.session_id, "session:1")
expect("at the tab the pane is in", performed and performed.args.window_id, "window:tab2")

press("session:2 block:z", "session:3 block:q")
expect("when the record is behind, its current pane is the one before this", focused and focused.block_id, "block:z")
expect("the record then names the pane gone to", kept.current, "session:2 block:z")
expect("and this pane as the one before", kept.previous, "session:1 block:a")

expect("with no pane before, the key is still handled", press("session:1 block:a", ""), true)
expect("with no pane before, nothing is focused", focused, nil)

expect("with nothing recorded, the key is still handled", press(nil, nil), true)
expect("with nothing recorded, nothing is focused", focused, nil)

expect(
  "when panes are not tracked, the key is still handled",
  press("session:1 block:a", "session:1 block:b", { untracked = true }),
  true
)
expect("when panes are not tracked, nothing is focused", focused, nil)

press("session:1 block:a", "session:2 block:closed", { pane_is_gone = true, client = "client:me" })
expect("a pane that is gone leaves the record alone", kept.previous, "session:2 block:closed")
expect("a pane that is gone switches no session", performed, nil)

bind_with({})
expect(
  "over Vim the key is passed on, for Vim to decide by its mode",
  press("session:1 block:a", "session:1 block:b", { over_vim = true, client = "client:me" }),
  false
)
expect("over Vim nothing is focused", focused, nil)
expect("over Vim the pane watcher still starts", watched, 1)

expect(
  "the key Neovim sends back is handled",
  press("session:1 block:a", "session:2 block:z", { key = from_vim, over_vim = true, client = "client:neovim" }),
  true
)
expect("the key Neovim sends back goes to the pane before, even over Vim", focused and focused.block_id, "block:z")
expect(
  "the session switch is asked of the client whose key press reached Vim",
  performed and performed.client_id,
  "client:me"
)

bind_with({})
press("session:1 block:a", "session:2 block:z", { key = from_vim, client = "client:neovim" })
expect("with no client known, the pane is still focused", focused and focused.block_id, "block:z")
expect("with no client known, every app is asked and nothing else", table.concat(asked, " "), "client:app")

bind_with({ keys = { last = "alt+tab" } })
expect("a key the user chose replaces the usual one", bindings["ctrl+\\"], nil)
expect("the chosen key is bound", type(bindings["alt+tab"]), "function")
expect("the key Neovim sends back stays bound", type(bindings[from_vim]), "function")

bind_with({ keys = { last = false } })
expect("a key the user turned off binds nothing", next(bindings), nil)

print("rex last pane: ok")
