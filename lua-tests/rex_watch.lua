local status
local status_failure
local program
local program_failure
local start_failure
local asked
local started
local logged

rex = {
  call = function(method)
    assert(method == "server.status", "called " .. tostring(method))
    asked.status = asked.status + 1
    return status, status_failure
  end,
  exec = setmetatable({
    start = function(command, options)
      started[#started + 1] = { command = command, options = options }
      if start_failure then
        return nil, start_failure
      end
      return {}
    end,
  }, {
    __call = function(_, command)
      asked.program = table.concat(command, " ")
      return program, program_failure
    end,
  }),
}

local say = print
print = function(message)
  logged = message
end

os.tmpname = function()
  return "/tmp/pane-record"
end

local function fresh()
  status = {
    pid = 42,
    listeners = {
      { endpoint = "tcp://elsewhere:1", primary = false },
      { endpoint = "unix:///run/rex.sock", primary = true },
    },
  }
  status_failure = nil
  program = { ok = true, stdout = "/apps/Rex/rex\n" }
  program_failure = nil
  start_failure = nil
  asked = { status = 0 }
  started = {}
  logged = nil
  first_recorded = nil
  return assert(loadfile("rex/watch.lua"))(
    "local at = ... return { kept_at = at, write = function(panes) first_recorded = table.concat(panes, ', ') end }",
    "store_the_watcher_got = store"
  )
end

local function expect(name, actual, wanted)
  if actual ~= wanted then
    error(name .. ": got " .. tostring(actual) .. ", wanted " .. tostring(wanted), 2)
  end
end

local watching = fresh()
expect("nothing starts until a key is pressed", #started, 0)

local pressed = { session_id = "session:1", block_id = "block:a" }
local store = watching(pressed)
expect("the first press returns a record kept in a fresh temp file", store and store.kept_at, "/tmp/pane-record")
expect("the record starts with the pane the key was pressed in", first_recorded, "session:1 block:a")
expect("the server's program is found from its process id", asked.program, "/bin/ps -o comm= -p 42")
expect(
  "the watcher runs as a Rex script against this server, hearing every session",
  table.concat(started[1].command, " ", 1, 6),
  "/apps/Rex/rex -S unix:///run/rex.sock do --all -e"
)
assert(loadstring(started[1].command[7], "=script"))()
expect("the watcher's script keeps its record in the same file", store_the_watcher_got.kept_at, "/tmp/pane-record")
expect("the watcher outlives the key press", started[1].options.detach, true)

expect("a later press returns the same record", watching(), store)
expect("a later press starts nothing more", #started, 1)
expect("a later press asks the server nothing more", asked.status, 1)

watching = fresh()
status, status_failure = nil, "server is busy"
expect("a server that will not say who it is gives no record", watching(), nil)
expect("that failure is logged", logged, "pwe: the last pane is not tracked: server is busy")
watching()
expect("that failure is not tried again on every press", asked.status, 1)

watching = fresh()
program = { ok = false, stderr = "ps: no such process" }
expect("a server whose program is not found gives no record", watching(), nil)
expect("nothing is started without the program", #started, 0)

watching = fresh()
start_failure = "cannot start"
expect("a watcher that does not start gives no record", watching(), nil)
expect("that failure is logged too", logged, "pwe: the last pane is not tracked: cannot start")

say("rex watch: ok")
