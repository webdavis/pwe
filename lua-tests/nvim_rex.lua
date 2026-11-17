package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local websocket = require("pwe.websocket")

local pipes
local connect_failure
local scheduled
local timers

local function new_pipe()
  local pipe = { written = {} }
  function pipe:connect(path, connected)
    self.path = path
    connected(connect_failure)
  end
  function pipe:write(data, written)
    self.written[#self.written + 1] = data
    if written and self.write_failure then
      written(self.write_failure)
    end
  end
  function pipe:read_start(reader)
    self.receive = function(data)
      reader(nil, data)
    end
    self.fail = function()
      reader("connection reset")
    end
  end
  function pipe:is_closing()
    return self.closed == true
  end
  function pipe:close()
    self.closed = true
  end
  pipes[#pipes + 1] = pipe
  return pipe
end

vim = {
  env = {},
  uv = { new_pipe = new_pipe },
  json = {
    encode = function(message)
      return "<" .. (message.method or message.type) .. ">"
    end,
  },
  schedule = function(action)
    scheduled[#scheduled + 1] = action
  end,
  defer_fn = function(action, milliseconds)
    timers[#timers + 1] = { ring = action, after = milliseconds }
  end,
}

local function fresh(server)
  package.loaded["pwe.rex"] = nil
  pipes = {}
  connect_failure = nil
  scheduled = {}
  timers = {}
  vim.env.REX_SERVER = server
  return require("pwe.rex")
end

local function fallbacks()
  local ran = {}
  return ran, function(name)
    return function()
      ran[#ran + 1] = name
    end
  end
end

local function run_scheduled()
  for _, action in ipairs(scheduled) do
    action()
  end
  scheduled = {}
end

local expect = dofile("lua-tests/support/expect.lua")

local accepted = "HTTP/1.1 101 Switching Protocols\r\n\r\n"
local welcome = "\129\009<welcome>"
local text = function(message)
  return websocket.frame("text", message)
end

local rex = fresh("unix:///Users/me/Application%20Support/rex/server.sock")
local ran, otherwise = fallbacks()

rex.call("session.focus_direction", {}, otherwise("first"))
expect("the first call opens Rex's socket", pipes[1].path, "/Users/me/Application Support/rex/server.sock")
expect("it asks for the control connection first", pipes[1].written[1], websocket.opening("/api/control"))
expect("nothing more is sent until Rex accepts", #pipes[1].written, 1)

pipes[1].receive(accepted)
expect("once accepted it says hello", pipes[1].written[2], text("<hello>"))
expect("the call still waits for the welcome", #pipes[1].written, 2)

pipes[1].receive(welcome)
expect("after the welcome it asks to act on every session", pipes[1].written[3], text("<session.attach_all>"))
expect("the call still waits for that to be granted", #pipes[1].written, 3)

pipes[1].receive("\129\007<event>")
expect("a message that is not the grant sends nothing", #pipes[1].written, 3)

pipes[1].receive('\129\015{"id":"attach"}')
expect("once granted the waiting call is sent", pipes[1].written[4], text("<session.focus_direction>"))

rex.call("client.key", {}, otherwise("second"))
expect("a later call uses the same connection", #pipes, 1)
expect("a later call is sent at once", pipes[1].written[5], text("<client.key>"))

pipes[1].receive("\137\004beat")
expect("a ping is answered with what it carried", pipes[1].written[6], websocket.frame("pong", "beat"))

pipes[1].receive("\129\007<event>")
expect("other messages from Rex send nothing", #pipes[1].written, 6)
run_scheduled()
expect("no call that was sent falls back", #ran, 0)

pipes[1].fail()
expect("a broken connection is closed", pipes[1].closed, true)
rex.call("client.key", {}, otherwise("third"))
expect("the next call opens a new connection", #pipes, 2)

rex = fresh("unix:///run/rex.sock")
ran, otherwise = fallbacks()
rex.call("client.key", {}, otherwise("sent"))
pipes[1].receive(accepted)
pipes[1].receive(welcome)
pipes[1].receive('\129\015{"id":"attach"}')
pipes[1].write_failure = "EPIPE"
rex.call("client.key", {}, otherwise("could not be written"))
run_scheduled()
expect("a call that could not be written falls back", ran[1], "could not be written")
expect("the connection it failed on is closed", pipes[1].closed, true)
rex.call("client.key", {}, otherwise("after"))
expect("the call after it opens a new connection", #pipes, 2)

rex = fresh("unix:///run/rex.sock")
ran, otherwise = fallbacks()
rex.call("client.key", {}, otherwise("waiting"))
pipes[1].receive("HTTP/1.1 403 Forbidden\r\n\r\n")
run_scheduled()
expect("a call waiting on a server that refuses falls back", ran[1], "waiting")
expect("a refused connection is closed", pipes[1].closed, true)

rex = fresh("unix:///run/rex.sock")
ran, otherwise = fallbacks()
rex.call("client.key", {}, otherwise("early"))
pipes[1].receive(accepted)
pipes[1].receive("\136\000")
run_scheduled()
expect("a call waiting when Rex closes the connection falls back", ran[1], "early")

rex = fresh("unix:///run/rex.sock")
ran, otherwise = fallbacks()
connect_failure = "ENOENT"
rex.call("client.key", {}, otherwise("no socket"))
run_scheduled()
expect("a call to a socket that cannot be opened falls back", ran[1], "no socket")

rex = fresh("unix:///run/rex.sock")
ran, otherwise = fallbacks()
rex.call("session.focus_direction", {}, otherwise("one"))
rex.call("client.key", {}, otherwise("two"))
expect("a second call made while connecting opens nothing more", #pipes, 1)
pipes[1].receive(accepted)
pipes[1].receive(welcome)
pipes[1].receive('\129\015{"id":"attach"}')
expect("the first call made while connecting is sent first", pipes[1].written[4], text("<session.focus_direction>"))
expect("the second call made while connecting is sent after it", pipes[1].written[5], text("<client.key>"))

rex = fresh(nil)
ran, otherwise = fallbacks()
rex.call("client.key", {}, otherwise("no address"))
expect("with no socket address the call falls back at once", ran[1], "no address")
expect("with no socket address nothing is opened", #pipes, 0)

rex = fresh("tcp://elsewhere:7000")
ran, otherwise = fallbacks()
rex.call("client.key", {}, otherwise("not local"))
expect("an address that is not a local socket falls back", ran[1], "not local")

rex = fresh("unix:///run/rex.sock")
ran, otherwise = fallbacks()
rex.call("client.key", {}, otherwise("never granted"))
pipes[1].receive(accepted)
pipes[1].receive(welcome)
expect("a new connection is given one second to be granted", timers[1] and timers[1].after, 1000)
timers[1].ring()
run_scheduled()
expect("a call still waiting when the second is up falls back", ran[1], "never granted")
expect("the connection that was never granted is closed", pipes[1].closed, true)
rex.call("client.key", {}, otherwise("after"))
expect("the call after it opens a new connection", #pipes, 2)

rex = fresh("unix:///run/rex.sock")
ran, otherwise = fallbacks()
rex.call("client.key", {}, otherwise("granted in time"))
pipes[1].receive(accepted)
pipes[1].receive(welcome)
pipes[1].receive('\129\015{"id":"attach"}')
timers[1].ring()
run_scheduled()
expect("a connection granted in time stays open when the second is up", pipes[1].closed, nil)
expect("and its call does not fall back", #ran, 0)

print("nvim rex: ok")
