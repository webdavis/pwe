local terminal = "com.superlogical.terminal"

local function is_vim(program)
  return program ~= nil and program:match("[^/]*$"):match("^n?vim") ~= nil
end

return function(context)
  local process = rex.block.call(terminal, "process", { block_id = context.block_id })
  local front = process and process.foreground
  return front ~= nil and (is_vim(front.name) or is_vim(front.argv0))
end
