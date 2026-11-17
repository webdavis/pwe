local function focused_block(view)
  for _, window in ipairs(view.windows or {}) do
    if window.window_id == view.active_window_id then
      return window.focused_block_id
    end
  end
end

local most_kept = 20

rex.on("session_view_changed", function(context)
  local view = rex.session.view({ session_id = context.session_id })
  local block = view and focused_block(view)
  if not block then
    return
  end
  local now = context.session_id .. " " .. block
  local panes = store.read()
  if panes[1] == now then
    return
  end
  local kept = { now }
  for _, pane in ipairs(panes) do
    if pane ~= now and #kept < most_kept then
      kept[#kept + 1] = pane
    end
  end
  store.write(kept)
end)

rex.on("keymap_changed", function()
  store.remove()
  rex.stop()
end)
