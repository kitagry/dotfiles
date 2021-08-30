local nvim_lsp = require'lspconfig'
local configs = require'lspconfig/configs'
local util = require 'lspconfig/util'

local M = {}

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local is_windows = vim.loop.os_uname().version:match("Windows")
local path_sep = is_windows and "\\" or "/"

local is_fs_root
if is_windows then
  is_fs_root = function(path)
    return path:match("^%a:$")
  end
else
  is_fs_root = function(path)
    return path == "/"
  end
end

local dirname
do
  local strip_dir_pat = path_sep.."([^"..path_sep.."]+)$"
  local strip_sep_pat = path_sep.."$"
  dirname = function(path)
    if not path then return end
    local result = path:gsub(strip_sep_pat, ""):gsub(strip_dir_pat, "")
    if #result == 0 then
      return "/"
    end
    return result
  end
end

local function iterate_parents(path)
  path = vim.loop.fs_realpath(path)
  local function it(s, v)
    if not v then return end
    if is_fs_root(v) then return end
    return dirname(v), path
  end
  return it, path, path
end

local function path_join(...)
  local result =
    table.concat(
      vim.tbl_flatten {...}, path_sep):gsub(path_sep.."+", path_sep)
  return result
end

function M.search_ancestors(startpath, func)
  vim.validate { func = {func, 'f'} }
  if func(startpath) then return startpath end
  for path in iterate_parents(startpath) do
    if func(path) then return path end
  end
end

function M.search_files(...)
  local patterns = vim.tbl_flatten {...}
  local function matcher(path)
    for _, pattern in ipairs(patterns) do
      for _, p in ipairs(vim.fn.glob(path_join(path, pattern), true, true)) do
        f = io.open(p, "r")
        if f ~= nil then
          f.close()
          return path
        end
      end
    end
  end
  return M.search_ancestors(vim.fn.expand("%:p:h"), matcher)
end

function M.setupLSP()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.preselectSupport = true
  capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
  capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
  capabilities.textDocument.completion.completionItem.deprecatedSupport = true
  capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
  capabilities.textDocument.completion.completionItem.tagSupport = { valueSet = { 1 } }
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = {
      'documentation',
      'detail',
      'additionalTextEdits',
    }
  }

  -- gopls settings
  nvim_lsp.gopls.setup{
    capabilities = capabilities,
    init_options = {
      usePlaceholders=true;
      gofumpt=true;
    }
  }

  local virtual_env_path = vim.trim(vim.fn.system('poetry env info -p'))

  local python_path = 'python'
  if #vim.split(virtual_env_path, '\n') == 1 then
    python_path = string.format("%s/bin/python", virtual_env_path)
  end
  nvim_lsp.pyright.setup{
    capabilities = capabilities,
    settings = {
      python = {
        pythonPath = python_path;
      }
    }
  }
  nvim_lsp.vimls.setup{
    capabilities = capabilities,
  }
  nvim_lsp.rust_analyzer.setup{
    capabilities = capabilities,
  }

  local package_json = M.search_files({'package.json'})
  if package_json then
    nvim_lsp.tsserver.setup{
      capabilities = capabilities,
    }
  else
    nvim_lsp.denols.setup{
      capabilities = capabilities,
    }
  end

  local efm_config
  local efm_logfile
  if vim.fn.has('win32') == 1 then
    efm_config = 'C:\\Users\\kitad\\AppData\\Roaming\\efm-langserver\\config.yaml'
    efm_logfile = 'C:\\Users\\kitad\\AppData\\Local\\Temp\\nvim\\efm.log'
  else
    efm_config = '~/.config/efm-langserver/config.yaml'
    efm_logfile = '~/.cache/nvim/efm.log'
  end
  nvim_lsp.efm.setup{
    capabilities = capabilities,
    filetypes = { 'vim', 'plaintex', 'tex', 'markdown', 'python', 'sh' },
    root_dir = util.root_pattern(".git", "tox.ini", "pyproject.toml");
    default_config = {
      cmd = { 'efm-langserver', '-c', efm_config, '-logfile', efm_logfile };
    }
  }
  nvim_lsp.texlab.setup{
    capabilities = capabilities,
  }
  nvim_lsp.terraformls.setup{
    capabilities = capabilities,
  }
  nvim_lsp.yamlls.setup{
    capabilities = capabilities,
    settings = {
      yaml = {
        schemas = {
          kubernetes = {"/k8s/*"};
        }
      }
    }
  }

  nvim_lsp.solargraph.setup{
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
