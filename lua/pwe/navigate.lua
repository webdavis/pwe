local directions = { h = "left", j = "down", k = "up", l = "right" }

local function move(key)
  local window = vim.api.nvim_get_current_win()
  pcall(vim.cmd.wincmd, key)
  local rex_folder = vim.env.REX_BIN_DIR
  if vim.api.nvim_get_current_win() ~= window or rex_folder == nil then
    return
  end
  vim.system({ rex_folder .. "/rex", "focus", directions[key] })
end

local function setup()
  for key, direction in pairs(directions) do
    vim.keymap.set("n", "<C-" .. key .. ">", function()
      move(key)
    end, { desc = "Move " .. direction .. " to the next split or pane" })
  end
end

return { setup = setup }
