"""claude_timing.py のテスト。実行: python3 .claude/scripts/claude_timing_test.py"""

import json
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

# install.sh が .claude 配下を丸ごと symlink するため、__pycache__ を作らない
sys.dont_write_bytecode = True
import claude_timing as ct  # noqa: E402


def assistant(ts, tool_id, name, inp, agent_id=None, cwd="/repo/a"):
    m = {
        "type": "assistant",
        "timestamp": ts,
        "cwd": cwd,
        "message": {"content": [{"type": "tool_use", "id": tool_id, "name": name, "input": inp}]},
    }
    if agent_id:
        m.update(agentId=agent_id, isSidechain=True)
    return m


def result(ts, tool_id, agent_id=None):
    m = {
        "type": "user",
        "timestamp": ts,
        "message": {"content": [{"type": "tool_result", "tool_use_id": tool_id, "content": "ok"}]},
    }
    if agent_id:
        m.update(agentId=agent_id, isSidechain=True)
    return m


def write_jsonl(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(r) + "\n" for r in rows))


class NormalizeCommandTest(unittest.TestCase):
    def test_cd_and_env_prefix_are_stripped(self):
        self.assertEqual(ct.normalize_command("cd apps/x && (FOO=1 go test ./...)"), "go test")

    def test_single_word_tool(self):
        self.assertEqual(ct.normalize_command("rg foo bar"), "rg")

    def test_multi_word_tool(self):
        self.assertEqual(ct.normalize_command("gh pr checks 1793"), "gh pr")

    def test_export_and_set_prefix_are_stripped(self):
        self.assertEqual(ct.normalize_command("set -e; export A=1; go test ./..."), "go test")

    def test_loop(self):
        self.assertEqual(ct.normalize_command("for i in $(seq 1 3); do gh pr checks 1; done"), "for")


class IsPollingTest(unittest.TestCase):
    def test_loop_with_sleep(self):
        self.assertTrue(ct.is_polling("for i in $(seq 1 28); do gh pr checks 1; sleep 20; done"))

    def test_bare_sleep(self):
        self.assertTrue(ct.is_polling("sleep 280; echo ok"))

    def test_watch_flag(self):
        self.assertTrue(ct.is_polling("gh pr checks 779 --watch --interval 20"))

    def test_gh_run_watch(self):
        self.assertTrue(ct.is_polling("gh run watch 123"))

    def test_normal_command(self):
        self.assertFalse(ct.is_polling("go test ./..."))


class CollectTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        sess = root / "-repo-a" / "s1.jsonl"
        write_jsonl(sess, [
            assistant("2026-10-01T00:00:00.000Z", "t1", "Bash", {"command": "cd x && go test ./..."}),
            result("2026-10-01T00:01:40.000Z", "t1"),
            assistant("2026-10-01T00:02:00.000Z", "t2", "AskUserQuestion", {}),
            result("2026-10-01T00:12:00.000Z", "t2"),
            assistant("2026-10-01T00:13:00.000Z", "t3", "Agent", {"description": "review"}),
            result("2026-10-01T00:13:01.000Z", "t3"),
        ])
        sub = root / "-repo-a" / "s1" / "subagents"
        write_jsonl(sub / "agent-abc.jsonl", [
            assistant("2026-10-01T00:13:02.000Z", "u1", "Read", {"file_path": "/x"}, agent_id="abc"),
            result("2026-10-01T00:13:05.000Z", "u1", agent_id="abc"),
            assistant("2026-10-01T00:13:10.000Z", "u2", "Bash", {"command": "sleep 30"}, agent_id="abc"),
            result("2026-10-01T00:13:40.000Z", "u2", agent_id="abc"),
        ])
        (sub / "agent-abc.meta.json").write_text(json.dumps({"agentType": "review", "toolUseId": "t3"}))
        # since より古いセッションは無視される
        write_jsonl(root / "-repo-b" / "old.jsonl", [
            assistant("2026-09-01T00:00:00.000Z", "o1", "Bash", {"command": "ls"}, cwd="/repo/b"),
            result("2026-09-01T00:00:01.000Z", "o1"),
        ])
        self.calls, self.agents = ct.collect(root, since=datetime(2026, 9, 15, tzinfo=timezone.utc))

    def tearDown(self):
        self.tmp.cleanup()

    def by_id(self, tool_id):
        return next(c for c in self.calls if c.tool_id == tool_id)

    def test_tool_duration(self):
        c = self.by_id("t1")
        self.assertEqual(c.seconds, 100)
        self.assertEqual(c.key, "Bash: go test")
        self.assertEqual(c.agent_type, "main")
        self.assertEqual(c.repo, "/repo/a")
        self.assertFalse(c.human)

    def test_ask_user_is_human_wait(self):
        self.assertTrue(self.by_id("t2").human)

    def test_subagent_calls_carry_agent_type(self):
        c = self.by_id("u2")
        self.assertEqual(c.agent_type, "review")
        self.assertTrue(c.polling)
        self.assertEqual(c.repo, "/repo/a")

    def test_old_sessions_are_skipped(self):
        self.assertNotIn("o1", [c.tool_id for c in self.calls])

    def test_agent_span_uses_own_transcript(self):
        # background 起動だと親の Agent 呼び出しは即 return するので、子の jsonl の最初と最後で測る
        [a] = self.agents
        self.assertEqual((a.agent_type, a.seconds, a.tool_count, a.parent_tool_id), ("review", 38, 2, "t3"))


