local function setup(options)
  options = options or {}
  local keys = options.keys or {}
  local modes = options.modes or { "n" }
  local last_pane = require("pwe.last_pane")
  require("pwe.navigate").setup(keys, modes, last_pane.left_neovim)
  last_pane.setup(keys.last, modes)
end

return { setup = setup }
