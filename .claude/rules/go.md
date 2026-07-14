---
paths: "**/*.go"
---

# Go コーディング規約

## テストの context は `t.Context()` (Go 1.24+)

- `context.Background()` は使わない — `t.Context()` はテスト終了時に自動 cancel される
- timeout 等で派生させる時も root を `t.Context()` に: `context.WithTimeout(t.Context(), ...)`
- benchmark / fuzz は `b.Context()` / `f.Context()`
- Go 1.24 未満 (`go.mod` の `go` directive で判定) のみ `context.Background()` + `defer cancel()`
