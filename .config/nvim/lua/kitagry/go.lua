local vim = vim
local M = {}

function M.toggle_test_file()
  local uri = vim.uri_from_bufnr(0)
  if string.sub(uri, #uri-#".go"+1) ~= ".go" then
    return
  end

  local new_uri = uri
  if string.sub(uri, #uri-#"_test.go"+1) == "_test.go" then
    new_uri = string.sub(uri, 0, #uri-#"_test.go") .. ".go"
  else
    new_uri = string.sub(uri, 0, #uri-#".go") .. "_test.go"
  end

  local bufnr = vim.uri_to_bufnr(new_uri)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_option(0, 'buflisted', true)
end

return M
