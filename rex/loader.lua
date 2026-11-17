local function not_loaded(reason)
  rex.log("pwe: its Rex keys were not loaded: " .. tostring(reason))
end

local result, failure = rex.exec({ pwe, "rex", "get", "config" })
if not result then
  return not_loaded(failure)
end
if not result.ok then
  return not_loaded(result.stderr)
end

local keys, mistake = loadstring(result.stdout, "=pwe")
if not keys then
  return not_loaded(mistake)
end
keys()
