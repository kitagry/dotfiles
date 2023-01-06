local vim = vim

return {
  name = "run go test",
  builder = function()
    local file = vim.fn.expand("%:p")

    local new_file = file
    if string.sub(file, #file-#"_test.go"+1) ~= "_test.go" then
      new_file = string.sub(file, 0, #file-#".go") .. "_test.go"
    end
    return {
      cmd = { "go" },
      args = { "test", new_file },
    }
  end,
  condition = {
    filetype = { "go" },
  },
}
