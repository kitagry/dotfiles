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

## JSON は `encoding/json/v2` を使う (Go 1.27+)

Go 1.27 (2026-08) で `encoding/json/v2` と `encoding/json/jsontext` が正式化された (GOEXPERIMENT 不要)。v1 (`encoding/json`) も内部的に v2 実装 + `DefaultOptionsV1()` で動くようになった。公式ドキュメントも「新規の json 利用はすべて v2 を使うべき」としている。

- **`go.mod` の `go` directive が 1.27 以上なら、新規コード・手を入れた箇所は v2 を使う**。1.27 未満のリポでは v1 のまま (v2 は GOEXPERIMENT=jsonv2 が要るので使わない)
- import は `"encoding/json/v2"` (パッケージ名は `json`)。v1 と併用するときは `jsonv1 "encoding/json"` と別名を付ける
- **既存コードの一括書き換えはしない**。v1 は永久にサポートされる。移行は「触ったファイルから」か、下記の段階移行で
- **Go 1.27 に上げるだけで v1 のエラーメッセージ文言が変わる**。エラー文字列に依存したテストは壊れるので `errors.As` / `errors.Is` に直す。どうしても旧実装が要るなら `GOEXPERIMENT=nojsonv2` でビルドできるが、将来削除予定の一時逃げ道

### v1 との挙動差 (ハマりどころ)

v2 は「厳格・相互運用性重視」のデフォルトになった。v1 と同じ挙動に戻す Option が各項目にある。

| 項目 | v1 | v2 | v2 で v1 に戻す Option |
| --- | --- | --- | --- |
| 不正 UTF-8 | U+FFFD に置換 | **エラー** | `jsontext.AllowInvalidUTF8(true)` |
| 重複キー | 後勝ちで許容 | **エラー** | `jsontext.AllowDuplicateNames(true)` |
| struct フィールド名の照合 | 大文字小文字を無視 | **完全一致** | `json.MatchCaseInsensitiveNames(true)` / タグ `case:ignore` |
| nil slice / nil map | `null` | **`[]` / `{}`** | `json.FormatNilSliceAsNull(true)` / `json.FormatNilMapAsNull(true)` |
| map のキー順 | ソート済み | **非決定的** | `json.Deterministic(true)` (golden テスト・署名・ハッシュ用途では必須) |
| `omitempty` | Go のゼロ値 (false / 0 / nil) で省略 | **JSON として空 (null / "" / [] / {}) のときだけ省略** | `jsonv1.OmitEmptyWithLegacySemantics(true)`。bool / 数値 / pointer は **`omitzero` に書き換える** のが正解 |
| `string` タグ | string / bool / 数値 / pointer を quote | **JSON number になる型だけ** | `jsonv1.StringifyWithLegacySemantics(true)` |
| HTML / JS 文字のエスケープ | `<>&` 等をエスケープ | **最小限のみ** | `jsontext.EscapeForHTML(true)` / `jsontext.EscapeForJS(true)` |
| `time.Duration` | ナノ秒の number | **エラー** | `jsonv1.FormatDurationAsNano(true)` か自前型 |
| `[N]byte` | number の配列 | **Base64 文字列** | `jsonv1.FormatByteArrayAsArray(true)` |
| Go 配列への unmarshal | 長さ不一致を許容 | **長さ一致必須** | `jsonv1.UnmarshalArrayFromAnyLength(true)` |
| JSON `null` の unmarshal | ゼロ化したりしなかったり | **常にゼロ化** | `jsonv1.MergeWithLegacySemantics(true)` |
| 既存値への merge | slice 要素等も merge | **object のみ merge、他は置換** | `jsonv1.MergeWithLegacySemantics(true)` |
| pointer receiver の `MarshalJSON` | addressable のときだけ呼ぶ | **常に呼ぶ**。map key でも呼ぶ | `jsonv1.CallMethodsWithLegacySemantics(true)` |
| struct 定義の不備 (unexported に json tag、JSON 化できるフィールドが無い等) | 無視 | **実行時エラー** | `jsonv1.ReportErrorsWithLegacySemantics(true)` |

