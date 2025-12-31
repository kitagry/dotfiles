return {
  name = "golangci-lint run ./...",
  builder = function()
    return {
      cmd = { "golangci-lint" },
      args = { "run", "./..." },
      components = { { "on_output_quickfix", open = true }, "default" },
    }
  end,
  condition = {
    filetype = { "go" },
  },
}
