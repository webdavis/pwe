local function not_loaded(reason)
  print("pwe: its Rex config was not loaded: " .. tostring(reason))
end

local function setup(options)
  local result, failure = rex.exec({ pwe, "rex", "get", "config" })
  if not result then
    return not_loaded(failure)
  end
  if not result.ok then
    return not_loaded(result.stderr)
  end

  local config, mistake = loadstring(result.stdout, "=pwe")
  if not config then
    return not_loaded(mistake)
  end
  config(options or {})
end

return { setup = setup }