- 外部 API のレスポンスを unmarshal するコードは **重複キー・大文字小文字・不正 UTF-8** で急に落ちる可能性が一番高い。移行時はこの 3 つを最初に疑う
- フロントに返す JSON で `null` と `[]` を区別しているなら `FormatNilSliceAsNull` を付けるか、型側を見直す

### API 対応表

| v1 | v2 |
| --- | --- |
| `json.Marshal(v)` / `json.Unmarshal(b, &v)` | 同名。可変長で `Options` を渡せる |
| `json.NewEncoder(w).Encode(v)` | `json.MarshalWrite(w, v)` (**末尾改行は付かない**。NDJSON なら自分で `\n` を書く) |
| `json.NewDecoder(r).Decode(&v)` | `json.UnmarshalRead(r, &v)` (**EOF まで読み切る単一値用**)。ストリームで複数値を読むなら `dec := jsontext.NewDecoder(r)` + `json.UnmarshalDecode(dec, &v)` をループ |
| `json.MarshalIndent(v, "", "  ")` | `json.Marshal(v, jsontext.Multiline(true), jsontext.WithIndent("  "))` |
| `json.RawMessage` | `jsontext.Value` (v1 の `RawMessage` は alias なので相互に渡せる) |
| `dec.DisallowUnknownFields()` | `json.RejectUnknownMembers(true)` |
| `MarshalJSON() ([]byte, error)` | **`MarshalJSONTo(*jsontext.Encoder) error`** を推奨 (ストリーミングで速い)。旧 `MarshalJSON` も引き続き動く |
| `UnmarshalJSON([]byte) error` | **`UnmarshalJSONFrom(*jsontext.Decoder) error`** を推奨。旧 `UnmarshalJSON` も動く |
| 型を変えずに表現を差し替えたい | `json.WithMarshalers(json.MarshalToFunc(func(enc *jsontext.Encoder, v T) error {...}))` / `WithUnmarshalers(UnmarshalFromFunc(...))` |

### struct タグ

- `omitzero` を基本にする。`IsZero() bool` があればそれを使う (`time.Time` 等)。`omitempty` は JSON 空値判定になったので「slice/map/string が空なら省略」の意図でだけ使う
- `case:ignore` / `case:strict` でフィールド単位に照合を指定できる。呼び出し側 Option より優先
- **`embed`** が Go 埋め込み相当 (実験期の `inline` は改名された)。`jsontext.Value` か `map[string]T` のフィールドに `json:",embed"` を付けると **未知フィールドの受け皿 (embedded fallback)** になる。実験期の `unknown` タグと `DiscardUnknownMembers` Option は削除された
- **`format` タグは削除された**。時刻フォーマットの指定 (`format:RFC1123` 等) や `format:emitnull` はもう無い。時刻は RFC 3339 固定で、変えたいなら自前型に `MarshalJSONTo` を実装するか `WithMarshalers` で差し替える
- 実験期 (Go 1.25/1.26 の GOEXPERIMENT) の記事をそのまま信じない。`inline` / `unknown` / `format` / `DiscardUnknownMembers` / `SkipFunc` を使った例は 1.27 ではコンパイルまたは実行時に失敗する

### 段階移行の手順

```go
import (
    jsonv1 "encoding/json"
    "encoding/json/v2"
)

// 1. まず v2 API に乗り換えつつ挙動は v1 のまま
b, err := json.Marshal(v, jsonv1.DefaultOptionsV1())

// 2. v1 互換 Option を 1 つずつ外して差分を潰す
b, err = json.Marshal(v, jsonv1.DefaultOptionsV1(), json.FormatNilSliceAsNull(false))

// 3. 全部外れたら Options なし (= DefaultOptionsV2)
b, err = json.Marshal(v)
```

- Option は後勝ち。`jsonv1.DefaultOptionsV1()` の後に v2 の Option を並べると、その項目だけ v2 挙動になる
- 本番トラフィックで v1/v2 の差分を検出したい場合は `github.com/go-json-experiment/jsonsplit` (両方呼んで差分を報告、v1 の結果を返す) で観測してから切り替える
- 参考: <https://go.dev/doc/go1.27> / <https://pkg.go.dev/encoding/json/v2> / <https://pkg.go.dev/encoding/json#hdr-Migrating_to_v2> / <https://go.dev/doc/jsonv2-migration>
