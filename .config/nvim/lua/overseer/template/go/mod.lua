local vim = vim
local overseer = require("overseer")

local tmpl = {
  name = "go mod",
  priority = 10,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    local cmd = { "go", "mod" }

    return {
      cmd = cmd,
      args = params.args,
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

    local commands = {
      { args = { "download" } },
      { args = { "tidy" } },
    }
    for _, command in ipairs(commands) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("go mod %s", table.concat(command.args, " ")) },
          { args = command.args, cwd = gomod_dir }
        )
      )
    end
    cb(ret)
  end
}
