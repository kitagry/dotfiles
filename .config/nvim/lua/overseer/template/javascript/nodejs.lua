local vim = vim
local files = require("overseer.files")
local overseer = require("overseer")

local tmpl = {
  name = "yarn run",
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
  },
  builder = function(params)
    local cmd = { "yarn", "run" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

return {
  cache_key = function(opts)
    return files.join(opts.dir, "package.json")
  end,
  condition = {
    callback = function(opts)
      if not files.exists(files.join(opts.dir, "package.json")) then
        return false, "No package.json file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local content = files.read_file(files.join(opts.dir, "package.json"))
    local targets = {}
    for t in pairs(vim.json.decode(content)['scripts']) do
      targets[t] = true
    end

    local ret = {}
    for k in pairs(targets) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("yarn run %s", k) },
          { args = { k } }
        )
      )
    end
    cb(ret)
  end,
}
