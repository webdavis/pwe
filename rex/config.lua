local options = ...

local function part(name, ...)
  return assert(loadstring(sources[name], "=pwe/" .. name))(...)
end

local watching = part("watch", sources.record, sources.watcher)
local vim_is_in_front = part("front")
part("navigate", options, watching, vim_is_in_front)
part("last_pane", options, watching, vim_is_in_front)
