local expect = dofile("lua-tests/support/expect.lua")

local path = os.tmpname()
local record = assert(loadfile("rex/record.lua"))(path)

local function kept()
  return table.concat(record.read(), ", ")
end

local function on_disk(name)
  local file = io.open(name)
  local text = file and file:read("*a")
  if file then
    file:close()
  end
  return text
end

record.write({ "session:1 block:b", "session:1 block:a" })
expect("what was written is read back in the same order", kept(), "session:1 block:b, session:1 block:a")
expect("the file holds one pane on each line", on_disk(path), "session:1 block:b\nsession:1 block:a\n")
expect("a finished write leaves no second file behind", on_disk(path .. ".new"), nil)

local open = io.open
local read_during_the_write
io.open = function(name, mode)
  local opened = open(name, mode)
  if mode == "w" then
    read_during_the_write = on_disk(path)
  end
  return opened
end
record.write({ "session:2 block:z" })
io.open = open
expect("a later write replaces the earlier one", kept(), "session:2 block:z")
expect(
  "a read that lands in the middle of that write still sees the earlier record whole",
  read_during_the_write,
  "session:1 block:b\nsession:1 block:a\n"
)

local file = assert(io.open(path, "w"))
file:write("\nsession:1 block:a\n\n\nsession:1 block:b\n")
file:close()
expect("empty lines are passed over", kept(), "session:1 block:a, session:1 block:b")

record.remove()
expect("a removed record is gone from disk", on_disk(path), nil)
expect("a removed record reads as no panes", kept(), "")

record.write({ "session:1 block:a" })
expect("a write after a removal starts the record again", kept(), "session:1 block:a")
record.remove()

print("rex record: ok")
