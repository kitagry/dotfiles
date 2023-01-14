local vim = vim

local M = {}

function M.setup(opts)
  -- add lazy plugin to runtimepath
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable", -- latest stable release
      lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
  local lazy = require("lazy")

  local local_commands = vim.tbl_filter(function (data)
    return data['setting']
  end, opts)

  for _, command in pairs(local_commands) do
    command.config()
  end

  local lazy_plugins = vim.tbl_filter(function (data)
    return data['setting'] == nil
  end, opts)

  lazy.setup(lazy_plugins)
end

return M
