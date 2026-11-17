local path = ...

local function read()
  local panes = {}
  local file = io.open(path)
  if file then
    for pane in file:lines() do
      if pane ~= "" then
        panes[#panes + 1] = pane
      end
    end
    file:close()
  end
  return panes
end

local function write(panes)
  local file = io.open(path, "w")
  if file then
    file:write(table.concat(panes, "\n"), "\n")
    file:close()
  end
end

local function remove()
  os.remove(path)
end

return { read = read, write = write, remove = remove }
