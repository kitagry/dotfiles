---
name: test-writing
description: テストコードを書く際のベストプラクティスとルール。テストファイルを作成・編集する際に自動適用されます。
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# テストの書き方

言語非依存の原則をまとめる。個別言語 (Go / Python / TS 等) の慣行は各言語ルールに従いつつ、ここに書かれた原則を優先する。

## テストの目的

良いテストは次を満たす:

1. **仕様書として読める** — テストを読めばコードの契約が分かる (docstring 不要)
2. **リファクタに強い** — 内部実装を変えても、振る舞いが同じなら通る
3. **失敗時の情報量が多い** — 何が・どこで・なぜ壊れたか一目で分かる
4. **シナリオを網羅する** — happy / edge / error の重要シナリオを押さえる

**カバレッジ率ではなくシナリオの網羅性を優先する**。行カバレッジ 100% でも、重要なシナリオを検証していなければ意味がない。

## ワークフロー

テストを書く際は必ず以下の順で進める。

### 1. 仕様を一行で言語化する

**実装を見る前に**、対象の関数/メソッドが何をするものかを一行で言語化する:

> 「この関数は __ するもの」

例:
- 「`calculate_total` は 商品リストから合計金額を計算するもの (空なら 0)」
- 「`login` は 認証情報からユーザーを認証し、失敗時は例外を投げるもの」

**一行で言語化できないなら、まだテストを書くべきではない**。仕様を明確化してから戻る。仕様が曖昧なままテストを書くと、後述の「実装のミラーテスト」に必ずなる。

### 2. シナリオを列挙する

言語化した仕様から検証すべきシナリオを列挙する:

- **happy path**: 正常系の代表的なケース
- **edge**: 境界値、空、限界値、上限/下限
- **error**: 不正入力、失敗系、例外

**シナリオは実装を見ずに、仕様だけから導き出せるべき**。実装を見ないと思いつかないシナリオは、実装詳細に依存している疑いがある (= ミラーテスト予備軍)。

### 3. テストを書く

各シナリオを 1 テストとして書く。詳細は「原則」参照。

### 4. self-review

書いた後、以下をチェックする。**いずれかが No なら書き直す**:

- [ ] 実装を隠して仕様だけを見せられたら、このテストを書けるか?
- [ ] 実装を等価にリファクタしたら (振る舞い同じで内部を書き換えたら) テストは通るか?
- [ ] 失敗したときに何が壊れたかがテスト名 + assertion から分かるか?
- [ ] 1 つのテストは 1 つのシナリオを検証しているか?
- [ ] 使ったモックは本当に外部依存 (API / DB / FS / 時刻 / 乱数) だけか?

## 原則

### モックは外部依存のみ

**モックしてよいもの**:
- 外部 API 呼び出し
- データベース
- ファイルシステム / ネットワーク
- 時刻 / 乱数 (テストの再現性のため)

**モックしないもの**:
- 内部クラス / メソッド
- ビジネスロジック
- 実オブジェクトで組み立てられるもの

**理由**: 内部モックは実装の呼び出し順序に依存したテストになり、リファクタで壊れる。「A が呼ばれた」「B が引数 X で呼ばれた」を検証しても、振る舞いの検証にはならない。

**実オブジェクトで組み立てが辛いと感じたら**、テストではなく設計 (責務分離) の問題を疑う。

### fixture より inline

テストデータはテスト関数内に直接書く。**「このテストが何を検証しているか」がその関数内だけで読めるべき**。

例外:
- assertion に直接関係ないダミーデータ (認証済みユーザーの雛形など)
- 複数テストで共通の重い setup (DB コンテナ起動など)

### 1 テスト 1 シナリオ

1 つのテスト関数は 1 つの振る舞いのみ検証する。複数の assertion があっても、それらは**同じ振る舞いの異なる側面**であるべき。

**検知**: テスト名に `and` / `_and_` が入っていたら詰め込みすぎの疑い。

### テスト名は行動を平文で描写

言語の慣行に従いつつ、**行動を平文で描写する**。主語は自明なら省略可。

- Go: `TestCalculateTotal_ReturnsZeroWhenListIsEmpty`
- Python: `test_returns_zero_when_list_is_empty`
- TS: `it("returns zero when list is empty")`

**テスト名だけで「何を検証しているか」が伝わるように書く**。`test_1` / `test_success` は NG。

