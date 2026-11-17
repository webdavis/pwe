local record, watcher = ...
local store

local function endpoint_of(status)
  for _, listener in ipairs(status.listeners or {}) do
    if listener.primary then
      return listener.endpoint
    end
  end
end

local function start()
  local status, failure = rex.call("server.status", {})
  if not status then
    return nil, failure
  end
  local endpoint = endpoint_of(status)
  if not endpoint then
    return nil, "the server names no address"
  end
  local program = rex.exec({ "/bin/ps", "-o", "comm=", "-p", tostring(status.pid) })
  if not program or not program.ok then
    return nil, program and program.stderr or "ps did not run"
  end
  local path = os.tmpname()
  local script = string.format("local store = assert(loadstring(%q))(%q)\n", record, path) .. watcher
  local command = { (program.stdout:gsub("%s+$", "")), "-S", endpoint, "do", "--all", "-e", script }
  local started, start_failure = rex.exec.start(command, { detach = true })
  if not started then
    return nil, start_failure
  end
  return assert(loadstring(record, "=pwe/record"))(path)
end

return function(context)
  if store == nil then
    local started, failure = start()
    if started then
      started.write({ context.session_id .. " " .. context.block_id })
    else
      print("pwe: the last pane is not tracked: " .. tostring(failure))
    end
    store = started or false
  end
  return store or nil
end
