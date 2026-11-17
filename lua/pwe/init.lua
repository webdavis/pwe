local function setup(options)
  options = options or {}
  local keys = options.keys or {}
  local modes = options.modes or { "n" }
  require("pwe.navigate").setup(keys, modes)
  require("pwe.last_pane").setup(keys.last, modes, options.last_goes_to)
end

return { setup = setup }
