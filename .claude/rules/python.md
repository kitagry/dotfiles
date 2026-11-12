---
paths: "**/*.py"
---

# Python コーディング規約

## Python実行コマンドの選択

プロジェクトの依存管理ツールに応じて、適切なPython実行コマンドを使用します。

### 優先順位

1. **uv使用時** - `uv.lock` ファイルが存在する場合
   ```bash
   uv run python <script>
   uv run pytest
   ```

2. **poetry使用時** - `poetry.lock` ファイルが存在する場合
   ```bash
   poetry run python <script>
   poetry run pytest
   ```

3. **その他** - 上記のファイルがない場合
   ```bash
   python <script>
   pytest
   ```

### 確認方法

プロジェクトルートで以下のコマンドを実行して、どのツールが使われているか確認：
```bash
ls uv.lock poetry.lock 2>/dev/null
```

## DataFrame の比較は `pd.testing.assert_frame_equal` を使う

- `assert df1.equals(df2)` や `assert (df1 == df2).all().all()` は書かない — 失敗時に差分が出ず原因調査に時間がかかる
- pandas: `pd.testing.assert_frame_equal(actual, expected)` / Series は `assert_series_equal`
- 型・index・カラム順まで厳密に比較される。緩めたい時は `check_dtype=False` 等の引数で明示的に落とす
- polars を使うプロジェクトでは `polars.testing.assert_frame_equal` に読み替える
- 使わない方が良い明確な理由 (対象が DataFrame でない・ライブラリ非依存にしたい等) がある場合のみ他の手段でよい
