local websocket = require("pwe.websocket")

local connection
local sent = 0

local function socket_path()
  local path = (vim.env.REX_SERVER or ""):match("^unix://(/.*)$")
  return path and path:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

local function drop(broken)
  if connection ~= broken then
    return
  end
  connection = nil
  if not broken.pipe:is_closing() then
    broken.pipe:close()
  end
  for _, waiting in ipairs(broken.waiting) do
    vim.schedule(waiting.otherwise)
  end
end

local function write(open, kind, payload, otherwise)
  open.pipe:write(websocket.frame(kind, payload), function(failure)
    if failure then
      drop(open)
      if otherwise then
        vim.schedule(otherwise)
      end
    end
  end)
end

local function hear(open, frames)
  for _, frame in ipairs(frames) do
    if frame.kind == websocket.kinds.ping then
      write(open, "pong", frame.payload)
    elseif frame.kind == websocket.kinds.close then
      return drop(open)
    elseif frame.kind == websocket.kinds.text and not open.welcomed then
      open.welcomed = true
      write(open, "text", vim.json.encode({
        type = "request",
        id = "attach",
        method = "session.attach_all",
        payload = { event_scope = "session" },
      }))
    elseif frame.kind == websocket.kinds.text and not open.ready and frame.payload:find('"id":"attach"', 1, true) then
      open.ready = true
      local waiting_calls = open.waiting
      open.waiting = {}
      for _, waiting in ipairs(waiting_calls) do
        write(open, "text", waiting.request, waiting.otherwise)
      end
    end
  end
end

local function connect(opening, path)
  opening.pipe:connect(path, function(failure)
    if failure then
      return drop(opening)
    end
    opening.pipe:write(websocket.opening("/api/control"))
    opening.pipe:read_start(function(read_failure, chunk)
      if read_failure or not chunk then
        return drop(opening)
      end
      opening.buffer = opening.buffer .. chunk
      if not opening.upgraded then
        local accepted
        accepted, opening.buffer = websocket.opened(opening.buffer)
        if accepted == nil then
          return
        end
        if not accepted then
          return drop(opening)
        end
        opening.upgraded = true
        write(opening, "text", vim.json.encode({ type = "hello", api_revision = 14, client = { kind = "other", name = "pwe.nvim" } }))
      end
      local frames
      frames, opening.buffer = websocket.read(opening.buffer)
      hear(opening, frames)
    end)
  end)
end

local function call(method, payload, otherwise)
  local path = socket_path()
  if not path then
    return otherwise()
  end
  sent = sent + 1
  local request = vim.json.encode({ type = "request", id = tostring(sent), method = method, payload = payload })
  if connection and connection.ready then
    return write(connection, "text", request, otherwise)
  end
  local waiting = { request = request, otherwise = otherwise }
  if connection then
    return table.insert(connection.waiting, waiting)
  end
  local opening = { pipe = vim.uv.new_pipe(false), waiting = { waiting }, buffer = "" }
  connection = opening
  vim.defer_fn(function()
    if not opening.ready then
      drop(opening)
    end
  end, 1000)
  connect(opening, path)
end

return { call = call }
