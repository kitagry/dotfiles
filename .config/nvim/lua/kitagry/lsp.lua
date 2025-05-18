local vim = vim
local nvim_lsp = require('lspconfig')
local configs = require('lspconfig.configs')
local util = require('lspconfig.util')
local mason = require('mason')
local mason_configs = require('mason-lspconfig')
local neodev = require('neodev')
local api = vim.api

local M = {}
--
---@param names string[]
---@return string[]
local function get_plugin_paths(names)
  local plugins = require("lazy.core.config").plugins
  local paths = {}
  for _, name in ipairs(names) do
    if plugins[name] then
      table.insert(paths, plugins[name].dir .. "/lua")
    else
      vim.notify("Invalid plugin name: " .. name)
    end
  end
  return paths
end

---@param plugins string[]
---@return string[]
local function library(plugins)
  local paths = get_plugin_paths(plugins)
  table.insert(paths, vim.fn.stdpath("config") .. "/lua")
  table.insert(paths, vim.env.VIMRUNTIME .. "/lua")
  table.insert(paths, "${3rd}/luv/library")
  table.insert(paths, "${3rd}/busted/library")
  table.insert(paths, "${3rd}/luassert/library")
  return paths
end

---@return boolean
local function has_ruff()
  local pyprojects = vim.fs.find('pyproject.toml', {
    upward = true,
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  })

  if #pyprojects == 0 then
    return false
  end

  local content = require('kitagry.util').read_file(pyprojects[1])
  if content == nil then
    return false
  end

  for line in vim.gsplit(content, "\n") do
      if string.find(line, "ruff", 1, true) ~= nil then
        return true
      end
  end
  return false
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
  M.capabilities = capabilities

  vim.lsp.handlers['window/showMessage'] = function(_, result, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local lvl = ({
      'ERROR',
      'WARN',
      'INFO',
      'DEBUG',
    })[result.type]
    vim.notify(result.message, lvl, {
      title = 'LSP | ' .. client.name,
      timeout = 10000,
    })
  end

  vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
    vim.lsp.handlers.hover,
    {
      border = 'single',
    }
  )

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

  local pyprojects = vim.fs.find('pyproject.toml', {
    upward = true,
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  })

  local pyproject = ""
  if #pyprojects > 0 then
    pyproject = pyprojects[1]
  end

  mason_configs.setup_handlers {
    function(server)
      if server == "ruff" then
        nvim_lsp[server].setup({
          capabilities = capabilities,
          autostart = has_ruff(),
          settings = {
            format = {
              args = { "--config=" .. pyproject },
            }
          },
        })
        return
      end
      nvim_lsp[server].setup({
        capabilities = capabilities,
      })
    end,
    ["ts_ls"] = function ()
      if package_json == "" then
        return
      end
      nvim_lsp.ts_ls.setup({
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
              kubernetes = {"/k8s/**/*.yml", "/k8s/**/*.yaml", "/*.k8s.yaml"},
              ["http://json.schemastore.org/kustomization"] = "kustomization.yaml",
              ["https://raw.githubusercontent.com/argoproj/argo-workflows/master/api/jsonschema/schema.json"] = {"/k8s/**/*.yml", "/k8s/**/*.yaml", "/*.k8s.yaml"},
              ["https://raw.githubusercontent.com/magmax/atlassian-openapi/master/spec/bitbucket.yaml"] = {"bitbucket-pipelines.yml"},
              ["https://raw.githubusercontent.com/GoogleContainerTools/skaffold/main/docs-v2/content/en/schemas/v4beta11.json"] = {"skaffold.yaml"}
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
            },
            runtime = {
              version = "LuaJIT",
              pathStrict = true,
              path = { "?.lua", "?/init.lua", "?/?.lua" },
            },
            workspace = {
              library = library({ "neo-tree.nvim", "telescope.nvim", "overseer.nvim" }),
              checkThirdParty = "Disable",
            }
          }
        }
      })
    end,
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

  vim.cmd[[
    command! BQUpdateCache lua vim.lsp.buf_request(0, "bq/updateCache", nil, function() end)
    command! BQClearCache lua vim.lsp.buf_request(0, "bq/clearCache", nil, function() end)
    command! BQDryRun lua vim.lsp.buf_request(0, "bq/dryRun", {uri = "file://" .. vim.fn.expand("%:p")}, function() end)
  ]]

  -- configs.sqls = {
  --   default_config = {
  --     cmd = { 'sqls' };
  --     filetypes = { 'sql' };
  --     root_dir = util.root_pattern(".git");
  --     init_options = {
  --       command = { 'sqls' };
  --     };
  --   };
  -- }
  -- nvim_lsp.sqls.setup{
  --   capabilities = capabilities,
  -- }
  nvim_lsp.solargraph.setup{
    capabilities = capabilities,
  }
end

local function find_python_path()
  local venv_path = vim.fs.find('python', {
    path = './.venv/bin/'
  })
  if #venv_path ~= 0 then
    return { python_path = string.format("%s/.venv/bin/python", vim.fn.getcwd()), root_dir = vim.fn.getcwd() }
  end

  local poetry_lock = vim.fs.find('poetry.lock', {
    upward = true,
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  })
  if #poetry_lock ~= 0 then
    local poetry_dir = vim.fs.dirname(poetry_lock[1])
    local virtual_env_path = vim.trim(vim.fn.system('cd ' .. poetry_dir .. ' && poetry env info -p'))
    local output = vim.split(virtual_env_path, '\n')
    for _, line in ipairs(output) do
      if vim.fn.isdirectory(line) == 1 then
        return { python_path = string.format("%s/bin/python", line), root_dir = poetry_dir }
      end
    end
  end

  local uv_lock = vim.fs.find('uv.lock', {
    upward = true,
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  })
  if #uv_lock ~= 0 then
    local uv_dir = vim.fs.dirname(uv_lock[1])
    return { python_path = string.format("%s/.venv/bin/python", uv_dir), root_dir = uv_dir }
  end

  local pipfile_lock = vim.fs.find('Pipfile.lock', {
    upward = true,
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
  })
  if #pipfile_lock ~= 0 then
    local pipfile_dir = vim.fs.dirname(pipfile_lock[1])
    local virtual_env_path = vim.trim(vim.fn.system('cd ' .. pipfile_dir .. ' && pipenv --venv'))
    local output = vim.split(virtual_env_path, '\n')
    for _, line in ipairs(output) do
      if vim.fn.isdirectory(line) == 1 then
        return { python_path = string.format("%s/bin/python", line), root_dir = pipfile_dir }
      end
    end
  end

  local rye_lock = vim.fs.find('requirements-dev.lock', {
    upward = true,
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  })
  if #rye_lock ~= 0 then
    local rye_lock_dir = vim.fn.dirname(rye_lock[1])
    return { python_path = string.format("%s/.venv/bin/python", rye_lock_dir), root_dir = rye_lock_dir }
  end

  return { python_path = 'python3', root_dir = vim.fn.getcwd() }
end

function M.setupPythonLSP()
  local config = find_python_path()

  nvim_lsp.pyright.setup{
    capabilities = M.capabilities,
    settings = {
      python = {
        pythonPath = config.python_path,
      };
      root_dir = config.root_dir,
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
