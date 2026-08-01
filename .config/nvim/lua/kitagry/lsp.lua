local vim = vim
local configs = require('lspconfig.configs')
local util = require('lspconfig.util')
local mason = require('mason')
local mason_configs = require('mason-lspconfig')
local neodev = require('neodev')
local api = vim.api

local M = {}

local incoming_call_tree_ns = vim.api.nvim_create_namespace('kitagry_incoming_call_tree')
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

local function find_python_path(search_dir)
  search_dir = search_dir or vim.fs.dirname(vim.api.nvim_buf_get_name(0))

  local venv_path = vim.fs.find('python', {
    path = search_dir .. '/.venv/bin/'
  })
  if #venv_path ~= 0 then
    return { python_path = string.format("%s/.venv/bin/python", search_dir), root_dir = search_dir }
  end

  local poetry_lock = vim.fs.find('poetry.lock', {
    upward = true,
    path = search_dir,
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
    path = search_dir,
  })
  if #uv_lock ~= 0 then
    local uv_dir = vim.fs.dirname(uv_lock[1])
    return { python_path = string.format("%s/.venv/bin/python", uv_dir), root_dir = uv_dir }
  end

  local pipfile_lock = vim.fs.find('Pipfile.lock', {
    upward = true,
    path = search_dir,
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

  return { python_path = 'python3', root_dir = search_dir }
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

  vim.lsp.config('*', {
    capability = capability
  })

  vim.lsp.config.ruff = {
    autostart = has_ruff(),
    settings = {
      format = {
        args = { "--config=" .. pyproject },
      }
    }
  }

  vim.lsp.config.ts_ls = {
    autostart = package_json ~= ""
  }

  vim.lsp.config.denols = {
    autostart = package_json == ""
  }

  vim.lsp.config.gopls = {
    init_options = {
      usePlaceholders=true;
      gofumpt=true;
    },
  }

  vim.lsp.config.yamlls = {
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
  }

  vim.lsp.config.pyright = {
    autostart = true,
    before_init = function(params, config)
      local root_dir = vim.uri_to_fname(params.rootUri) or params.rootPath
      if root_dir then
        local python_config = find_python_path(root_dir)
        config.settings.python.pythonPath = python_config.python_path
      end
    end,
    settings = {
      python = {
        pythonPath = 'python3',
      },
    },
  }

  vim.lsp.config.lua_ls = {
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
          library = library({ "telescope.nvim", "overseer.nvim" }),
          checkThirdParty = "Disable",
        }
      }
    },
  }

  if not vim.lsp.config.regols then
    vim.lsp.config.regols = {
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
  vim.lsp.config('regols', {
    capabilities = capabilities,
  })

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
  -- vim.lsp.config.sqls.setup{
  --   capabilities = capabilities,
  -- }
  vim.lsp.config('solargraph', {
    capabilities = capabilities,
  })
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

local CALL_TREE_MAX_NODES = 300
local CALL_TREE_MAX_LEAVES = 100
local CALL_TREE_TIMEOUT_MS = 15000
local INCOMING_CALL_TREE_DEFAULT_DEPTH = 20
local OUTGOING_CALL_TREE_DEFAULT_DEPTH = 1

---@param item table CallHierarchyItem
---@return string
local function call_hierarchy_key(item)
  return item.uri .. ':' .. item.range.start.line .. ':' .. item.range.start.character
end

---@param client vim.lsp.Client
---@param item table CallHierarchyItem
---@param method string 'callHierarchy/incomingCalls' | 'callHierarchy/outgoingCalls'
---@param item_field string 'from' (incoming) | 'to' (outgoing)
---@param depth integer
---@param path_visited table<string, boolean>
---@param state { count: integer, leaf_count: integer, start_time: integer }
---@param max_depth integer
---@param callback fun(node: table)
local function build_call_tree(client, item, method, item_field, depth, path_visited, state, max_depth, callback)
  local node = { item = item, children = {}, depth = depth }
  local key = call_hierarchy_key(item)

  local elapsed_ms = (vim.uv.hrtime() - state.start_time) / 1e6
  state.count = state.count + 1
  if depth >= max_depth
      or path_visited[key]
      or state.count > CALL_TREE_MAX_NODES
      or state.leaf_count >= CALL_TREE_MAX_LEAVES
      or elapsed_ms > CALL_TREE_TIMEOUT_MS then
    node.truncated = true
    callback(node)
    return
  end

  local next_visited = vim.tbl_extend('force', {}, path_visited)
  next_visited[key] = true

  local ok = client:request(method, { item = item }, function(err, result)
    if err or not result or #result == 0 then
      node.is_leaf = true
      state.leaf_count = state.leaf_count + 1
      callback(node)
      return
    end

    local remaining = #result
    for _, call in ipairs(result) do
      build_call_tree(client, call[item_field], method, item_field, depth + 1, next_visited, state, max_depth, function(child)
        table.insert(node.children, child)
        remaining = remaining - 1
        if remaining == 0 then
          callback(node)
        end
      end)
    end
  end, 0)

  -- client:request()がfalseを返すと(クライアントshutdown中など)ハンドラは呼ばれないので、
  -- ここで呼んでおかないと親のremainingが0にならず全体が固まる。
  if not ok then
    node.truncated = true
    callback(node)
  end
end

---@param node table
---@param lines string[]
---@param jump_targets table<integer, {uri: string, line: integer, character: integer}>
---@param highlights {row: integer, col_start: integer, col_end: integer, hl_group: string}[]
local function render_call_tree(node, lines, jump_targets, highlights)
  local mark = node.is_leaf and '* ' or (node.truncated and '~ ' or '')
  local prefix = string.rep('  ', node.depth) .. mark
  local name = node.item.name
  local location = string.format(' (%s:%d)', vim.fn.fnamemodify(vim.uri_to_fname(node.item.uri), ':.'), node.item.range.start.line + 1)
  local line = prefix .. name .. location
  table.insert(lines, line)

  local row = #lines - 1
  local name_start = #prefix
  local name_end = name_start + #name

  if node.is_leaf then
    table.insert(highlights, { row = row, col_start = 0, col_end = name_start, hl_group = 'DiagnosticOk' })
  elseif node.truncated then
    table.insert(highlights, { row = row, col_start = 0, col_end = name_start, hl_group = 'DiagnosticWarn' })
  end
  table.insert(highlights, { row = row, col_start = name_start, col_end = name_end, hl_group = 'Function' })
  table.insert(highlights, { row = row, col_start = name_end, col_end = #line, hl_group = 'Comment' })

  jump_targets[#lines] = {
    uri = node.item.uri,
    line = node.item.range.start.line,
    character = node.item.range.start.character,
  }
  for _, child in ipairs(node.children) do
    render_call_tree(child, lines, jump_targets, highlights)
  end
end

---@param target {uri: string, line: integer, character: integer}
---@param preview_state table
local function show_call_tree_origin_preview(target, preview_state)
  local win = preview_state.origin_win
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local filename = vim.uri_to_fname(target.uri)
  local bufnr = vim.fn.bufadd(filename)
  vim.fn.bufload(bufnr)

  if vim.bo[bufnr].filetype == '' then
    local ft = vim.filetype.match({ buf = bufnr, filename = filename })
    if ft then
      -- filetypeを代入するとFileTypeイベントが発火し、treesitter highlightが有効になる
      vim.bo[bufnr].filetype = ft
    end
  end

  if vim.api.nvim_win_get_buf(win) ~= bufnr then
    vim.api.nvim_win_set_buf(win, bufnr)
  end
  vim.api.nvim_win_set_cursor(win, { target.line + 1, target.character })
  vim.api.nvim_win_call(win, function()
    vim.cmd('normal! zz')
  end)

  if preview_state.origin_highlight_buf and vim.api.nvim_buf_is_valid(preview_state.origin_highlight_buf) then
    vim.api.nvim_buf_clear_namespace(preview_state.origin_highlight_buf, incoming_call_tree_ns, 0, -1)
  end
  vim.api.nvim_buf_set_extmark(bufnr, incoming_call_tree_ns, target.line, 0, {
    end_row = target.line + 1,
    hl_group = 'Visual',
    hl_eol = true,
  })
  preview_state.origin_highlight_buf = bufnr
end

---@param preview_state table
local function restore_call_tree_origin_window(preview_state)
  if preview_state.origin_highlight_buf and vim.api.nvim_buf_is_valid(preview_state.origin_highlight_buf) then
    vim.api.nvim_buf_clear_namespace(preview_state.origin_highlight_buf, incoming_call_tree_ns, 0, -1)
  end
  preview_state.origin_highlight_buf = nil

  local win = preview_state.origin_win
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  if preview_state.origin_buf and vim.api.nvim_buf_is_valid(preview_state.origin_buf) then
    vim.api.nvim_win_set_buf(win, preview_state.origin_buf)
    if preview_state.origin_cursor then
      pcall(vim.api.nvim_win_set_cursor, win, preview_state.origin_cursor)
    end
  end
end

-- カーソル上の関数について、呼び出し元(incoming)/呼び出し先(outgoing)をleafまで再帰的に辿ってtree表示する。
-- `*` はleaf(それ以上辿る先が無い)、`~` は深さ/件数上限による打ち切りを示す。
---@param method string 'callHierarchy/incomingCalls' | 'callHierarchy/outgoingCalls'
---@param item_field string 'from' (incoming) | 'to' (outgoing)
---@param filetype string
---@param notify_message string
---@param max_depth integer
local function open_call_tree(method, item_field, filetype, notify_message, max_depth)
  local origin_win = vim.api.nvim_get_current_win()
  local origin_buf = vim.api.nvim_get_current_buf()
  local origin_cursor = vim.api.nvim_win_get_cursor(origin_win)
  local bufnr = origin_buf
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/prepareCallHierarchy' })
  if #clients == 0 then
    vim.notify('call hierarchy未対応のLSPです', vim.log.levels.WARN)
    return
  end
  local client = clients[1]

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local ok = client:request('textDocument/prepareCallHierarchy', params, function(err, result)
    if err or not result or #result == 0 then
      vim.notify('call hierarchyの起点が見つかりませんでした', vim.log.levels.WARN)
      return
    end

    vim.notify(notify_message .. string.format(' (最大%d階層)', max_depth), vim.log.levels.INFO)
    local state = { count = 0, leaf_count = 0, start_time = vim.uv.hrtime() }
    build_call_tree(client, result[1], method, item_field, 0, {}, state, max_depth, function(tree)
      local lines = {}
      local jump_targets = {}
      local highlights = {}
      render_call_tree(tree, lines, jump_targets, highlights)

      vim.cmd('botright new')
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(win, buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].buftype = 'nofile'
      vim.bo[buf].bufhidden = 'wipe'
      vim.bo[buf].filetype = filetype
      vim.api.nvim_win_set_height(win, math.min(25, #lines + 1))

      for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_set_extmark(buf, incoming_call_tree_ns, hl.row, hl.col_start, {
          end_col = hl.col_end,
          hl_group = hl.hl_group,
        })
      end

      vim.keymap.set('n', '<CR>', function()
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        local target = jump_targets[lnum]
        if not target then
          return
        end
        vim.cmd('wincmd p')
        vim.cmd('edit ' .. vim.fn.fnameescape(vim.uri_to_fname(target.uri)))
        vim.api.nvim_win_set_cursor(0, { target.line + 1, target.character })
      end, { buffer = buf, silent = true })

      vim.keymap.set('n', 'q', ':bwipeout<CR>', { buffer = buf, silent = true })

      local preview_state = {
        origin_win = origin_win,
        origin_buf = origin_buf,
        origin_cursor = origin_cursor,
      }
      vim.api.nvim_create_autocmd('CursorMoved', {
        buffer = buf,
        callback = function()
          local lnum = vim.api.nvim_win_get_cursor(0)[1]
          local target = jump_targets[lnum]
          if target then
            show_call_tree_origin_preview(target, preview_state)
          end
        end,
      })
      vim.api.nvim_create_autocmd({ 'BufLeave', 'BufWipeout' }, {
        buffer = buf,
        callback = function()
          restore_call_tree_origin_window(preview_state)
        end,
      })
    end)
  end, 0)

  if not ok then
    vim.notify('prepareCallHierarchyの送信に失敗しました', vim.log.levels.WARN)
  end
end

---@param max_depth integer|nil
function M.incoming_call_tree(max_depth)
  open_call_tree('callHierarchy/incomingCalls', 'from', 'incomingcalltree', '呼び出し元を辿っています...', max_depth or INCOMING_CALL_TREE_DEFAULT_DEPTH)
end

---@param max_depth integer|nil
function M.outgoing_call_tree(max_depth)
  open_call_tree('callHierarchy/outgoingCalls', 'to', 'outgoingcalltree', '呼び出し先を辿っています...', max_depth or OUTGOING_CALL_TREE_DEFAULT_DEPTH)
end

return M
