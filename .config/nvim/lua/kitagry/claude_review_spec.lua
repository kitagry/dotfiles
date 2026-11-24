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
      cr.add_comment("foo.go", 10, 10, "nil check")
      assert.are.same({ end_lnum = 10, text = "nil check" }, cr.get_comment("foo.go", 10))
    end)

    it("範囲付きコメントを追加できる", function()
      cr.add_comment("foo.go", 10, 15, "range comment")
      assert.are.same({ end_lnum = 15, text = "range comment" }, cr.get_comment("foo.go", 10))
    end)

    it("同じ開始行に追加すると上書きされる", function()
      cr.add_comment("foo.go", 10, 10, "first")
      cr.add_comment("foo.go", 10, 12, "second")
      assert.are.same({ end_lnum = 12, text = "second" }, cr.get_comment("foo.go", 10))
    end)

    it("削除すると get_comment は nil", function()
      cr.add_comment("foo.go", 10, 10, "nil check")
      cr.delete_comment("foo.go", 10)
      assert.is_nil(cr.get_comment("foo.go", 10))
    end)

    it("list_comments は path/lnum 順にソートされたフラットリストを返す", function()
      cr.add_comment("b.go", 5, 5, "B5")
      cr.add_comment("a.go", 20, 25, "A20")
      cr.add_comment("a.go", 3, 3, "A3")
      assert.are.same({
        { path = "a.go", lnum = 3, end_lnum = 3, text = "A3" },
        { path = "a.go", lnum = 20, end_lnum = 25, text = "A20" },
        { path = "b.go", lnum = 5, end_lnum = 5, text = "B5" },
      }, cr.list_comments())
    end)

    it("clear で全部消える", function()
      cr.add_comment("foo.go", 10, 10, "x")
      cr.add_comment("bar.go", 20, 20, "y")
      cr.clear()
      assert.are.same({}, cr.list_comments())
    end)

    it("空文字のコメントは追加できない (no-op)", function()
      cr.add_comment("foo.go", 10, 10, "")
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

  describe("find_comment_at", function()
    it("範囲外なら nil", function()
      cr.add_comment("foo.go", 10, 15, "x")
      assert.is_nil(cr.find_comment_at("foo.go", 9))
      assert.is_nil(cr.find_comment_at("foo.go", 16))
    end)

    it("範囲内の任意の行から開始行を引ける", function()
      cr.add_comment("foo.go", 10, 15, "x")
      assert.are.equal(10, cr.find_comment_at("foo.go", 10))
      assert.are.equal(10, cr.find_comment_at("foo.go", 12))
      assert.are.equal(10, cr.find_comment_at("foo.go", 15))
    end)
  end)

  describe("format_for_claude", function()
    it("コメントが空なら nil を返す", function()
      assert.is_nil(cr.format_for_claude())
    end)

    it("1件のコメントを整形できる", function()
      cr.add_comment("foo.go", 42, 42, "nil check が抜けている")
      local out = cr.format_for_claude({
        diff_excerpt = function(path, start_lnum, end_lnum)
          assert.are.equal("foo.go", path)
          assert.are.equal(42, start_lnum)
          assert.are.equal(42, end_lnum)
          return "- old\n+ new"
        end,
      })
      assert.is_truthy(out:find("### foo.go:42", 1, true))
      assert.is_truthy(out:find("- old\n+ new", 1, true))
      assert.is_truthy(out:find("> nil check が抜けている", 1, true))
    end)

    it("範囲コメントは path:start-end 形式になる", function()
      cr.add_comment("foo.go", 10, 15, "range")
      local out = cr.format_for_claude({ diff_excerpt = function() return "" end })
      assert.is_truthy(out:find("### foo.go:10-15", 1, true))
    end)

    it("複数コメントは path/lnum 順に並ぶ", function()
      cr.add_comment("b.go", 1, 1, "B")
      cr.add_comment("a.go", 2, 2, "A2")
      cr.add_comment("a.go", 1, 1, "A1")
      local out = cr.format_for_claude({ diff_excerpt = function() return "" end })
      local a1 = out:find("### a.go:1", 1, true)
      local a2 = out:find("### a.go:2", 1, true)
      local b1 = out:find("### b.go:1", 1, true)
      assert.is_truthy(a1 and a2 and b1)
      assert.is_true(a1 < a2)
      assert.is_true(a2 < b1)
    end)

    it("diff_excerpt が空文字なら diff ブロックを省略する", function()
      cr.add_comment("foo.go", 1, 1, "comment")
      local out = cr.format_for_claude({ diff_excerpt = function() return "" end })
      assert.is_nil(out:find("```\n```", 1, true))
    end)

    it("複数行コメントは引用ブロックの各行に > を付ける", function()
      cr.add_comment("foo.go", 1, 1, "line1\nline2")
      local out = cr.format_for_claude({ diff_excerpt = function() return "" end })
      assert.is_truthy(out:find("> line1", 1, true))
      assert.is_truthy(out:find("> line2", 1, true))
    end)
    it("wraps an excerpt containing ``` in a longer fence", function()
      cr.add_comment("README.md", 1, 1, "comment")
      local out = cr.format_for_claude({ diff_excerpt = function() return "+```lua\n+x\n+```" end })
      assert.is_truthy(out:find("````\n+```lua\n+x\n+```\n````", 1, true))
    end)
  end)

  describe("pick_hunk", function()
    local diff = table.concat({
      "diff --git a/a.py b/a.py",
      "index 111..222 100644",
      "--- a/a.py",
      "+++ b/a.py",
      "@@ -1,3 +1,4 @@",
      " import x",
      "+@decorator",
      " def f():",
      "     pass",
      "@@ -10,2 +11,3 @@ def g(): @@weird",
      " a",
      "+b @ c",
      " d",
    }, "\n")

    it("does not split a hunk on @ in its body", function()
      assert.are.equal(
        "@@ -1,3 +1,4 @@\n import x\n+@decorator\n def f():\n     pass",
        cr.pick_hunk(diff, 2, 2)
      )
    end)

    it("returns the hunk overlapping the range (even with @@ in the header function name)", function()
      assert.are.equal(
        "@@ -10,2 +11,3 @@ def g(): @@weird\n a\n+b @ c\n d",
        cr.pick_hunk(diff, 12, 20)
      )
    end)

    it("returns an empty string when no hunk overlaps", function()
      assert.are.equal("", cr.pick_hunk(diff, 6, 10))
    end)

    it("does not include the next file's header lines in the hunk", function()
      local two = diff .. "\ndiff --git a/b.py b/b.py\n--- a/b.py\n+++ b/b.py\n@@ -1 +1 @@\n-x\n+y"
      assert.are.equal("@@ -10,2 +11,3 @@ def g(): @@weird\n a\n+b @ c\n d", cr.pick_hunk(two, 12, 12))
    end)
  end)
end)
