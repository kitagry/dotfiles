#!/usr/bin/env python3
"""Claude Code のトランスクリプトから、ツール呼び出し・サブエージェントの所要時間を集計する。

一次ソースは ~/.claude/projects/<proj>/<session>.jsonl と <session>/subagents/agent-<id>.jsonl。
全メッセージに timestamp が残っているので、tool_use と tool_result の差分で所要時間が出る。
ただしこの差分には権限確認の待ちが混ざるため、.claude/hooks/timing-log.sh が記録する
~/.claude/timing/events.jsonl (PostToolUse の duration_ms と PermissionRequest) があれば
実行時間と待ち時間に分ける。

使い方: claude_timing.py [--since 7d] [--project <部分一致>] [--top 20] [--json]
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

HUMAN_TOOLS = {"AskUserQuestion", "ExitPlanMode"}
# サブコマンドまで見ないと区別できないツール (gh pr / gh run 等)
MULTI_WORD_TOOLS = {
    "go", "uv", "gh", "git", "npm", "pnpm", "yarn", "docker", "kubectl", "gcloud",
    "cargo", "make", "mise", "bq", "gws", "poetry", "aws",
}
# 本体の前に置かれがちな準備用の文。これらは飛ばして次の文をコマンド名にする
PRELUDE_WORDS = {"cd", "export", "set", "source", ".", "unset"}
ENV_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=\S*$")


@dataclass
class Call:
    session: str
    agent_type: str
    repo: str
    tool_id: str
    key: str
    detail: str
    start: datetime
    seconds: float
    polling: bool
    human: bool
    tool: str = ""
    input_json: str = ""
    # events.jsonl が無い (hook 導入前など) 呼び出しは None のまま
    exec_seconds: float | None = None
    wait_seconds: float | None = None
    permission_prompted: bool = False


@dataclass
class AgentSpan:
    session: str
    agent_id: str
    agent_type: str
    description: str
    parent_tool_id: str
    repo: str
    start: datetime
    seconds: float
    tool_count: int


def parse_ts(s: str) -> datetime:
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def normalize_command(cmd: str) -> str:
    # `cd ... &&` や `export ...;` の後が本体。サブシェルの括弧と先頭の環境変数代入も外す
    body = re.split(r"&&|;", cmd.strip())
    words: list[str] = []
    for part in body:
        ws = part.replace("(", " ").replace(")", " ").split()
        while ws and ENV_ASSIGN.match(ws[0]):
            ws = ws[1:]
        if ws and ws[0] not in PRELUDE_WORDS:
            words = ws
            break
    if not words:
        return "cd"
    if words[0] in MULTI_WORD_TOOLS and len(words) > 1 and not words[1].startswith("-"):
        return f"{words[0]} {words[1]}"
    return words[0]


def is_polling(cmd: str) -> bool:
    return re.search(r"\b(sleep|while|until)\b|--watch\b|\bgh run watch\b", cmd) is not None


def percentile(xs: list[float], p: float) -> float:
    s = sorted(xs)
    return s[max(0, math.ceil(p / 100 * len(s)) - 1)]


def _canonical(obj) -> str:
    return json.dumps(obj, sort_keys=True, ensure_ascii=False)


def load_events(path: Path, since: datetime) -> list[dict]:
    if not path.exists():
        return []
    since_epoch = since.timestamp()
    return [e for e in _read_jsonl(path) if e.get("ts", 0) >= since_epoch]


def apply_events(calls: list[Call], events: list[dict]) -> Counter:
    """Call に実行時間・待ち時間・権限確認の有無を付け、提案された allow ルールの出現数を返す。"""
    by_id = {c.tool_id: c for c in calls}
    by_input = defaultdict(list)
    for c in calls:
        by_input[(c.session, c.tool, c.input_json)].append(c)
    rules: Counter = Counter()
    for e in events:
        if e.get("event") in ("PostToolUse", "PostToolUseFailure"):
            c = by_id.get(e.get("tool_use_id"))
            if c and e.get("duration_ms") is not None:
                c.exec_seconds = e["duration_ms"] / 1000
                c.wait_seconds = max(0.0, c.seconds - c.exec_seconds)
        elif e.get("event") == "PermissionRequest":
            rules.update(e.get("rules") or [])
            # tool_use_id が無いので、同じ入力のうち確認が出る直前に始まった呼び出しに紐づける
            ts = datetime.fromtimestamp(e["ts"], timezone.utc)
            key = (e.get("session_id"), e.get("tool_name"), _canonical(e.get("tool_input") or {}))
            cands = [c for c in by_input.get(key, []) if c.start <= ts]
            if cands:
                max(cands, key=lambda c: c.start).permission_prompted = True
    return rules


def _read_jsonl(path: Path):
    with path.open() as f:
        for line in f:
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def _calls_in(path: Path, session: str, agent_type: str, default_repo: str, since: datetime):
    """戻り値: (calls, 最後に見た cwd, 全メッセージの timestamp 一覧, tool_use 数)"""
    uses: dict[str, tuple[dict, datetime, str]] = {}
    calls: list[Call] = []
    stamps: list[datetime] = []
    repo = default_repo
    tool_count = 0
    for m in _read_jsonl(path):
        if "timestamp" not in m:
            continue
        ts = parse_ts(m["timestamp"])
        stamps.append(ts)
        repo = m.get("cwd", repo)
        content = (m.get("message") or {}).get("content")
        if not isinstance(content, list):
            continue
        for c in content:
            if c.get("type") == "tool_use":
                tool_count += 1
                uses[c["id"]] = (c, ts, repo)
            elif c.get("type") == "tool_result" and c.get("tool_use_id") in uses:
                u, start, use_repo = uses.pop(c["tool_use_id"])
                if start < since:
                    continue
                name = u["name"]
                inp = u.get("input") or {}
                cmd = inp.get("command", "") if name == "Bash" else ""
                key = f"Bash: {normalize_command(cmd)}" if name == "Bash" else name
                detail = cmd or inp.get("description") or inp.get("file_path") or inp.get("pattern") or ""
                calls.append(Call(
                    session=session, agent_type=agent_type, repo=use_repo, tool_id=u["id"], key=key,
                    detail=str(detail).replace("\n", " ")[:80], start=start,
                    seconds=(ts - start).total_seconds(), polling=bool(cmd) and is_polling(cmd),
                    human=name in HUMAN_TOOLS, tool=name, input_json=_canonical(inp),
                ))
    return calls, repo, stamps, tool_count


def collect(projects_dir: Path, since: datetime) -> tuple[list[Call], list[AgentSpan]]:
    calls: list[Call] = []
    agents: list[AgentSpan] = []
    since_epoch = since.timestamp()
    for sess_file in projects_dir.glob("*/*.jsonl"):
        sess_dir = sess_file.with_suffix("")
        sub_files = list(sess_dir.rglob("subagents/agent-*.jsonl")) if sess_dir.is_dir() else []
        if max([sess_file.stat().st_mtime] + [f.stat().st_mtime for f in sub_files]) < since_epoch:
            continue
        session = sess_file.stem
        main_calls, repo, _, _ = _calls_in(sess_file, session, "main", "", since)
        calls += main_calls
        for sub in sub_files:
            meta_path = sub.with_name(sub.stem + ".meta.json")
            meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
            agent_type = meta.get("agentType", "unknown")
            sub_calls, sub_repo, stamps, tool_count = _calls_in(sub, session, agent_type, repo, since)
            calls += sub_calls
            if stamps and min(stamps) >= since:
                agents.append(AgentSpan(
                    session=session, agent_id=sub.stem.removeprefix("agent-"), agent_type=agent_type,
                    description=meta.get("description", ""), parent_tool_id=meta.get("toolUseId", ""),
                    repo=sub_repo, start=min(stamps), seconds=(max(stamps) - min(stamps)).total_seconds(),
                    tool_count=tool_count,
                ))
    return calls, agents


def _fmt(sec: float) -> str:
    sec = int(sec)
    if sec >= 3600:
        return f"{sec // 3600}h{sec % 3600 // 60:02d}m"
    if sec >= 60:
        return f"{sec // 60}m{sec % 60:02d}s"
    return f"{sec}s"


def _table(title: str, header: list[str], rows: list[list[str]]) -> str:
    out = [f"## {title}", "", "| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    out += ["| " + " | ".join(r) + " |" for r in rows]
    return "\n".join(out) + "\n"


def _group(items, key, sec):
    g = defaultdict(list)
    for it in items:
        g[key(it)].append(sec(it))
    return sorted(g.items(), key=lambda kv: -sum(kv[1]))


def _repo_name(path: str) -> str:
    # worktree (…/<repo>-wt/<branch> や .herdr/worktrees/<name>) でも識別できるよう末尾 2 要素を残す
    parts = Path(path).parts
    return "/".join(parts[-2:]) if parts else "(unknown)"


def report(calls: list[Call], agents: list[AgentSpan], top: int, rules: Counter | None = None) -> str:
    machine = [c for c in calls if not c.human]
    human = [c for c in calls if c.human]
    polling = [c for c in machine if c.polling]
    total = sum(c.seconds for c in machine)
    out = [
        "# Claude timing report", "",
        f"- ツール実行合計: {_fmt(total)} ({len(machine)} 回)",
        f"- うちポーリング (sleep / while / until / --watch): {_fmt(sum(c.seconds for c in polling))} ({len(polling)} 回)",
        f"- 人間待ち (AskUserQuestion 等): {_fmt(sum(c.seconds for c in human))} ({len(human)} 回)",
        f"- サブエージェント: {len(agents)} 体 / 合計 {_fmt(sum(a.seconds for a in agents))}",
    ]
    measured = [c for c in machine if c.wait_seconds is not None]
    prompted = [c for c in measured if c.permission_prompted]
    if measured:
        out.append(
            f"- 権限確認の待ち (hook 計測分 {len(measured)} 回のうち): "
            f"{_fmt(sum(c.wait_seconds for c in prompted))} (確認 {len(prompted)} 回)"
        )
    out.append("")
    out.append(_table(
        f"遅いツール呼び出し Top {top}", ["秒", "agent", "repo", "tool", "detail"],
        [[_fmt(c.seconds), c.agent_type, _repo_name(c.repo), c.key + (" ⏳" if c.polling else ""),
          f"`{c.detail.replace('|', '¦').replace('`', '')}`"]
         for c in sorted(machine, key=lambda c: -c.seconds)[:top]],
    ))
    out.append(_table(
        "ツール / コマンド別", ["key", "合計", "回数", "p50", "p95", "max"],
        [[k, _fmt(sum(v)), str(len(v)), _fmt(percentile(v, 50)), _fmt(percentile(v, 95)), _fmt(max(v))]
         for k, v in _group(machine, lambda c: c.key, lambda c: c.seconds)[:top]],
    ))
    tools_by_type = defaultdict(int)
    for a in agents:
        tools_by_type[a.agent_type] += a.tool_count
    out.append(_table(
        "サブエージェント種別", ["agentType", "体数", "合計", "p50", "p95", "ツール回数"],
        [[k, str(len(v)), _fmt(sum(v)), _fmt(percentile(v, 50)), _fmt(percentile(v, 95)), str(tools_by_type[k])]
         for k, v in _group(agents, lambda a: a.agent_type, lambda a: a.seconds)],
    ))
    if prompted:
        out.append(_table(
            "権限確認の待ち (コマンド別)", ["key", "合計待ち", "確認回数", "max"],
            [[k, _fmt(sum(v)), str(len(v)), _fmt(max(v))]
             for k, v in _group(prompted, lambda c: c.key, lambda c: c.wait_seconds)[:top]],
        ))
    if rules:
        out.append(_table(
            "allow 候補 (PermissionRequest の提案ルール)", ["rule", "回数"],
            [[f"`{r}`", str(n)] for r, n in rules.most_common(top)],
        ))
    out.append(_table(
        "リポジトリ別 (ツール実行時間)", ["repo", "合計", "回数"],
        [[k, _fmt(sum(v)), str(len(v))] for k, v in _group(machine, lambda c: _repo_name(c.repo), lambda c: c.seconds)[:top]],
    ))
    return "\n".join(out)


def parse_since(s: str) -> datetime:
    m = re.fullmatch(r"(\d+)([dh])", s)
    if not m:
        return datetime.fromisoformat(s).replace(tzinfo=timezone.utc)
    n, unit = int(m[1]), m[2]
    return datetime.now(timezone.utc) - (timedelta(days=n) if unit == "d" else timedelta(hours=n))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--since", default="7d", help="7d / 24h / 2026-10-01 (default: 7d)")
    ap.add_argument("--project", help="repo (cwd) の部分一致で絞る")
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--json", action="store_true", help="集計前の生データを JSON Lines で出す")
    ap.add_argument("--projects-dir", type=Path, default=Path.home() / ".claude" / "projects")
    ap.add_argument("--events", type=Path, default=Path.home() / ".claude" / "timing" / "events.jsonl")
    args = ap.parse_args()

    since = parse_since(args.since)
    calls, agents = collect(args.projects_dir, since)
    events = load_events(args.events, since)
    if args.project:
        events = [e for e in events if args.project in e.get("cwd", "")]
    rules = apply_events(calls, events)
    if args.project:
        calls = [c for c in calls if args.project in c.repo]
        agents = [a for a in agents if args.project in a.repo]
    if args.json:
        for kind, items in (("call", calls), ("agent", agents)):
            for it in items:
                d = asdict(it)
                d.pop("input_json", None)
                print(json.dumps({"kind": kind, **d}, default=str, ensure_ascii=False))
        return
    sys.stdout.write(report(calls, agents, args.top, rules))


if __name__ == "__main__":
    main()
