-- Send the current line/selection to the herdr agent pane running in the
-- same workspace, formatted like reviewr's Send: `path:start-end — note`.
-- Prototype: https://github.com/ogulcancelik/herdr (herdr agent send).

local M = {}

-- ---------------------------------------------------------------------------
-- Pure logic
-- ---------------------------------------------------------------------------

function M.format_range(start_line, end_line)
  if start_line == end_line then return tostring(start_line) end
  return start_line .. "-" .. end_line
end

function M.format_message(path, range, note)
  return string.format("%s:%s — %s", path, range, note)
end

-- Resolve the sole agent pane in the given workspace, mirroring reviewr's
-- "focused tab's agent, or the sole agent in the workspace" rule.
function M.select_target(agents, workspace_id, own_pane_id)
  local candidates = {}
  for _, a in ipairs(agents) do
    if a.workspace_id == workspace_id and a.pane_id ~= own_pane_id then
      candidates[#candidates + 1] = a
    end
  end

  if #candidates == 0 then
    return nil, "同じ workspace に agent pane が見つかりません"
  elseif #candidates > 1 then
    local labels = vim.tbl_map(function(a) return a.pane_id .. " (" .. (a.agent or "?") .. ")" end, candidates)
    return nil, "agent pane が複数あります: " .. table.concat(labels, ", ")
  end
  return candidates[1].pane_id
end

-- ---------------------------------------------------------------------------
-- Integration helpers (Neovim runtime side, not unit-tested)
-- ---------------------------------------------------------------------------

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function herdr_bin()
  local override = vim.env.HERDR_BIN_PATH
  if override and override ~= "" then return override end
  return "herdr"
end

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

local function buf_path_relative()
  -- Resolve gin's virtual buffers (ginedit://, gindiff://, ...) back to their real path.
  local ok, file = pcall(vim.fn["gin#util#expand"], "%")
  if not ok or not file or file == "" then
    file = vim.api.nvim_buf_get_name(0)
  end
  if file == "" then return nil end
  local root = git_root()
  if not root then return file end
  if file:sub(1, #root + 1) == root .. "/" then
    return file:sub(#root + 2)
  end
  return file
end

local function resolve_target_pane()
  local pane_id = vim.env.HERDR_PANE_ID
  if not pane_id or pane_id == "" then
    return nil, "HERDR_PANE_ID が見つかりません(herdr の pane で neovim を起動してください)"
  end

  local pane_out = shell(herdr_bin() .. " pane get " .. vim.fn.shellescape(pane_id))
  if not pane_out then return nil, "herdr pane get に失敗しました" end
  local pane_ok, pane_data = pcall(vim.json.decode, pane_out)
  if not pane_ok then return nil, "herdr pane get の出力を解析できませんでした" end
  local workspace_id = vim.tbl_get(pane_data, "result", "pane", "workspace_id")
  if not workspace_id then return nil, "workspace_id を取得できませんでした" end

  local agents_out = shell(herdr_bin() .. " agent list")
  if not agents_out then return nil, "herdr agent list に失敗しました" end
  local agents_ok, agents_data = pcall(vim.json.decode, agents_out)
  if not agents_ok then return nil, "herdr agent list の出力を解析できませんでした" end
  local agents = vim.tbl_get(agents_data, "result", "agents") or {}

  return M.select_target(agents, workspace_id, pane_id)
end

local function do_send(target, text)
  local result = vim.system({ herdr_bin(), "agent", "send", target, text }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("herdr agent send に失敗しました: " .. trim(result.stderr or ""), vim.log.levels.ERROR)
    return
  end
  vim.notify("herdr agent へ送信しました (" .. target .. ")", vim.log.levels.INFO)
end

-- Same shape as claude_review.lua's open_comment_float: scratch markdown
-- buffer in a floating window, <CR>/<C-CR> to save, q/<Esc> to cancel.
local function open_note_float(title, on_save)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  local width = math.min(80, vim.o.columns - 4)
  local height = 6
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    border = "rounded",
    title = string.format(" %s  (<CR>:send  q/<Esc>:cancel) ", title),
    title_pos = "left",
  })
  vim.cmd("startinsert")

  local function close() pcall(vim.api.nvim_win_close, win, true) end
  local function save()
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    text = trim(text)
    close()
    if text ~= "" then on_save(text) end
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

function M.send_range(start_line, end_line)
  local path = buf_path_relative()
  if not path then
    vim.notify("ファイルバッファ上で実行してください", vim.log.levels.WARN)
    return
  end

  local target, err = resolve_target_pane()
  if not target then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local range = M.format_range(start_line, end_line)
  open_note_float(string.format("%s:%s", path, range), function(note)
    do_send(target, M.format_message(path, range, note))
  end)
end

function M.send_normal()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  M.send_range(lnum, lnum)
end

function M.send_visual()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  M.send_range(start_line, end_line)
end

return M
