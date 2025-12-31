---
description: TDD赤フェーズ - 失敗するテストを書く
---

# TDD - 赤フェーズ（Red Phase）

## 目的
新しい機能や動作を検証する失敗するテストを書きます。

## 実施手順

1. **実装したい機能の特定**
   - どんな小さな動作を追加/変更したいか明確にする

2. **テストを書く**
   - その動作を検証するテストケースを作成
   - テストデータはテスト関数内に直接記述（fixtureは使わない）
   - assertionに関係ないデータのみfixture利用可

3. **テストを実行**
   - テストが失敗することを確認
   - 失敗理由が想定通りか検証

## テスト実行例

### Python
```bash
# uv.lockがある場合
uv run python -m pytest -v <test_file>

# poetry.lockがある場合
poetry run python -m pytest -v <test_file>

# それ以外
python -m pytest -v <test_file>
```

### Go
```bash
go test -v ./<package_path>
```

### Node.js
```bash
npm test -- <test_file>
```

## 重要な原則

- **モックの使用**: なるべく使わない（API/DB呼び出しのみ許可）
- **テストの粒度**: 小さく、1つの動作のみを検証
- **コメント**: WHYを書く（なぜこのテストが必要か）

## 次のステップ

テストが失敗することを確認したら `/tdd-green` で実装フェーズへ
