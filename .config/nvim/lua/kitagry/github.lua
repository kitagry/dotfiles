local M = {}

function M.get_git_origin_url()
  local handle = io.popen("git config --get remote.origin.url 2>/dev/null")
  if not handle then
    return nil
  end
  local url = handle:read("*a")
  handle:close()
  
  if url == "" then
    return nil
  end
  
  url = vim.trim(url)
  
  -- SSH URLをHTTPS URLに変換
  if url:match("^git@github.com:") then
    url = url:gsub("^git@github.com:", "https://github.com/")
    url = url:gsub("%.git$", "")
  elseif url:match("^https://github.com/") then
    url = url:gsub("%.git$", "")
  else
    return nil
  end
  
  return url
end

function M.get_current_branch()
  local handle = io.popen("git branch --show-current 2>/dev/null")
  if not handle then
    return "main"
  end
  local branch = handle:read("*a")
  handle:close()
  
  if branch == "" then
    return "main"
  end
  
  return vim.trim(branch)
end

function M.get_git_root()
  local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
  if not handle then
    return nil
  end
  local root = handle:read("*a")
  handle:close()
  
  if root == "" then
    return nil
  end
  
  return vim.trim(root)
end

function M.open_in_github()
  local git_url = M.get_git_origin_url()
  if not git_url then
    vim.notify("Git origin URLが見つかりません", vim.log.levels.ERROR)
    return
  end
  
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then
    vim.notify("保存されていないバッファです", vim.log.levels.ERROR)
    return
  end
  
  local git_root = M.get_git_root()
  if not git_root then
    vim.notify("Gitリポジトリ内ではありません", vim.log.levels.ERROR)
    return
  end
  
  local relative_path = current_file:sub(#git_root + 2)
  local branch = M.get_current_branch()
  
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  
  local github_url = string.format("%s/blob/%s/%s#L%d", git_url, branch, relative_path, cursor_line)
  
  local cmd = string.format('open "%s"', github_url)
  vim.fn.system(cmd)
  
  vim.notify("GitHubで開きました: " .. github_url)
end

return M