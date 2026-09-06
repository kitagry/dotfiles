-- plenary.busted で実行:
--   :PlenaryBustedFile %
-- もしくは:
--   nvim --headless -c "PlenaryBustedFile .config/nvim/lua/kitagry/claude_review_spec.lua" -c qa

describe("claude_review", function()
  local cr

  before_each(function()
    package.loaded["kitagry.claude_review"] = nil
    cr = require("kitagry.claude_review")
    cr.clear()
  end)

  describe("state", function()
    it("空の状態では list_comments が空", function()
      assert.are.same({}, cr.list_comments())
    end)

    it("追加したコメントを取得できる", function()
      cr.add_comment("foo.go", 10, "nil check")
      assert.are.equal("nil check", cr.get_comment("foo.go", 10))
    end)

    it("同じ行に追加すると上書きされる", function()
      cr.add_comment("foo.go", 10, "first")
      cr.add_comment("foo.go", 10, "second")
      assert.are.equal("second", cr.get_comment("foo.go", 10))
    end)

    it("削除すると get_comment は nil", function()
      cr.add_comment("foo.go", 10, "nil check")
      cr.delete_comment("foo.go", 10)
      assert.is_nil(cr.get_comment("foo.go", 10))
    end)

    it("list_comments は path/lnum 順にソートされたフラットリストを返す", function()
      cr.add_comment("b.go", 5, "B5")
      cr.add_comment("a.go", 20, "A20")
      cr.add_comment("a.go", 3, "A3")
      assert.are.same({
        { path = "a.go", lnum = 3, text = "A3" },
        { path = "a.go", lnum = 20, text = "A20" },
        { path = "b.go", lnum = 5, text = "B5" },
      }, cr.list_comments())
    end)

    it("clear で全部消える", function()
      cr.add_comment("foo.go", 10, "x")
      cr.add_comment("bar.go", 20, "y")
      cr.clear()
      assert.are.same({}, cr.list_comments())
    end)

    it("空文字のコメントは追加できない (no-op)", function()
      cr.add_comment("foo.go", 10, "")
      assert.is_nil(cr.get_comment("foo.go", 10))
    end)
  end)

  describe("diff_spec", function()
    it("branch モードは merge-base 起点 (working tree 込み) になる", function()
      local spec = cr.diff_spec({ mode = "branch", merge_base = "abc123" })
      assert.are.equal("abc123", spec.diffview_args)
      assert.are.equal("abc123", spec.git_diff_range)
    end)

    it("working モードは引数なし (未コミットのみ)", function()
      local spec = cr.diff_spec({ mode = "working", merge_base = "abc123" })
      assert.are.equal("", spec.diffview_args)
      assert.are.equal("", spec.git_diff_range)
    end)

    it("rev の明示指定が mode より優先される", function()
      local spec = cr.diff_spec({ mode = "working", merge_base = "abc123", rev = "origin/main...HEAD" })
      assert.are.equal("origin/main...HEAD", spec.diffview_args)
      assert.are.equal("origin/main...HEAD", spec.git_diff_range)
    end)

    it("merge_base が取れなければ branch モードでも引数なしにフォールバックする", function()
      local spec = cr.diff_spec({ mode = "branch" })
      assert.are.equal("", spec.diffview_args)
      assert.are.equal("", spec.git_diff_range)
    end)

    it("mode 未指定は branch 扱い", function()
      local spec = cr.diff_spec({ merge_base = "abc123" })
      assert.are.equal("abc123", spec.diffview_args)
    end)
  end)

  describe("format_for_claude", function()
    it("コメントが空なら nil を返す", function()
      assert.is_nil(cr.format_for_claude())
    end)

    it("1件のコメントを整形できる", function()
      cr.add_comment("foo.go", 42, "nil check が抜けている")
      local out = cr.format_for_claude({
        diff_excerpt = function(path, lnum)
          assert.are.equal("foo.go", path)
          assert.are.equal(42, lnum)
          return "- old\n+ new"
        end,
      })
      assert.is_truthy(out:find("### foo.go:42", 1, true))
      assert.is_truthy(out:find("- old\n+ new", 1, true))
      assert.is_truthy(out:find("> nil check が抜けている", 1, true))
    end)

    it("複数コメントは path/lnum 順に並ぶ", function()
      cr.add_comment("b.go", 1, "B")
      cr.add_comment("a.go", 2, "A2")
      cr.add_comment("a.go", 1, "A1")
      local out = cr.format_for_claude({ diff_excerpt = function() return "" end })
      local a1 = out:find("### a.go:1", 1, true)
      local a2 = out:find("### a.go:2", 1, true)
      local b1 = out:find("### b.go:1", 1, true)
      assert.is_truthy(a1 and a2 and b1)
      assert.is_true(a1 < a2)
      assert.is_true(a2 < b1)
    end)

    it("diff_excerpt が空文字なら diff ブロックを省略する", function()
      cr.add_comment("foo.go", 1, "comment")
      local out = cr.format_for_claude({ diff_excerpt = function() return "" end })
      assert.is_nil(out:find("```\n```", 1, true))
    end)

    it("複数行コメントは引用ブロックの各行に > を付ける", function()
      cr.add_comment("foo.go", 1, "line1\nline2")
      local out = cr.format_for_claude({ diff_excerpt = function() return "" end })
      assert.is_truthy(out:find("> line1", 1, true))
      assert.is_truthy(out:find("> line2", 1, true))
    end)
  end)
end)
