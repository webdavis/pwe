package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local websocket = require("pwe.websocket")

local expect = dofile("lua-tests/support/expect.lua")

local function bytes(text)
  return (text:gsub(".", function(character)
    return string.format("%02x ", character:byte())
  end))
end

local opening = websocket.opening("/api/control")
expect("the opening asks for the control connection", opening:match("^GET /api/control HTTP/1%.1\r\n") ~= nil, true)
expect("the opening asks for Rex's protocol", opening:find("\r\nSec-WebSocket-Protocol: rex.control.v1\r\n", 1, true) ~= nil, true)
expect("the opening ends its headers", opening:sub(-4), "\r\n\r\n")

local accepted, rest = websocket.opened("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n\r\nmore")
expect("a server that switches protocols has accepted", accepted, true)
expect("what follows the answer is kept", rest, "more")
expect("a server that answers anything else has not", (websocket.opened("HTTP/1.1 403 Forbidden\r\n\r\n")), false)
expect("an answer still arriving is waited for", (websocket.opened("HTTP/1.1 101 Switch")), nil)

expect("a short message is one masked text frame", bytes(websocket.frame("text", "hi")), "81 82 00 00 00 00 68 69 ")
local long = websocket.frame("text", string.rep("x", 300))
expect("a longer message carries its length in two bytes", bytes(long:sub(1, 4)), "81 fe 01 2c ")
expect("a longer message keeps its whole text", #long, 4 + 4 + 300)
expect("a pong carries what the ping carried", bytes(websocket.frame("pong", "a")), "8a 81 00 00 00 00 61 ")

local frames, left = websocket.read("\129\002hi\137\001a\129\005par")
expect("two whole frames are read", #frames, 2)
expect("the first is text", frames[1].kind, websocket.kinds.text)
expect("with its text", frames[1].payload, "hi")
expect("the second is a ping", frames[2].kind, websocket.kinds.ping)
expect("a frame still arriving is kept for later", left, "\129\005par")

frames = websocket.read("\129\126\001\044" .. string.rep("y", 300))
expect("a frame with a two byte length is read whole", frames[1].payload, string.rep("y", 300))

frames = websocket.read("\129\127\000\000\000\000\000\001\000\000" .. string.rep("z", 65536))
expect("a frame with an eight byte length is read whole", #frames[1].payload, 65536)

print("nvim websocket: ok")
