local M = {}
function M.setupLSP()
  -- gopls settings
  require'nvim_lsp'.gopls.setup{
    on_attach=require'diagnostic'.on_attach,
    init_options = {
      usePlaceholders=true;
      gofumpt=true;
    }
  }

  require'nvim_lsp'.pyls.setup{
    on_attach=require'diagnostic'.on_attach,
    pyls = {
      configurationSources = {'flake8'}
    }
  }
  require'nvim_lsp'.vimls.setup{
    on_attach=require'diagnostic'.on_attach,
  }
  require'nvim_lsp'.rust_analyzer.setup{
    on_attach=require'diagnostic'.on_attach,
  }
  require'nvim_lsp'.tsserver.setup{
    on_attach=require'diagnostic'.on_attach,
  }
end

local function run(_, _, actions)
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
  local params = vim.lsp.util.make_range_params()
  params.context = context
  local result = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', params)
  if result ~= nil and result[1] ~= nil then
    run(0, 0, result[1]['result'])
  end
  vim.lsp.callbacks['textDocument/codeAction'] = pre_callback
end
return M
