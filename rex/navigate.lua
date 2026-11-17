local terminal = "com.superlogical.terminal"

local function is_vim(program)
  return program ~= nil and program:match("[^/]*$"):match("^n?vim") ~= nil
end

local function vim_is_in_front(context)
  local process = rex.block.call(terminal, "process", { block_id = context.block_id })
  local front = process and process.foreground
  return front ~= nil and (is_vim(front.name) or is_vim(front.argv0))
end

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+" .. key, function(context)
    if vim_is_in_front(context) then
      return false
    end
    rex.session.focus_direction({ session_id = context.session_id, direction = direction, wrap = false })
    return true
  end)
end
