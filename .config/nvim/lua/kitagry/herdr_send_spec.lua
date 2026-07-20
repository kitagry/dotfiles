-- plenary.busted で実行:
--   :PlenaryBustedFile %
-- もしくは:
--   nvim --headless -c "PlenaryBustedFile .config/nvim/lua/kitagry/herdr_send_spec.lua" -c qa

describe("herdr_send", function()
  local hs

  before_each(function()
    package.loaded["kitagry.herdr_send"] = nil
    hs = require("kitagry.herdr_send")
  end)

  describe("format_range", function()
    it("開始と終了が同じなら単一の行番号を返す", function()
      assert.are.equal("5", hs.format_range(5, 5))
    end)

    it("開始と終了が異なれば start-end 形式を返す", function()
      assert.are.equal("5-10", hs.format_range(5, 10))
    end)
  end)

  describe("format_message", function()
    it("path:range — note 形式を返す", function()
      assert.are.equal(
        "foo.go:5-10 — nil check が抜けている",
        hs.format_message("foo.go", "5-10", "nil check が抜けている")
      )
    end)
  end)

  describe("select_target", function()
    it("同じ workspace に自分以外の agent がいなければエラーを返す", function()
      local agents = {
        { pane_id = "w1:p1", workspace_id = "w1" },
      }
      local target, err = hs.select_target(agents, "w1", "w1:p1")
      assert.is_nil(target)
      assert.is_truthy(err:find("見つかりません", 1, true))
    end)

    it("agent が存在しない workspace ならエラーを返す", function()
      local target, err = hs.select_target({}, "w1", "w1:p1")
      assert.is_nil(target)
      assert.is_truthy(err:find("見つかりません", 1, true))
    end)

    it("別 workspace の agent は候補から除外される", function()
      local agents = {
        { pane_id = "w2:p1", workspace_id = "w2" },
      }
      local target, err = hs.select_target(agents, "w1", "w1:p1")
      assert.is_nil(target)
      assert.is_truthy(err:find("見つかりません", 1, true))
    end)

    it("同じ workspace に自分以外の agent が1つだけならその pane_id を返す", function()
      local agents = {
        { pane_id = "w1:p1", workspace_id = "w1" }, -- 自分自身
        { pane_id = "w1:p2", workspace_id = "w1", agent = "claude" },
      }
      local target, err = hs.select_target(agents, "w1", "w1:p1")
      assert.are.equal("w1:p2", target)
      assert.is_nil(err)
    end)

    it("同じ workspace に候補が複数あればエラーを返す", function()
      local agents = {
        { pane_id = "w1:p2", workspace_id = "w1", agent = "claude" },
        { pane_id = "w1:p3", workspace_id = "w1", agent = "codex" },
      }
      local target, err = hs.select_target(agents, "w1", "w1:p1")
      assert.is_nil(target)
      assert.is_truthy(err:find("複数", 1, true))
      assert.is_truthy(err:find("w1:p2", 1, true))
      assert.is_truthy(err:find("w1:p3", 1, true))
    end)
  end)
end)
