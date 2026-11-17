local path = ...

local function read()
  local file = io.open(path)
  if not file then
    return nil
  end
  local current, previous = file:read("*l", "*l")
  file:close()
  return current, previous
end

local function write(current, previous)
  local file = io.open(path, "w")
  if file then
    file:write(current, "\n", previous or "", "\n")
    file:close()
  end
end

local function remove()
  os.remove(path)
end

return { read = read, write = write, remove = remove }
