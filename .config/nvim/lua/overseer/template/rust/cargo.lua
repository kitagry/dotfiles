local vim = vim
local overseer = require("overseer")

local tmpl = {
  name = "cargo",
  priority = 50,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    local cmd = { "cargo" }
    local args = params.args

    return {
      cmd = cmd,
      args = args,
      cwd = params.cwd,
    }
  end,
}

local function get_cargo_toml_dir(opts)
  local cargo_file
  if opts.filetype ~= "rust" then
    return nil
  end

  local parent = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
  cargo_file = vim.fn.findfile("Cargo.toml", parent .. ";")
  if not cargo_file then
    cargo_file = vim.fn.findfile("Cargo.toml", opts.dir .. ";")
  end
  if cargo_file == "" then
    return nil
  end
  return vim.fn.fnamemodify(cargo_file, ":p:h")
end

return {
  cache_key = function(opts)
    return get_cargo_toml_dir(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("cargo") == 0 then
        return false, 'Command "cargo" not found'
      end
      if not get_cargo_toml_dir(opts) then
        return false, "No Cargo.toml file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local cargo_toml_dir = get_cargo_toml_dir(opts)
    local ret = {}

    if cargo_toml_dir == nil then
      return
    end

    local commands = {
      {"run"},
      {"check"},
      {"test"},
      {"clippy", "--", "-D", "warnings"}
    }

    for _, command in ipairs(commands) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("cargo %s", table.concat(command, " ")) },
          { args = command, cwd = cargo_toml_dir }
        )
      )
    end
    cb(ret)
  end
}
