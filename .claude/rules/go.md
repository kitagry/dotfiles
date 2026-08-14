---
paths: "**/*.go"
---

# Go コーディング規約

## テストの context は `t.Context()` (Go 1.24+)

- `context.Background()` は使わない — `t.Context()` はテスト終了時に自動 cancel される
- timeout 等で派生させる時も root を `t.Context()` に: `context.WithTimeout(t.Context(), ...)`
- benchmark / fuzz は `b.Context()` / `f.Context()`
- Go 1.24 未満 (`go.mod` の `go` directive で判定) のみ `context.Background()` + `defer cancel()`

## map → slice 変換は `slices.Collect(maps.Keys(m))` / `maps.Values` (Go 1.23+)

- 手書きの `make([]K, 0, len(m))` + `for k := range m { s = append(s, k) }` は書かない
- keys: `slices.Collect(maps.Keys(m))`、values: `slices.Collect(maps.Values(m))`
- 決定的な順序が欲しい場合は `slices.Sorted(maps.Keys(m))` (comparable key のみ)
- Go 1.23 未満 (`go.mod` 判定) のみ手書きループ
