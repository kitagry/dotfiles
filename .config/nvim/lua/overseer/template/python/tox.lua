local vim = vim
local files = require("overseer.files")
local overseer = require("overseer")
local util = require("kitagry.util")

---@type overseer.TemplateDefinition
local tmpl = {
  name = "tox",
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
  },
  builder = function(params)
    local cmd = { "tox" }
    if util.search_files({'poetry.lock'}) then
      cmd = vim.list_extend({'poetry', 'run'}, cmd)
    end
    if util.search_files({'uv.lock'}) then
      cmd = vim.list_extend({'uv', 'run'}, cmd)
    end
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

local function get_tox_dir(opts)
  local tox
  if opts.filetype == "python" then
    local parent = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
    tox = vim.fn.findfile("tox.ini", parent .. ";")
  end
  if not tox then
    tox = vim.fn.findfile("tox.ini", opts.dir .. ";")
  end
  if tox == "" then
    return nil
  end
  return vim.fn.fnamemodify(tox, ":p:h")
end

return {
  cache_key = function(opts)
    return get_tox_dir(opts)
  end,
  condition = {
    callback = function(opts)
      if not get_tox_dir(opts) then
        return false, "No tox.ini file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local ret = { tmpl }

    local content = files.read_file(files.join(get_tox_dir(opts), "tox.ini"))
    if not content then
      cb(ret)
      return
    end
    local targets = {}
    for line in vim.gsplit(content, "\n") do
      local envlist = line:match("^envlist%s*=%s*(.+)$")
      if envlist then
        for t in vim.gsplit(envlist, "%s*,%s*") do
          if t:match("^[a-zA-Z0-9_%-]+$") then
            targets[t] = true
          end
        end
      end

      local name = line:match("^%[testenv:([a-zA-Z0-9_%-]+)%]")
      if name then
        targets[name] = true
      end
    end

    for k in pairs(targets) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("tox -e %s", k) },
          { args = { "-e", k } }
        )
      )
    end
    cb(ret)
  end,
}
