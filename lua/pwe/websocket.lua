local kinds = { text = 1, close = 8, ping = 9, pong = 10 }

local function opening(path)
  return table.concat({
    "GET " .. path .. " HTTP/1.1",
    "Host: localhost",
    "Upgrade: websocket",
    "Connection: Upgrade",
    "Sec-WebSocket-Key: cHdlLm52aW0ga2V5IDAwMQ==",
    "Sec-WebSocket-Version: 13",
    "Sec-WebSocket-Protocol: rex.control.v1",
    "",
    "",
  }, "\r\n")
end

local function opened(buffer)
  local finish = buffer:find("\r\n\r\n", 1, true)
  if not finish then
    return nil, buffer
  end
  return buffer:match("^HTTP/1%.1 101 ") ~= nil, buffer:sub(finish + 4)
end

local function frame(kind, payload)
  local masked = 128
  local size = #payload
  assert(size < 65536, "the message is too long for one frame")
  local length = size < 126 and string.char(masked + size)
    or string.char(masked + 126, math.floor(size / 256), size % 256)
  return string.char(128 + kinds[kind]) .. length .. "\0\0\0\0" .. payload
end

local function read(buffer)
  local frames = {}
  while #buffer >= 2 do
    local first, second = buffer:byte(1, 2)
    local size, start = second % 128, 3
    if size == 126 then
      if #buffer < 4 then
        break
      end
      local high, low = buffer:byte(3, 4)
      size, start = high * 256 + low, 5
    elseif size == 127 then
      if #buffer < 10 then
        break
      end
      size, start = 0, 11
      for _, byte in ipairs({ buffer:byte(3, 10) }) do
        size = size * 256 + byte
      end
    end
    if #buffer < start + size - 1 then
      break
    end
    frames[#frames + 1] = { kind = first % 16, payload = buffer:sub(start, start + size - 1) }
    buffer = buffer:sub(start + size)
  end
  return frames, buffer
end

return { kinds = kinds, opening = opening, opened = opened, frame = frame, read = read }
