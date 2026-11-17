local options, watching, vim_is_in_front = ...
local key = (options.keys or {}).last
if key == nil then
  key = "ctrl+\\"
end
if not key then
  return
end

local from_vim = "ctrl+alt+shift+super+f20"
local clients = {}

local function focus_the_newest_open(panes, here)
  local older = {}
  local reached
  for _, pane in ipairs(panes) do
    if pane ~= here then
      local session, block = pane:match("^(%S+) (%S+)$")
      if reached then
        older[#older + 1] = pane
      elseif session and rex.session.focus_block({ session_id = session, block_id = block }) then
        reached = { pane = pane, session = session, block = block }
      end
    end
  end
  return reached, older
end

local function window_of(session, block)
  local view = rex.session.view({ session_id = session })
  for _, window in ipairs(view and view.windows or {}) do
    if rex.json.encode(window):find(block, 1, true) then
      return window.window_id
    end
  end
end

local function apps()
  local listed = rex.call("client.list", {})
  local found = {}
  for _, client in ipairs(listed and listed.clients or {}) do
    if client.info and client.info.kind == "app" then
      found[#found + 1] = client.client_id
    end
  end
  return found
end

local function show(client, session, window)
  for _, asked in ipairs(client and { client } or apps()) do
    rex.call("client.perform", {
      client_id = asked,
      action = "session.select",
      args = { session_id = session, window_id = window },
      timeout_ms = 2000,
    })
  end
end

local function go_back(context, client)
  local store = watching(context)
  if not store then
    return
  end
  local here = context.session_id .. " " .. context.block_id
  local reached, older = focus_the_newest_open(store.read(), here)
  if not reached then
    return store.write({ here })
  end
  store.write({ reached.pane, here, unpack(older) })
  local session, block = reached.session, reached.block
  local window = window_of(session, block)
  if session ~= context.session_id or window ~= window_of(context.session_id, context.block_id) then
    show(client, session, window)
  end
end

rex.bind(key, function(context)
  if vim_is_in_front(context) then
    watching(context)
    clients[context.block_id] = context.client_id
    return false
  end
  go_back(context, context.client_id)
  return true
end)

rex.bind(from_vim, function(context)
  go_back(context, clients[context.block_id])
  return true
end)
