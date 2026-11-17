local function focused_block(view)
  for _, window in ipairs(view.windows or {}) do
    if window.window_id == view.active_window_id then
      return window.focused_block_id
    end
  end
end

rex.on("session_view_changed", function(context)
  local view = rex.session.view({ session_id = context.session_id })
  local block = view and focused_block(view)
  if not block then
    return
  end
  local now = context.session_id .. " " .. block
  local before = store.read()
  if now ~= before then
    store.write(now, before)
  end
end)

rex.on("keymap_changed", function()
  store.remove()
  rex.stop()
end)
