local vim = vim

local M = {}

local is_windows = vim.loop.os_uname().version:match("Windows")
local path_sep = is_windows and "\\" or "/"

local is_fs_root
if is_windows then
  is_fs_root = function(path)
    return path:match("^%a:$")
  end
else
  is_fs_root = function(path)
    return path == "/"
  end
end

local dirname
do
  local strip_dir_pat = path_sep.."([^"..path_sep.."]+)$"
  local strip_sep_pat = path_sep.."$"
  dirname = function(path)
    if not path then return end
    local result = path:gsub(strip_sep_pat, ""):gsub(strip_dir_pat, "")
    if #result == 0 then
      return "/"
    end
    return result
  end
end

local function iterate_parents(path)
  path = vim.loop.fs_realpath(path)
  local function it(s, v)
    if not v then return end
    if is_fs_root(v) then return end
    return dirname(v), path
  end
  return it, path, path
end

local function search_ancestors(startpath, func)
  vim.validate { func = {func, 'f'} }
  if func(startpath) then return startpath end
  for path in iterate_parents(startpath) do
    if func(path) then return path end
  end
end

---@param filepath string
---@return boolean
function M.exists(filepath)
  local stat = vim.loop.fs_stat(filepath)
  return stat ~= nil and stat.type ~= nil
end

---@param filepath string
---@return string?
function M.read_file(filepath)
  if not M.exists(filepath) then
    return nil
  end
  local fd = vim.loop.fs_open(filepath, "r", 420) -- 0644
  local stat = vim.loop.fs_fstat(fd)
  local content = vim.loop.fs_read(fd, stat.size)
  vim.loop.fs_close(fd)
  return content
end

function M.yank_file_path()
  local file_path = vim.fn.expand('%:p')
  if file_path == '' then
    vim.notify('No file in buffer', vim.log.levels.WARN)
    return
  end

  local mode = vim.fn.mode()
  local yanked_text = file_path

  if mode == 'v' or mode == 'V' or mode == '\22' then  -- visual modes
    local start_line = vim.fn.line('v')
    local end_line = vim.fn.line('.')

    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end

    if start_line == end_line then
      yanked_text = file_path .. '#' .. start_line
    else
      yanked_text = file_path .. '#' .. start_line .. '-' .. end_line
    end

    -- Exit visual mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
  end

  vim.fn.setreg('+', yanked_text)
  vim.fn.setreg('"', yanked_text)
end

return M
