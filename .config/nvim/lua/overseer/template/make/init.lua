local vim = vim
local overseer = require("overseer")
local files = require("overseer.files")

local tmpl = {
  name = "make",
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
  },
  builder = function(params)
    local cmd = { "make" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

return {
  cache_key = function (opts)
    return files.join(opts.dir, "Makefile")
  end,
  condition = {
    callback = function (opts)
      if not files.exists(files.join(opts.dir, "Makefile")) then
        return false, "No Makefile file found"
      end
      return true
    end
  },
  generator = function(opts, cb)
    local content = files.read_file(files.join(opts.dir, "Makefile"))
    local targets = {}
    for line in vim.gsplit(content, "\n") do
      local phony = line:match("^.PHONY:%s*(.+)$")
      if phony then
        for t in vim.gsplit(phony, "%s*,%s*") do
          if t:match("^[a-zA-Z0-9_%-]+$") then
            targets[t] = true
          end
        end
      end

      local name = line:match("^([a-zA-Z0-9_%-]+):$")
      if name then
        targets[name] = true
      end
    end

    local ret = { tmpl }
    for k in pairs(targets) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("make %s", k) },
          { args = { k } }
        )
      )
    end
    cb(ret)
  end,
}
