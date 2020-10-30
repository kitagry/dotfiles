local M = {}

local texlab_build_status = vim.tbl_add_reverse_lookup {
  Success = 0;
  Error = 1;
  Failure = 2;
  Cancelled = 3;
}

local function build_callback(_, _, result)
  print(texlab_build_status[result.status])
end

function M.build()
  vim.lsp.callbacks['textDocument/build'] = build_callback
  local params = vim.lsp.util.make_formatting_params({})
  vim.lsp.buf_request(0, 'textDocument/build', params)
end

return M
