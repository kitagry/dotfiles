local nvim_lsp = require'lspconfig'
-- local diagnostic = require'diagnostic'
local configs = require'lspconfig/configs'
local util = require 'lspconfig/util'

local M = {}
function M.setupLSP()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.completion.completionItem.snippetSupport = true

  -- gopls settings
  nvim_lsp.gopls.setup{
    capabilities = capabilities,
    init_options = {
      usePlaceholders=true;
      gofumpt=true;
    }
  }

  nvim_lsp.pyls.setup{
    capabilities = capabilities,
    pyls = {
      configurationSources = {'flake8'}
    }
  }
  nvim_lsp.vimls.setup{
    capabilities = capabilities,
  }
  nvim_lsp.rust_analyzer.setup{
    capabilities = capabilities,
  }
  nvim_lsp.tsserver.setup{
    capabilities = capabilities,
  }
  nvim_lsp.efm.setup{
    capabilities = capabilities,
    filetypes = { 'vim' },
  }

  -- configs.golangci_lint = {
  --   default_config = {
  --     cmd = { 'golangci-lint-langserver' };
  --     filetypes = { 'go' };
  --     root_dir = util.root_pattern("go.mod", ".git");
  --     init_options = {
  --       command={ 'golangci-lint', 'run', '--enable-all', '--disable', 'lll', '--out-format', 'json' };
  --     };
  --   };
  -- }
  -- nvim_lsp.golangci_lint.setup{}

  configs.sqls = {
    default_config = {
      cmd = { 'sqls' };
      filetypes = { 'sql' };
      root_dir = util.root_pattern(".git");
      init_options = {
        command = { 'sqls' };
      };
    };
  }
  nvim_lsp.sqls.setup{
    capabilities = capabilities,
  }

  nvim_lsp.clangd.setup{
    capabilities = capabilities,
  }
  nvim_lsp.sumneko_lua.setup{
    capabilities = capabilities,
  }
end

local function buf_request_sync(bufnr, method, params, timeout_ms)
  local request_results = {}
  local result_count = 0
  local function _callback(err, _, result, client_id)
    request_results[client_id] = { error = err, result = result }
    result_count = result_count + 1
  end
  local client_request_ids, cancel = vim.lsp.buf_request(bufnr, method, params, _callback)
  local expected_result_count = 0
  for _ in pairs(client_request_ids) do
    expected_result_count = expected_result_count + 1
  end

  local wait_result = vim.wait(timeout_ms or 100, function()
    return result_count >= expected_result_count
  end, 10)

  if not wait_result then
    cancel()
    return nil
  end
  return request_results
end

local function run(actions)
  if actions == nil or vim.tbl_isempty(actions) then
    return
  end

  if #actions ~= 1 then
    return
  end

  local action_chosen = actions[1]

  -- textDocument/codeAction can return either Command[] or CodeAction[].
  -- If it is a CodeAction, it can have either an edit, a command or both.
  -- Edits should be executed first
  if action_chosen.edit or type(action_chosen.command) == "table" then
    if action_chosen.edit then
      vim.lsp.util.apply_workspace_edit(action_chosen.edit)
    end
    if type(action_chosen.command) == "table" then
      vim.lsp.buf.execute_command(action_chosen.command)
    end
  else
    vim.lsp.buf.execute_command(action_chosen)
  end
end

function M.code_action_sync(action)
  local pre_callback = vim.lsp.callbacks['textDocument/codeAction']
  vim.lsp.callbacks['textDocument/codeAction'] = run
  local context = {}
  context['only'] = {action}
  context['diagnostics'] = {}
  local params = vim.lsp.util.make_range_params()
  params.context = context
  local result = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', params)
  if not result or vim.tbl_isempty(result) then return end
  local _, code_action_result = next(result)
  result = code_action_result.result
  run(result)
  vim.lsp.callbacks['textDocument/codeAction'] = pre_callback
end

function M.formatting_sync(options, timeout_ms)
  local params = vim.lsp.util.make_formatting_params(options)
  local result = buf_request_sync(0, "textDocument/formatting", params, timeout_ms)
  if not result or vim.tbl_isempty(result) then return end
  local _, formatting_result = next(result)
  result = formatting_result.result
  if not result then return end
  vim.lsp.util.apply_text_edits(result)
end
return M
