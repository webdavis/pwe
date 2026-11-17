local file = assert(io.open("rex/loader.lua"))
local loader = assert(loadstring('local pwe = "/somewhere/pwe"\n' .. file:read("*a"), "=loader"))
file:close()

local asked
local answer
local failure
local logged

rex = {
  exec = function(command)
    asked = table.concat(command, " ")
    return answer, failure
  end,
  log = function(message)
    logged = message
  end,
}

local function load_with(result, exec_failure)
  asked = nil
  answer = result
  failure = exec_failure
  logged = nil
  keys_were_set = nil
  loader()
  return keys_were_set, logged
end

local function expect(name, actual, wanted)
  if actual ~= wanted then
    error(name .. ": got " .. tostring(actual) .. ", wanted " .. tostring(wanted), 2)
  end
end

local set, log = load_with({ ok = true, stdout = "keys_were_set = true" })
expect("the loader asks the saved pwe for its config", asked, "/somewhere/pwe rex get config")
expect("the Lua pwe prints is run", set, true)
expect("a good load logs nothing", log, nil)

set, log = load_with(nil, "no such file")
expect("a missing pwe sets no keys", set, nil)
expect("a missing pwe is logged with the reason", log, "pwe: its Rex keys were not loaded: no such file")

set, log = load_with({ ok = false, stdout = "keys_were_set = true", stderr = "usage: pwe" })
expect("a failing pwe sets no keys", set, nil)
expect("a failing pwe is logged with what it said", log, "pwe: its Rex keys were not loaded: usage: pwe")

set, log = load_with({ ok = true, stdout = "keys_were_set = = true" })
expect("Lua that does not parse sets no keys", set, nil)
expect("Lua that does not parse is logged by line", log and log:match("^pwe: its Rex keys were not loaded: pwe:1: ") ~= nil, true)

print("rex loader: ok")
