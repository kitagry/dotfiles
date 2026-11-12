local M = {}

local state = {
  comments = {},
  base_ref = nil,
  -- 開いている diff の range。空文字なら working tree (未コミット) のみ
  diff_range = "",
}

local NS = vim.api and vim.api.nvim_create_namespace and vim.api.nvim_create_namespace("claude_review") or 0

-- ---------------------------------------------------------------------------
-- Pure state
-- ---------------------------------------------------------------------------

function M.add_comment(path, start_lnum, end_lnum, text)
  if not text or text == "" then return end
  state.comments[path] = state.comments[path] or {}
  state.comments[path][start_lnum] = { end_lnum = end_lnum or start_lnum, text = text }
end

function M.get_comment(path, start_lnum)
  return state.comments[path] and state.comments[path][start_lnum] or nil
end

function M.delete_comment(path, start_lnum)
  if state.comments[path] then
    state.comments[path][start_lnum] = nil
    if next(state.comments[path]) == nil then
      state.comments[path] = nil
    end
  end
end

-- 行 lnum を含むコメントの開始行を返す (無ければ nil)
function M.find_comment_at(path, lnum)
  local per_file = state.comments[path]
  if not per_file then return nil end
  for start_lnum, c in pairs(per_file) do
    if lnum >= start_lnum and lnum <= (c.end_lnum or start_lnum) then
      return start_lnum
    end
  end
  return nil
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
      local c = state.comments[p][ln]
      out[#out + 1] = { path = p, lnum = ln, end_lnum = c.end_lnum, text = c.text }
    end
  end
  return out
end

-- コメントの状態のみ消す。diff_range は開いている diffview 側の状態なので保持
-- (submit 後も同じ diff で続けてコメントできるようにするため)
function M.clear()
  state.comments = {}
  state.base_ref = nil
end

-- diffview / git diff に渡す rev を決める。
-- branch: merge-base 起点の 2-dot。コミット済み + 未コミットの両方がファイル一覧に出る
-- working: 引数なし。未コミットのみ
function M.diff_spec(opts)
  opts = opts or {}
  local rev = opts.rev
  if not rev or rev == "" then
    if opts.mode ~= "working" then
      rev = opts.merge_base
    end
  end
  rev = rev or ""
  return { diffview_args = rev, git_diff_range = rev }
end

local function quote(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = "> " .. line
  end
  return table.concat(lines, "\n")
end

local function format_range(start_lnum, end_lnum)
  if start_lnum == end_lnum then return tostring(start_lnum) end
  return start_lnum .. "-" .. end_lnum
end

function M.format_for_claude(opts)
  opts = opts or {}
  local comments = M.list_comments()
  if #comments == 0 then return nil end
  local diff_excerpt = opts.diff_excerpt or function() return "" end
  local parts = { "以下のレビューに沿って修正してください。", "" }
  for _, c in ipairs(comments) do
    parts[#parts + 1] = string.format("### %s:%s", c.path, format_range(c.lnum, c.end_lnum))
    local excerpt = diff_excerpt(c.path, c.lnum, c.end_lnum) or ""
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

local function detect_merge_base()
  local base = detect_base_ref()
  local sha = shell("git merge-base " .. vim.fn.shellescape(base) .. " HEAD")
  if not sha or sha == "" then return nil end
  return sha
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

local function diff_excerpt_for(path, start_lnum, end_lnum)
  end_lnum = end_lnum or start_lnum
  -- start() で開いたのと同じ range を使う。空なら未コミット差分
  local range = state.diff_range or ""
  local cmd = string.format(
    "git diff %s-- %s",
    range ~= "" and (vim.fn.shellescape(range) .. " ") or "",
    vim.fn.shellescape(path)
  )
  local out = shell(cmd)
  if not out or out == "" then return "" end

  -- 当該範囲と重なる @@ hunk を抜き出す
  local hunks = {}
  for hunk in (out .. "\n@@"):gmatch("(@@[^@]+@@[^@]*)\n@@") do
    hunks[#hunks + 1] = hunk
  end
  for _, h in ipairs(hunks) do
    local new_start, new_count = h:match("@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
    if new_start then
      new_start = tonumber(new_start)
      new_count = tonumber(new_count) or 1
      local hunk_end = new_start + new_count - 1
      if start_lnum <= hunk_end and end_lnum >= new_start then
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
  for start_lnum, c in pairs(per_file) do
    local end_lnum = c.end_lnum or start_lnum
    for ln = start_lnum, end_lnum do
      if ln >= 1 and ln <= line_count then
        local is_last = ln == end_lnum
        vim.api.nvim_buf_set_extmark(bufnr, NS, ln - 1, 0, {
          sign_text = "R",
          sign_hl_group = "DiagnosticWarn",
          virt_text = is_last and { { " 💬 " .. preview_text(c.text), "Comment" } } or nil,
          virt_text_pos = is_last and "eol" or nil,
        })
      end
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

local function open_comment_float(path, start_lnum, end_lnum, initial, on_save)
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
    title = string.format(" %s:%s  (<CR>:save  q/<Esc>:cancel) ", path, format_range(start_lnum, end_lnum)),
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
  local mode = opts.mode or "branch"
  local merge_base = mode == "branch" and detect_merge_base() or nil
  if mode == "branch" and not merge_base and not opts.base then
    vim.notify("merge-base を取得できないため未コミット差分を開きます", vim.log.levels.WARN)
  end
  local spec = M.diff_spec({ mode = mode, merge_base = merge_base, rev = opts.base })
  state.diff_range = spec.git_diff_range

  local ok = pcall(vim.cmd, trim("DiffviewOpen " .. spec.diffview_args))
  if not ok then
    vim.notify("diffview.nvim が見つかりません", vim.log.levels.ERROR)
    return
  end
  refresh_all()
end

function M.comment_here(range_start, range_end)
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
  local start_lnum = range_start or vim.api.nvim_win_get_cursor(0)[1]
  local end_lnum = range_end or start_lnum
  if end_lnum < start_lnum then start_lnum, end_lnum = end_lnum, start_lnum end

  -- 既存コメントが範囲に重なるなら開始行を揃えて編集
  local existing_start
  for ln = start_lnum, end_lnum do
    existing_start = M.find_comment_at(path, ln)
    if existing_start then break end
  end
  local existing = existing_start and M.get_comment(path, existing_start) or nil
  local initial = existing and existing.text or ""
  if existing_start then
    start_lnum = existing_start
    end_lnum = existing.end_lnum
  end

  open_comment_float(path, start_lnum, end_lnum, initial, function(text)
    if text == "" then
      M.delete_comment(path, start_lnum)
    else
      M.add_comment(path, start_lnum, end_lnum, text)
    end
    refresh_path(path)
  end)
end

function M.delete_here()
  local path = buf_path_relative()
  if not path then return end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local start_lnum = M.find_comment_at(path, lnum)
  if not start_lnum then return end
  M.delete_comment(path, start_lnum)
  refresh_path(path)
end

function M.list_in_quickfix()
  local items = {}
  local root = git_root() or ""
  for _, c in ipairs(M.list_comments()) do
    items[#items + 1] = {
      filename = root ~= "" and (root .. "/" .. c.path) or c.path,
      lnum = c.lnum,
      end_lnum = c.end_lnum,
      text = c.text:gsub("\n", " / "),
    }
  end
  vim.fn.setqflist({}, " ", { title = "Claude Review", items = items })
  vim.cmd("copen")
end

function M.submit()
  local payload = M.format_for_claude({ diff_excerpt = diff_excerpt_for })
  if not payload then
    vim.notify("レビューコメントがありません", vim.log.levels.WARN)
    return
  end

  local ok, herdr = pcall(require, "kitagry.herdr_send")
  if not ok then
    vim.notify("kitagry.herdr_send を読み込めませんでした", vim.log.levels.ERROR)
    return
  end
  local sent, err = herdr.send(payload)
  if not sent then
    vim.notify(err or "herdr agent への送信に失敗しました", vim.log.levels.ERROR)
    return
  end

  -- 状態クリア + 描画リフレッシュ
  local affected_paths = {}
  for path in pairs(state.comments) do affected_paths[#affected_paths + 1] = path end
  M.clear()
  for _, p in ipairs(affected_paths) do refresh_path(p) end

  vim.notify("herdr agent へレビューを送信しました", vim.log.levels.INFO)
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
  end, { nargs = "?", desc = "Open diffview from merge-base (committed + uncommitted)" })

  vim.api.nvim_create_user_command("ClaudeReviewWorking", function()
    M.start({ mode = "working" })
  end, { desc = "Open diffview for uncommitted changes only" })

  vim.api.nvim_create_user_command("ClaudeReviewComment", function(o)
    if o.range == 0 then
      M.comment_here()
    else
      M.comment_here(o.line1, o.line2)
    end
  end, { desc = "Add review comment on current line or range", range = true })
  vim.api.nvim_create_user_command("ClaudeReviewDelete", M.delete_here, { desc = "Delete review comment on current line" })
  vim.api.nvim_create_user_command("ClaudeReviewList", M.list_in_quickfix, { desc = "List all review comments" })
  vim.api.nvim_create_user_command("ClaudeReviewSubmit", M.submit, { desc = "Send review comments to herdr agent" })
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
