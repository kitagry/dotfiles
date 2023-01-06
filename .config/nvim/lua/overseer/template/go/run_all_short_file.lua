return {
  name = "run go all test short",
  builder = function()
    return {
      cmd = { "go" },
      args = { "test", "-short", "./..." },
      components = { { "on_output_quickfix", open = true }, "default" },
    }
  end,
  condition = {
    filetype = { "go" },
  },
}
