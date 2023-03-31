local vim = vim
local nvim_lsp = require'lspconfig'
local configs = require'lspconfig.configs'
local util = require 'lspconfig.util'
local kitautil = require('kitagry.util')
local mason = require('mason')
local mason_configs = require('mason-lspconfig')
local neodev = require('neodev')

local M = {}

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
  M.capabilities = capabilities

  mason.setup({
    providers = {
      "mason.providers.client",
      "mason.providers.registry-api",
    },
  })
  mason_configs.setup({
    ensure_installed = { "rust_analyzer", "gopls", "pyright" }
  })
  neodev.setup({})

  local parent = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
  local package_json = vim.fn.findfile('package.json', parent .. ';')

  mason_configs.setup_handlers {
    function(server)
      nvim_lsp[server].setup({
        capabilities = capabilities,
      })
    end,
    ["tsserver"] = function ()
      if package_json == "" then
        return
      end
      nvim_lsp.tsserver.setup({
        capabilities = capabilities,
      })
    end,
    ["denols"] = function ()
      if package_json ~= "" then
        return
      end
      nvim_lsp.denols.setup({
        capabilities = capabilities,
      })
    end,
    ["gopls"] = function ()
      nvim_lsp.gopls.setup({
        capabilities = capabilities,
        init_options = {
          usePlaceholders=true;
          gofumpt=true;
        },
      })
    end,
    ["yamlls"] = function ()
      nvim_lsp.yamlls.setup({
        capabilities = capabilities,
        settings = {
          yaml = {
            schemas = {
              ["kubernetes"] = {"/k8s/**/*.yml", "/k8s/**/*.yaml", "/*.k8s.yaml"},
              ["http://json.schemastore.org/kustomization"] = "kustomization.yaml",
              ["https://raw.githubusercontent.com/argoproj/argo-workflows/master/api/jsonschema/schema.json"] = {"/k8s/**/*.yml", "/k8s/**/*.yaml", "/*.k8s.yaml"},
              ["https://raw.githubusercontent.com/magmax/atlassian-openapi/master/spec/bitbucket.yaml"] = {"bitbucket-pipelines.yml"}
            },
            format = {
              enable = true,
            },
            validate = true,
          }
        },
      })
    end,
    ["pyright"] = function ()
      M.setupPythonLSP()
    end,
    ["lua_ls"] = function ()
      nvim_lsp.lua_ls.setup({
        settings = {
          Lua = {
            completion = {
              callSnippet = "Replace"
            }
          }
        }
      })
    end
  }

  if not configs.regols then
    configs.regols = {
      default_config = {
        cmd = { 'regols' };
        filetypes = { 'rego' };
        root_dir = util.root_pattern(".git");
        init_options = {
          command = { 'regols' };
        };
      };
    }
  end
  nvim_lsp.regols.setup{
    capabilities = capabilities,
  }
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
  nvim_lsp.solargraph.setup{
    capabilities = capabilities,
  }
end

function M.setupPythonLSP()
  local python_path = 'python3'

  local poetry_lock = kitautil.search_files({'poetry.lock'})
  if poetry_lock then
    local virtual_env_path = vim.trim(vim.fn.system('poetry env info -p'))
    if #vim.split(virtual_env_path, '\n') == 1 then
      python_path = string.format("%s/bin/python", virtual_env_path)
    end
  end

  local pipfile_lock = kitautil.search_files({'Pipfile.lock'})
  if pipfile_lock then
    local virtual_env_path = vim.trim(vim.fn.system('pipenv --venv'))
    if #vim.split(virtual_env_path, '\n') == 1 then
      python_path = string.format("%s/bin/python", virtual_env_path)
    end
  end

  nvim_lsp.pyright.setup{
    capabilities = M.capabilities,
    settings = {
      python = {
        pythonPath = python_path;
      }
    }
  }
end

local function code_action_sync_handler(actions)
  if actions == nil or vim.tbl_isempty(actions) then
    return
  end

  ---@private
  local function apply_action(action, client)
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    if action.command then
      local command = type(action.command) == 'table' and action.command or action
      local fn = client.commands[command.command] or vim.lsp.commands[command.command]
      if fn then
        local enriched_ctx = vim.deepcopy(ctx)
        enriched_ctx.client_id = client.id
        fn(command, enriched_ctx)
      else
        M.execute_command(command)
      end
    end
  end

  for _, action in pairs(actions) do
    if action.result == nil or #action.result ~= 1 then
      goto continue
    end

    local client = vim.lsp.get_client_by_id(1)
    local action_chosen = action.result[1]
    if not action_chosen.edit
        and client
        and type(client.resolved_capabilities.code_action) == 'table'
        and client.resolved_capabilities.code_action.resolveProvider then

      client.request('codeAction/resolve', action_chosen, function(err, resolved_action)
        if err then
          vim.notify(err.code .. ': ' .. err.message, vim.log.levels.ERROR)
          return
        end
        apply_action(resolved_action, client)
      end)
    else
      apply_action(action_chosen, client)
    end
    ::continue::
  end
end

function M.code_action_sync(action)
  local context = {}
  context['only'] = {action}
  context['diagnostics'] = {}
  local params = vim.lsp.util.make_range_params()
  params.context = context
  local results = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', params)
  code_action_sync_handler(results)
end

return M
