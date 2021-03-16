local nvim_lsp = require'lspconfig'
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
  -- nvim_lsp.denols.setup{
  --   capabilities = capabilities,
  -- }
  nvim_lsp.efm.setup{
    capabilities = capabilities,
    filetypes = { 'vim', 'plaintex', 'tex', 'markdown' },
    default_config = {
      cmd = { 'efm-langserver', '-c', 'C:\\Users\\kitad\\AppData\\Roaming\\efm-langserver\\config.yaml', '-logfile', 'C:\\Users\\kitad\\AppData\\Local\\Temp\\nvim\\efm.log' }
    }
  }
  nvim_lsp.texlab.setup{
    capabilities = capabilities,
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

local function code_action_sync_handler(actions)
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
  local pre_callback = vim.lsp.handlers['textDocument/codeAction']
  local context = {}
  context['only'] = {action}
  context['diagnostics'] = {}
  local params = vim.lsp.util.make_range_params()
  params.context = context
  local result = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', params)
  if not result or vim.tbl_isempty(result) then return end
  local _, code_action_result = next(result)
  result = code_action_result.result
  code_action_sync_handler(result)
end

return M