### Table-driven / parameterize は積極活用

境界値や同型シナリオの列挙には積極的に使う。**各ケースには case name / id を必ず付ける** (失敗時にどのケースが落ちたか分かるように)。

ただし、**シナリオが本質的に異なる** (setup が違う / 検証観点が違う) ものを無理にまとめない。「同じ入力形式で期待値だけ違う」ものが table 化の適切なスコープ。

### 入力値はシナリオを語る

入力値だけを見て「このテストが何を検証したいか」が伝わるように選ぶ:

- `[]` → 空のケースを検証している
- `0` / `-1` / `MAX_INT` → 境界値を検証している
- `"not-an-email"` → 不正入力を検証している

**「リアルっぽい値」より「シナリオを語る値」を優先**。プロダクションに近い値は統合テストに任せる。

### DRY vs DAMP: バランス型

- **ノイズなセットアップ** (テスト本旨と無関係な認証準備 / DB 接続 / ダミーユーザー生成) → helper 化して良い
- **シナリオの中身** (入力データ / 期待値 / 振る舞い) → テスト関数内に直接書く

**「helper を辿らないと何がテストされているか分からない」状態は避ける**。

### assertion は情報量を最大化

**構造体/オブジェクト全体を 1 回で比較する**:

```
# 良い: 失敗時に何が違うか diff で一目
assert result == expected_user

# 悪い: 4 回書いていて、最初の assert で失敗すると 2 番目以降が見えない
assert result.name == "alice"
assert result.id == 1
assert result.email == "alice@example.com"
assert result.active is True
```

例外: フィールド単位で「その条件が満たされていること」を検証したい場合 (ID は自動採番で予測不能等) は分けて OK。ただしその場合も、比較不能なフィールドを除いた残りは構造体まるごと比較を検討する。

**assertion には必ず message を付ける**:

```
# 良い: 失敗時に何を期待していたかが残る
assert result == 300, f"expected sum 300, got {result}"

# 悪い: 「値が違う」しか分からない
assert result == 300
```

言語/フレームワークが自動で diff を出してくれる場合 (Go の `cmp.Diff` / Jest 等) はそれで代替可。**「テストが落ちたときに追加調査せずに原因が分かる」ことが最終ゴール**。

## アンチパターン

### 1. 実装のミラーテスト

実装コードを見ながら、同じロジックをテスト側に写しているパターン。

**検知**:
- 仕様を一行で言語化しないとテストが書けない
- 実装の定数を assert 側にもそのまま書き写している
- 実装をリファクタするとテストも一緒に直す必要がある

**bad**:
```
# 実装
def discount(price):
    return price * 0.8  # 20% off

# 実装をそのまま写している (実装の 0.8 を変えたらテストも直す)
def test_discount():
    assert discount(100) == 100 * 0.8
```

**good**:
```
# 仕様「20% 割引される」を検証。リテラル 80 は仕様から導出した値
def test_returns_80_percent_of_original():
    result = discount(100)
    assert result == 80, f"expected 80 (20% off from 100), got {result}"
```

### 2. Mock だらけで何も検証してない

内部メソッドを全部モックして「A が呼ばれた」「B が引数 X で呼ばれた」だけ検証しているパターン。実装の呼び出し順を写経しているだけで、振る舞いを検証してない。

**検知**:
- テスト内に mock / spy が 3 個以上ある
- assertion が `mock.called_with(...)` ばかりで、返り値/副作用の検証がない
- 実装を等価にリファクタしただけでテストが落ちる

**bad**:
```
def test_login():
    password_hasher = Mock()
    password_hasher.verify.return_value = True
    user_repo = Mock()
    user_repo.find.return_value = Mock(id=1, password_hash="xxx")
    session_manager = Mock()

    service = LoginService(password_hasher, user_repo, session_manager)
    service.login("alice", "password")

    # 呼び出し順の検証だけ
    user_repo.find.assert_called_with("alice")
    password_hasher.verify.assert_called_with("password", "xxx")
    session_manager.create.assert_called()
```

