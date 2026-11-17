local rex = require("pwe.rex")

local split_was_last = false
local split_here
local split_left

local function left_neovim()
  split_was_last = false
end

local function entered_a_window()
  local entered = vim.api.nvim_get_current_win()
  if entered == split_here or vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  split_left, split_here = split_here, entered
  split_was_last = true
end

local function split_before()
  if split_left and split_left ~= vim.api.nvim_get_current_win() and vim.api.nvim_win_is_valid(split_left) then
    return split_left
  end
end

local function pane_before()
  local rex_folder, session, block = vim.env.REX_BIN_DIR, vim.env.REX_SESSION, vim.env.REX_BLOCK
  if not (rex_folder and session and block) then
    return
  end
  local request = {
    session_id = session,
    block_id = block,
    key = {
      key = "f20",
      mods = "shift+ctrl+alt+super",
      consumed_mods = "",
      text = "",
      unshifted_codepoint = 0,
      composing = false,
      action = "press",
    },
  }
  rex.call("client.key", request, function()
    vim.system({ rex_folder .. "/rex", "api", "call", "client.key", vim.json.encode(request) })
  end)
end

local function go_back(goes_to)
  local split = split_before()
  if split and (goes_to == "split" or (goes_to ~= "pane" and split_was_last)) then
    return vim.api.nvim_set_current_win(split)
  end
  pane_before()
end

local function setup(key, modes, goes_to)
  if key == nil then
    key = "<C-\\>"
  end
  if not key then
    return
  end
  split_here = vim.api.nvim_get_current_win()
  vim.keymap.set(modes, key, function()
    go_back(goes_to)
  end, { desc = "Go back to the last split or pane" })
  local group = vim.api.nvim_create_augroup("pwe_last_pane", { clear = true })
  vim.api.nvim_create_autocmd("WinEnter", { group = group, callback = entered_a_window })
  vim.api.nvim_create_autocmd("FocusLost", { group = group, callback = left_neovim })
end

return { setup = setup }
