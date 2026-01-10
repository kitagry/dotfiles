---
name: test-writing
description: テストコードを書く際のベストプラクティスとルール。テストファイルを作成・編集する際に自動適用されます。
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# テストの書き方

## 基本原則

### 1. モックの使用制限

**原則**: モックはなるべく使わない

- **許可される場合**:
  - API呼び出し（外部サービスとの通信）
  - データベース呼び出し
  - その他の外部依存（ファイルシステム、ネットワーク等）

- **避けるべき**:
  - 内部のクラスやメソッドのモック
  - ビジネスロジックのモック
  - 簡単に実際のオブジェクトを使えるケース

**理由**: モックを使いすぎると、実装の詳細に依存したテストになり、リファクタリング時にテストが壊れやすくなる。

### 2. Fixtureの使用制限

**原則**: fixtureは使わない

- **テストデータの配置**:
  - テストデータはテスト関数内に直接記述する
  - 各テストで何がテストされているかが一目でわかるようにする

- **例外的に許可される場合**:
  - assertionに直接関係ないデータ（ダミーデータ等）
  - 複数のテストで共通して使うセットアップ処理

**良い例**:
```python
def test_calculate_total():
    # テストデータはここに直接記述
    items = [
        {"name": "apple", "price": 100},
        {"name": "banana", "price": 200},
    ]

    result = calculate_total(items)

    assert result == 300
```

**悪い例**:
```python
@pytest.fixture
def items():
    return [
        {"name": "apple", "price": 100},
        {"name": "banana", "price": 200},
    ]

def test_calculate_total(items):  # 何がテストされているか分かりにくい
    result = calculate_total(items)
    assert result == 300
```

## テストの粒度

### 1つのテストで1つの動作のみを検証

- テストは小さく保つ
- 複数のアサーションがある場合、それらは同じ動作の異なる側面を検証するべき
- テストが失敗した時、何が壊れたかすぐに分かるようにする

**良い例**:
```python
def test_user_creation_sets_username():
    user = User.create(username="alice")
    assert user.username == "alice"

def test_user_creation_generates_id():
    user = User.create(username="alice")
    assert user.id is not None
```

**悪い例**:
```python
def test_user_creation():  # 複数の異なる動作をテスト
    user = User.create(username="alice")
    assert user.username == "alice"
    assert user.id is not None
    assert user.created_at is not None
    assert user.is_active is True
```

## テストの命名

- テスト関数名は動作を説明する
- `test_<method>_<scenario>_<expected_behavior>` の形式を推奨

**例**:
```python
def test_calculate_total_with_empty_list_returns_zero()
def test_calculate_total_with_multiple_items_sums_prices()
def test_user_login_with_invalid_password_raises_error()
```

## アサーションのベストプラクティス

- 具体的なアサーションを使う（`assert x == 5` より `assert_equal(x, 5)`）
- エラーメッセージは明確に
- 期待値を先に、実際の値を後に記述

**良い例**:
```python
assert result == expected, f"Expected {expected}, but got {result}"
```

## テストの独立性

- 各テストは独立して実行可能であるべき
- テストの実行順序に依存しない
- 他のテストの状態に依存しない

## TDDとの関係

TDD（テスト駆動開発）を実践する場合は、`tdd-workflow` スキルと併用してください。
このスキルはTDD以外のテスト作成時にも適用されます。
