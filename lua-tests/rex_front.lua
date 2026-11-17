local foreground

rex = {
  block = {
    call = function(creator, method, arguments)
      assert(creator == "com.superlogical.terminal", "asked " .. tostring(creator))
      assert(method == "process", "called " .. tostring(method))
      assert(arguments.block_id == "block:pressed", "asked about " .. tostring(arguments.block_id))
      return { foreground = foreground }
    end,
  },
}

local vim_is_in_front = dofile("rex/front.lua")

local function in_front(program)
  foreground = program
  return vim_is_in_front({ block_id = "block:pressed" })
end

local expect = dofile("lua-tests/support/expect.lua")

expect("Neovim is in front", in_front({ name = "nvim", argv0 = "nvim" }), true)
expect("Vim by name is in front", in_front({ name = "vim", argv0 = "/usr/bin/vim" }), true)
expect("Neovim started under another name is in front", in_front({ name = "editor", argv0 = "/opt/homebrew/bin/nvim" }), true)
expect("a shell is not", in_front({ name = "zsh", argv0 = "-zsh" }), false)
expect("a pane reporting no program is not", in_front(nil), false)
expect("a program whose name only contains vim is not", in_front({ name = "notvim", argv0 = "/usr/local/bin/notvim" }), false)

print("rex front: ok")
