return {
  name = "run go all test",
  builder = function()
    return {
      cmd = { "go" },
      args = { "test", "./..." },
      components = { { "on_output_quickfix", open = true }, "default" },
    }
  end,
  condition = {
    filetype = { "go" },
  },
}
