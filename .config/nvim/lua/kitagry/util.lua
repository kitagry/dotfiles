local vim = vim

local M = {}

local is_windows = vim.loop.os_uname().version:match("Windows")
local path_sep = is_windows and "\\" or "/"

local function path_join(...)
  local result =
    table.concat(
      vim.tbl_flatten {...}, path_sep):gsub(path_sep.."+", path_sep)
  return result
end

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

-- util.search_files({'SEARCH_FILE'})
function M.search_files(...)
  local patterns = vim.tbl_flatten {...}
  local function matcher(path)
    for _, pattern in ipairs(patterns) do
      for _, p in ipairs(vim.fn.glob(path_join(path, pattern), true, true)) do
        local f = io.open(p, "r")
        if f ~= nil then
          f.close()
          return path
        end
      end
    end
  end
  return search_ancestors(vim.fn.expand("%:p:h"), matcher)
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

return M
