local vim = vim
local files = require("overseer.files")
local overseer = require("overseer")

local tmpl = {
  name = "go run",
  priority = 50,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    local cmd = { "go", "run" }
    local args = params.args and params.args or { "./..." }

    return {
      cmd = cmd,
      args = args,
      cwd = params.cwd,
    }
  end,
}

local function get_gomod_dir(opts)
  local go_mod
  if opts.filetype == "go" then
    local parent = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
    go_mod = vim.fn.findfile("go.mod", parent .. ";")
  end
  if not go_mod then
    go_mod = vim.fn.findfile("go.mod", opts.dir .. ";")
  end
  if go_mod == "" then
    return nil
  end
  return vim.fn.fnamemodify(go_mod, ":p:h")
end

return {
  cache_key = function(opts)
    return get_gomod_dir(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("go") == 0 then
        return false, 'Command "go" not found'
      end
      if not get_gomod_dir(opts) then
        return false, "No go.mod file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local gomod_dir = get_gomod_dir(opts)
    local ret = {}

    if gomod_dir == nil then
      return
    end

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local is_main = false
    for _, line in ipairs(lines) do
      if line:match("^package main") then
        is_main = true
      end
    end

    if not is_main then
      return
    end

    local source_file = vim.api.nvim_buf_get_name(0)
    local source_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
    local relative_source_file = source_file:gsub(gomod_dir, ".")
    local relative_source_path = source_path:gsub(gomod_dir, ".")
    local commands = {
      { args = { relative_source_path } },
      { args = { relative_source_file } },
    }
    for _, command in ipairs(commands) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("go run %s", table.concat(command.args, " ")) },
          { args = command.args, cwd = gomod_dir }
        )
      )
    end
    cb(ret)
  end
}
