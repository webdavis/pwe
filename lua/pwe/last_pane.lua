local rex = require("pwe.rex")

local split_was_last = false

local function left_neovim()
  split_was_last = false
end

local function split_before()
  local before = vim.fn.win_getid(vim.fn.winnr("#"))
  if split_was_last and before ~= 0 and before ~= vim.api.nvim_get_current_win() then
    return before
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

local function go_back()
  local split = split_before()
  if split then
    return vim.api.nvim_set_current_win(split)
  end
  pane_before()
end

local function setup(key, modes)
  if key == nil then
    key = "<C-\\>"
  end
  if not key then
    return
  end
  vim.keymap.set(modes, key, go_back, { desc = "Go back to the last split or pane" })
  local group = vim.api.nvim_create_augroup("pwe_last_pane", { clear = true })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if vim.api.nvim_win_get_config(0).relative == "" then
        split_was_last = true
      end
    end,
  })
  vim.api.nvim_create_autocmd("FocusLost", { group = group, callback = left_neovim })
end

return { setup = setup, left_neovim = left_neovim }
