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
}

local say = print
print = function(message)
  logged = message
end

local function setup_with(result, exec_failure, options)
  asked = nil
  answer = result
  failure = exec_failure
  logged = nil
  given = nil
  loader().setup(options)
  return given, logged
end

local expect = dofile("lua-tests/support/expect.lua")

loader()
expect("loading the file alone asks pwe nothing", asked, nil)

local got, log = setup_with({ ok = true, stdout = "given = ..." }, nil, { keys = { left = "alt+h" } })
expect("setup asks the saved pwe for its config", asked, "/somewhere/pwe rex get config")
expect("the config is run with the options given to setup", got and got.keys.left, "alt+h")
expect("a good setup logs nothing", log, nil)

got = setup_with({ ok = true, stdout = "given = ..." })
expect("setup without options runs the config with none set", type(got), "table")
expect("setup without options sets no keys", got.keys, nil)

got, log = setup_with(nil, "no such file")
expect("a missing pwe runs no config", got, nil)
expect("a missing pwe is logged with the reason", log, "pwe: its Rex config was not loaded: no such file")

got, log = setup_with({ ok = false, stdout = "given = ...", stderr = "usage: pwe" })
expect("a failing pwe runs no config", got, nil)
expect("a failing pwe is logged with what it said", log, "pwe: its Rex config was not loaded: usage: pwe")

got, log = setup_with({ ok = true, stdout = "given = = ..." })
expect("Lua that does not parse runs no config", got, nil)
expect("Lua that does not parse is logged by line", log and log:match("^pwe: its Rex config was not loaded: pwe:1: ") ~= nil, true)

say("rex loader: ok")
