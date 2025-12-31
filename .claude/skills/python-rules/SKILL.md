---
name: python-rules
description: Pythonプロジェクトでのコーディング規約。Pythonファイルを扱う際に自動適用されます。
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# Python コーディング規約

## Python実行コマンドの選択

プロジェクトの依存管理ツールに応じて、適切なPython実行コマンドを使用します：

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

## 確認方法

プロジェクトルートで以下のコマンドを実行して、どのツールが使われているか確認：
```bash
ls uv.lock poetry.lock 2>/dev/null
```
