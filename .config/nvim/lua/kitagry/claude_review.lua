local M = {}

local state = {
  comments = {},
  base_ref = nil,
}

local NS = vim.api and vim.api.nvim_create_namespace and vim.api.nvim_create_namespace("claude_review") or 0

-- ---------------------------------------------------------------------------
-- Pure state
-- ---------------------------------------------------------------------------

function M.add_comment(path, lnum, text)
  if not text or text == "" then return end
  state.comments[path] = state.comments[path] or {}
  state.comments[path][lnum] = text
end

function M.get_comment(path, lnum)
  return state.comments[path] and state.comments[path][lnum] or nil
end

function M.delete_comment(path, lnum)
  if state.comments[path] then
    state.comments[path][lnum] = nil
    if next(state.comments[path]) == nil then
      state.comments[path] = nil
    end
  end
end

function M.list_comments()
  local out = {}
  local paths = {}
  for p in pairs(state.comments) do paths[#paths + 1] = p end
  table.sort(paths)
  for _, p in ipairs(paths) do
    local lnums = {}
    for ln in pairs(state.comments[p]) do lnums[#lnums + 1] = ln end
    table.sort(lnums)
    for _, ln in ipairs(lnums) do
      out[#out + 1] = { path = p, lnum = ln, text = state.comments[p][ln] }
    end
  end
  return out
end

function M.clear()
  state.comments = {}
  state.base_ref = nil
end

local function quote(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = "> " .. line
  end
  return table.concat(lines, "\n")
end

function M.format_for_claude(opts)
  opts = opts or {}
  local comments = M.list_comments()
  if #comments == 0 then return nil end
  local diff_excerpt = opts.diff_excerpt or function() return "" end
  local parts = { "以下のレビューに沿って修正してください。", "" }
  for _, c in ipairs(comments) do
    parts[#parts + 1] = string.format("### %s:%d", c.path, c.lnum)
    local excerpt = diff_excerpt(c.path, c.lnum) or ""
    if excerpt ~= "" then
      parts[#parts + 1] = "```"
      parts[#parts + 1] = excerpt
      parts[#parts + 1] = "```"
    end
    parts[#parts + 1] = quote(c.text)
    parts[#parts + 1] = ""
  end
  return table.concat(parts, "\n")
end

-- ---------------------------------------------------------------------------
-- Integration helpers (Neovim runtime side, not unit-tested)
-- ---------------------------------------------------------------------------

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function shell(cmd)
  local h = io.popen(cmd .. " 2>/dev/null")
  if not h then return nil end
  local out = h:read("*a")
  local ok = h:close()
  if not ok then return nil end
  return trim(out)
end

local function git_root()
  return shell("git rev-parse --show-toplevel")
end

local function detect_base_ref()
  if state.base_ref then return state.base_ref end
  local ref = shell("gh pr view --json baseRefName -q .baseRefName")
  if not ref or ref == "" then
    ref = shell("git symbolic-ref --short refs/remotes/origin/HEAD")
    if ref then ref = ref:gsub("^origin/", "") end
  end
  if not ref or ref == "" then ref = "main" end
  state.base_ref = "origin/" .. ref
  return state.base_ref
end

local function diffview_cur_file_path()
  local ok, lib = pcall(require, "diffview.lib")
  if not ok then return nil end
  local view = lib.get_current_view()
  if not view or not view.panel or not view.panel.cur_file then return nil end
  return view.panel.cur_file.path
end

local function buf_path_relative()
  -- diffview 上ならファイルパネル/差分バッファ問わず cur_file から解決
  local from_diffview = diffview_cur_file_path()
  if from_diffview then return from_diffview end

  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then return nil end
  if file:match("^diffview://") then return nil end
  local root = git_root()
  if not root then return nil end
  if file:sub(1, #root + 1) == root .. "/" then
    return file:sub(#root + 2)
  end
  return file
end

local function diff_excerpt_for(path, lnum)
  local base = detect_base_ref()
  local cmd = string.format(
    "git diff %s...HEAD -- %s",
    vim.fn.shellescape(base),
    vim.fn.shellescape(path)
  )
  local out = shell(cmd)
  if not out or out == "" then return "" end

  -- 当該行を含む @@ hunk を抜き出す
  local hunks = {}
  for hunk in (out .. "\n@@"):gmatch("(@@[^@]+@@[^@]*)\n@@") do
    hunks[#hunks + 1] = hunk
  end
  for _, h in ipairs(hunks) do
    local new_start, new_count = h:match("@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
    if new_start then
      new_start = tonumber(new_start)
      new_count = tonumber(new_count) or 1
      if lnum >= new_start and lnum < new_start + new_count then
        return h
      end
    end
  end
  return ""
end

-- ---------------------------------------------------------------------------
-- Visuals: sign + virtual text via extmark
-- ---------------------------------------------------------------------------

local function preview_text(text)
  local first = text:match("[^\n]*") or ""
  if #first > 60 then first = first:sub(1, 60) .. "…" end
  return first
end

local function bufs_for_path(path)
  local root = git_root()
  if not root then return {} end
  local abs = root .. "/" .. path
  local out = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_get_name(b) == abs then
      out[#out + 1] = b
    end
  end
  return out
end

local function render_buf(bufnr, path)
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  local per_file = state.comments[path]
  if not per_file then return end
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for lnum, text in pairs(per_file) do
    if lnum >= 1 and lnum <= line_count then
      vim.api.nvim_buf_set_extmark(bufnr, NS, lnum - 1, 0, {
        sign_text = "R",
        sign_hl_group = "DiagnosticWarn",
        virt_text = { { " 💬 " .. preview_text(text), "Comment" } },
        virt_text_pos = "eol",
      })
    end
  end
end

local function refresh_path(path)
  for _, b in ipairs(bufs_for_path(path)) do
    render_buf(b, path)
  end
end

local function refresh_all()
  for path in pairs(state.comments) do
    refresh_path(path)
  end
end

-- ---------------------------------------------------------------------------
-- Comment input floating window
-- ---------------------------------------------------------------------------

local function open_comment_float(path, lnum, initial, on_save)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  if initial and initial ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(initial, "\n", { plain = true }))
  end
  local width = math.min(80, vim.o.columns - 4)
  local height = 6
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    border = "rounded",
    title = string.format(" %s:%d  (<CR>:save  q/<Esc>:cancel) ", path, lnum),
    title_pos = "left",
  })
  vim.cmd("startinsert")

  local function close() pcall(vim.api.nvim_win_close, win, true) end
  local function save()
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    text = trim(text)
    close()
    on_save(text)
  end

  vim.keymap.set({ "n" }, "<CR>", save, { buffer = buf, nowait = true })
  vim.keymap.set({ "n" }, "q", close, { buffer = buf, nowait = true })
  vim.keymap.set({ "n" }, "<Esc>", close, { buffer = buf, nowait = true })
  vim.keymap.set({ "i" }, "<C-CR>", function()
    vim.cmd("stopinsert")
    save()
  end, { buffer = buf, nowait = true })
end

-- ---------------------------------------------------------------------------
-- Public commands
-- ---------------------------------------------------------------------------

function M.start(opts)
  opts = opts or {}
  local base = opts.base or detect_base_ref()
  state.base_ref = base
  local ok = pcall(vim.cmd, "DiffviewOpen " .. base .. "...HEAD")
  if not ok then
    vim.notify("diffview.nvim が見つかりません", vim.log.levels.ERROR)
    return
  end
  refresh_all()
end

function M.comment_here()
  local ft = vim.bo.filetype
  if ft == "DiffviewFiles" or ft == "DiffviewFileHistory" or ft == "DiffviewFilePanel" then
    vim.notify("差分ウィンドウ側にカーソルを移してから実行してください", vim.log.levels.WARN)
    return
  end
  local path = buf_path_relative()
  if not path then
    vim.notify("ファイルバッファ上で実行してください", vim.log.levels.WARN)
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local existing = M.get_comment(path, lnum) or ""
  open_comment_float(path, lnum, existing, function(text)
    if text == "" then
      M.delete_comment(path, lnum)
    else
      M.add_comment(path, lnum, text)
    end
    refresh_path(path)
  end)
end

function M.delete_here()
  local path = buf_path_relative()
  if not path then return end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  M.delete_comment(path, lnum)
  refresh_path(path)
end

function M.list_in_quickfix()
  local items = {}
  local root = git_root() or ""
  for _, c in ipairs(M.list_comments()) do
    items[#items + 1] = {
      filename = root ~= "" and (root .. "/" .. c.path) or c.path,
      lnum = c.lnum,
      text = c.text:gsub("\n", " / "),
    }
  end
  vim.fn.setqflist({}, " ", { title = "Claude Review", items = items })
  vim.cmd("copen")
end

local function find_aibo_console()
  local ok, console = pcall(require, "aibo.internal.console_window")
  if not ok then return nil end
  return console.find_info_globally({ cmd = "claude" })
end

function M.submit()
  local payload = M.format_for_claude({ diff_excerpt = diff_excerpt_for })
  if not payload then
    vim.notify("レビューコメントがありません", vim.log.levels.WARN)
    return
  end
  local info = find_aibo_console()
  if not info then
    vim.notify("Aibo claude console が見つかりません (<leader>ac で起動)", vim.log.levels.ERROR)
    return
  end
  if info.winid == -1 then
    vim.notify("Aibo claude console は開いていますが非表示です。タブで開いてから再実行してください", vim.log.levels.WARN)
    return
  end

  local prompt = require("aibo.internal.prompt_window")
  prompt.open(info.winid, { startinsert = false })
  local prompt_info = prompt.get_info_by_console_winid(info.winid)
  if not prompt_info then
    vim.notify("Aibo prompt window を開けませんでした", vim.log.levels.ERROR)
    return
  end
  prompt.write(prompt_info.bufnr, vim.split(payload, "\n", { plain = true }), { replace = true })

  -- 状態クリア + 描画リフレッシュ
  local affected_paths = {}
  for path in pairs(state.comments) do affected_paths[#affected_paths + 1] = path end
  M.clear()
  for _, p in ipairs(affected_paths) do refresh_path(p) end

  vim.notify("Aibo prompt にレビューを書き込みました。確認して Ctrl+Enter で送信してください", vim.log.levels.INFO)
end

function M.discard()
  local affected_paths = {}
  for path in pairs(state.comments) do affected_paths[#affected_paths + 1] = path end
  M.clear()
  for _, p in ipairs(affected_paths) do refresh_path(p) end
  vim.notify("Claude Review コメントを破棄しました", vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

function M.setup()
  vim.api.nvim_create_user_command("ClaudeReview", function(o)
    M.start({ base = o.args ~= "" and o.args or nil })
  end, { nargs = "?", desc = "Open diffview against PR base" })

  vim.api.nvim_create_user_command("ClaudeReviewComment", M.comment_here, { desc = "Add review comment on current line" })
  vim.api.nvim_create_user_command("ClaudeReviewDelete", M.delete_here, { desc = "Delete review comment on current line" })
  vim.api.nvim_create_user_command("ClaudeReviewList", M.list_in_quickfix, { desc = "List all review comments" })
  vim.api.nvim_create_user_command("ClaudeReviewSubmit", M.submit, { desc = "Send review comments to Aibo claude" })
  vim.api.nvim_create_user_command("ClaudeReviewDiscard", M.discard, { desc = "Discard review comments without sending" })

  local group = vim.api.nvim_create_augroup("kitagry.claude_review", { clear = true })
  vim.api.nvim_create_autocmd({ "BufRead", "BufEnter" }, {
    group = group,
    callback = function(args)
      local root = git_root()
      if not root then return end
      local file = vim.api.nvim_buf_get_name(args.buf)
      if file == "" or file:match("^diffview://") then return end
      if file:sub(1, #root + 1) == root .. "/" then
        local rel = file:sub(#root + 2)
        if state.comments[rel] then render_buf(args.buf, rel) end
      end
    end,
  })
end

return M