**good**:
```
# 外部依存 (DB) のみ差し替え。他は本物
def test_returns_user_on_success():
    user_repo = InMemoryUserRepo()
    user_repo.save(User(username="alice", password="secret"))
    service = LoginService(user_repo)

    result = service.login("alice", "secret")

    assert result.username == "alice", f"expected alice, got {result.username}"

def test_raises_error_on_invalid_password():
    user_repo = InMemoryUserRepo()
    user_repo.save(User(username="alice", password="secret"))
    service = LoginService(user_repo)

    with pytest.raises(AuthError):
        service.login("alice", "wrong")
```

### 3. 1 テストに詰め込みすぎ

1 つのテスト関数で複数のシナリオを検証しているパターン。最初の assert で失敗すると後続が見えない。

**検知**:
- テスト名に `and` が入っている (`test_login_and_logout`)
- テスト本体で複数の独立したシナリオを続けて実行している
- assertion が 5 個以上あって、それぞれが違う振る舞いを見ている

**bad**:
```
def test_user_creation():
    user = User.create(username="alice")
    assert user.username == "alice"     # 属性設定の検証
    assert user.id is not None          # ID 自動採番の検証
    assert user.created_at is not None  # タイムスタンプの検証
    assert user.is_active is True       # デフォルト有効化の検証
```

**good**:
```
def test_sets_username_from_argument():
    user = User.create(username="alice")
    assert user.username == "alice"

def test_generates_id_automatically():
    user = User.create(username="alice")
    assert user.id is not None

def test_activates_new_user_by_default():
    user = User.create(username="alice")
    assert user.is_active is True
```

### 4. フレームワーク/ライブラリの振る舞いをテストしている

自分のコードではなく、依存ライブラリの仕様を検証しているパターン。ライブラリを信頼していない or 何もテストしていないかのどちらか。

**検知**:
- ORM の `save` → `find` が同じデータを返すことを検証
- HTTP クライアントが 200 を返すと `response.status == 200` になることを検証
- 標準ライブラリの動作を確認するテスト

**対処**: そのテストは削除。自分のコードが**そのライブラリをどう使っているか** (引数の組み立て / 結果の解釈) だけをテストする。

### 5. 実装を先に見て書いているテスト

「実装がどう書かれているか」を先に読んで、その動きを写しているパターン。**ワークフローの Step 1 (仕様を一行で言語化) を先にやることで回避する**。

## 例: 全体の流れ

**要件**: `calculate_shipping_fee(order)` を実装する。

### Step 1: 仕様を一行で

「注文の合計金額から送料を計算するもの。1 万円以上なら無料、それ未満なら 500 円」

### Step 2: シナリオ列挙

- happy: 5000 円の注文 → 500 円
- edge: ちょうど 10000 円 → 0 円 (境界)
- edge: 9999 円 → 500 円 (境界の反対側)
- edge: 0 円 → 500 円 (下限)
- happy: 高額 (100000 円) → 0 円

### Step 3: テストを書く

```
def test_charges_500_yen_when_below_threshold():
    order = Order(total=5000)
    assert calculate_shipping_fee(order) == 500, "expected 500 for order below 10000"

def test_free_when_exactly_at_threshold():
    order = Order(total=10000)
    assert calculate_shipping_fee(order) == 0, "expected free at exactly 10000 (inclusive)"

def test_charges_500_yen_just_below_threshold():
    order = Order(total=9999)
    assert calculate_shipping_fee(order) == 500, "expected 500 just below threshold"

def test_charges_500_yen_for_zero_total():
    order = Order(total=0)
    assert calculate_shipping_fee(order) == 500

def test_free_for_high_value_order():
    order = Order(total=100000)
    assert calculate_shipping_fee(order) == 0
```

### Step 4: self-review

- 仕様だけ見せられたら書けるか → ✅ 「1 万円以上なら無料、未満なら 500 円」から全て導出可
- リファクタ耐性 → ✅ 内部が `if / else` だろうが `dict` lookup だろうがテストは通る
- 失敗時の情報量 → ✅ テスト名から「境界のどちら側で失敗したか」が分かる
- 1 テスト 1 シナリオ → ✅
- モックは外部依存だけか → ✅ そもそもモックなし

## TDD との関係

TDD で進める場合は `tdd-workflow` skill と併用する。ワークフローの Step 1-2 (仕様言語化 → シナリオ列挙) は TDD の Red フェーズと同期する。

このスキルは TDD 以外 (既存コードへのテスト追加 / リファクタ後のテスト更新) にも適用される。
