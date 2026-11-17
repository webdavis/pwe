local rex = require("pwe.rex")

local usual = {
  left = { key = "<C-h>", window = "h" },
  down = { key = "<C-j>", window = "j" },
  up = { key = "<C-k>", window = "k" },
  right = { key = "<C-l>", window = "l" },
}

local function move(direction, leaving_neovim)
  local window = vim.api.nvim_get_current_win()
  pcall(vim.cmd.wincmd, usual[direction].window)
  local rex_folder = vim.env.REX_BIN_DIR
  if vim.api.nvim_get_current_win() ~= window or rex_folder == nil then
    return
  end
  leaving_neovim()
  rex.call("session.focus_direction", { session_id = vim.env.REX_SESSION, direction = direction, wrap = false }, function()
    vim.system({ rex_folder .. "/rex", "focus", direction })
  end)
end

local function setup(chosen, modes, leaving_neovim)
  for direction, usual_move in pairs(usual) do
    local key = chosen[direction]
    if key == nil then
      key = usual_move.key
    end
    if key then
      vim.keymap.set(modes, key, function()
        move(direction, leaving_neovim)
      end, { desc = "Move " .. direction .. " to the next split or pane" })
    end
  end
end

return { setup = setup }
