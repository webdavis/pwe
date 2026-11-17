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

local function pane_before(store, here)
  local current, previous = store.read()
  local before = current ~= here and current or previous
  if before and before ~= here then
    return before, before:match("^(%S+) (%S+)$")
  end
end

local function go_back(context, client)
  local store = watching(context)
  if not store then
    return
  end
  local here = context.session_id .. " " .. context.block_id
  local before, session, block = pane_before(store, here)
  if not session or not rex.session.focus_block({ session_id = session, block_id = block }) then
    return
  end
  store.write(before, here)
  if session ~= context.session_id and client then
    rex.call("client.perform", {
      client_id = client,
      action = "session.select",
      args = { session_id = session },
    })
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
