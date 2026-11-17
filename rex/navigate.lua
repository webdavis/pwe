local options, watching, vim_is_in_front = ...
local chosen = options.keys or {}
local usual = { left = "ctrl+h", down = "ctrl+j", up = "ctrl+k", right = "ctrl+l" }

for direction, usual_key in pairs(usual) do
  local key = chosen[direction]
  if key == nil then
    key = usual_key
  end
  if key then
    rex.bind(key, function(context)
      watching(context)
      if vim_is_in_front(context) then
        return false
      end
      rex.session.focus_direction({ session_id = context.session_id, direction = direction, wrap = false })
      return true
    end)
  end
end