def epoch(s):
    return ct.parse_ts(s).timestamp()


class ApplyEventsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        write_jsonl(root / "-repo-a" / "s1.jsonl", [
            # 実行 10 秒 + 権限確認待ち 50 秒
            assistant("2026-10-01T00:00:00.000Z", "t1", "Bash", {"command": "rm x"}),
            result("2026-10-01T00:01:00.000Z", "t1"),
            # 同じコマンドの 2 回目は確認なし
            assistant("2026-10-01T00:02:00.000Z", "t2", "Bash", {"command": "rm x"}),
            result("2026-10-01T00:02:05.000Z", "t2"),
            # hook 導入前など events に無い呼び出し
            assistant("2026-10-01T00:03:00.000Z", "t3", "Read", {"file_path": "/x"}),
            result("2026-10-01T00:03:01.000Z", "t3"),
        ])
        self.calls, _ = ct.collect(root, since=datetime(2026, 9, 15, tzinfo=timezone.utc))
        events = [
            {"ts": epoch("2026-10-01T00:00:01Z"), "event": "PermissionRequest", "session_id": "s1",
             "tool_name": "Bash", "tool_input": {"command": "rm x"}, "rules": ["Bash(rm:*)"]},
            {"ts": epoch("2026-10-01T00:01:00Z"), "event": "PostToolUse", "session_id": "s1",
             "tool_name": "Bash", "tool_use_id": "t1", "duration_ms": 10000},
            {"ts": epoch("2026-10-01T00:02:05Z"), "event": "PostToolUseFailure", "session_id": "s1",
             "tool_name": "Bash", "tool_use_id": "t2", "duration_ms": 5000},
        ]
        self.rules = ct.apply_events(self.calls, events)

    def tearDown(self):
        self.tmp.cleanup()

    def by_id(self, tool_id):
        return next(c for c in self.calls if c.tool_id == tool_id)

    def test_wait_is_transcript_minus_exec(self):
        c = self.by_id("t1")
        self.assertEqual((c.exec_seconds, c.wait_seconds), (10, 50))

    def test_permission_request_attaches_to_latest_matching_call(self):
        self.assertTrue(self.by_id("t1").permission_prompted)
        self.assertFalse(self.by_id("t2").permission_prompted)

    def test_failure_event_also_gives_exec(self):
        self.assertEqual(self.by_id("t2").wait_seconds, 0)

    def test_calls_without_events_stay_unknown(self):
        c = self.by_id("t3")
        self.assertIsNone(c.exec_seconds)
        self.assertIsNone(c.wait_seconds)

    def test_suggested_rules_are_counted(self):
        self.assertEqual(self.rules, {"Bash(rm:*)": 1})


class LoadEventsTest(unittest.TestCase):
    def test_skips_old_and_broken_lines(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "events.jsonl"
            p.write_text(
                json.dumps({"ts": epoch("2026-09-01T00:00:00Z"), "event": "PostToolUse"}) + "\n"
                + "broken\n"
                + json.dumps({"ts": epoch("2026-10-01T00:00:00Z"), "event": "PostToolUse"}) + "\n"
            )
            events = ct.load_events(p, since=datetime(2026, 9, 15, tzinfo=timezone.utc))
            self.assertEqual(len(events), 1)

    def test_missing_file(self):
        self.assertEqual(ct.load_events(Path("/nonexistent/x.jsonl"), since=datetime.now(timezone.utc)), [])


class PercentileTest(unittest.TestCase):
    def test_p50_p95(self):
        xs = list(range(1, 101))
        self.assertEqual(ct.percentile(xs, 50), 50)
        self.assertEqual(ct.percentile(xs, 95), 95)


if __name__ == "__main__":
    unittest.main()
