# Claim Ledger

SKILL.md の Main loop 2 / 4 から読む。起動時には読まない。

既存 GitHub review comment、resolved comment、対応せず close、ユーザーの仮説、Agent の仮説、CI / test failure から生じた疑義は、すべて同じ Claim model で扱う。ただし独立した論点を 1 つの Claim に混ぜない。

## 三層は独立

```text
GitHub thread state  ≠  technical claim state  ≠  human decision state
```

例:

```text
GitHub: resolved
Technical: confirmed
Origin: introduced
Decision: accepted-risk    ← Human だけが付けられる
```

逆も可:

```text
GitHub: unresolved
Technical: falsified
```

`resolved` は technical truth ではない。UI metadata。

- `resolved ≠ fixed`
- `commit exists ≠ fix verified`

## Claim の形

各 Claim は最低限これを持つ。会話内の短い箇条書きでよい。JSON 永続化はしない。

```text
claim:
source:              github-thread | user | agent | ci | test
status:              unverified | confirmed | falsified | fixed-verified
                     | accepted-risk | deferred
github_thread_state: unresolved | resolved | none
evidence_for:
evidence_against:
witness:             なければ空。confirmed にするなら可能な限り入れる
origin:              introduced | exposed | pre-existing | unknown
impact:
approve_blocker:     yes | no | unknown
next_investigation:
remaining_evidence:  判定不能なときに何が足りないか
```

## Claim の粒度

**1 Claim = evidence / status / severity / decision を独立して更新できる 1 つの主張**。

同じコード箇所から複数の懸念が出ても、根拠や判断が別なら分ける。たとえば correctness、performance、query shape、type safety、maintainability / style は、同じ修正箇所でも別 Claim になり得る。

```text
performance regression is confirmed
  ≠
implementation style is wrong
  ≠
proposed optimization is verified
```

1 つの confirmed finding を根拠に、隣接する別論点まで confirmed 扱いしない。
公開コメントでまとめるかは Decision Gate / Human Gate で決める。内部の Claim は先に分離しておく。

## Status を誰が付けられるか

```text
Agent may determine:
- unverified
- confirmed
- falsified
- fixed-verified

Human-only transition:
- accepted-risk

Human decision or explicit external decision:
- deferred
```

Agent は risk を説明する。risk を受容するのは人間。
「発生率低そうなので accepted-risk」と勝手に閉じない。

`unverified` は最後まで残してよい。production data が無い、到達可能性が切れない、などなら:

```text
status: unverified
remaining_evidence: production cardinality
approve_blocker: unknown / depends on N
```

で止める。Stop のために confirmed / falsified へ押し込まない。不確実性の所在を明示することが成果。

## Priority Claim と confirmation bias

ユーザーの仮説は通常の Agent 仮説より優先する Priority Claim。正本にはしない。対応せずクローズ由来より後。

```text
Hypothesis → Try to falsify → Gather supporting evidence → Build witness → Update Claim
```

例: 「二重引当が起きる」なら、先に unique constraint / transaction / lock / idempotency / existing guard / unreachable path を探す。突破可能なら witness を組む。

Agent が見つけた仮説も同じ仕組み。

## 既存コメントの仕分け

解決済みを含めて thread を全部見る。`collect-pr-context.sh` の `review_threads` を使う。resolved を信用して飛ばさない。

2 つのリストに分け、未解決は 3 つ目に短く残す。

```text
修正コミットでクローズ（候補）
  → 一覧。直ったかは 1 行では足りない。fixed-verified の定義で判定する
対応せずクローズ（意図的 / 仕様 / 対応しない / 別PR）
  → 必ず深掘りする。作者の説明を正本にしない
未解決
  → 放置しない。Claim にする
```

### 修正コミットでクローズ（候補）の手がかり

- 返信に commit hash があり、その SHA がこの PR に含まれる
- または、指摘後の commit で該当箇所が変わっている

これは **候補** にすぎない。hash があるだけでは `fixed-verified` にしない。

### 対応せずクローズ の判定（どれかで入れる）

- 返信が「仕様」「意図的」「対応しない」「別PR」「問題ない」だけで、直した commit が無い
- resolved なのに返信も hash も無い
- hash はあるが、その commit が指摘箇所を触っていない

対応せずクローズは Evidence Loop と同じ粒度で深掘りする。

- 発生条件 / 影響 / 今のコードで起きるか
- 判定は `起こる / 起こらない / 狭いエッジ`、または `unverified`
- Approve を止める理由になるか
- 「仕様です」でも、実害が残るなら Claim として残す

## fixed-verified

旧 Skill の「修正コミットでクローズ」を厳しくする。

```text
fixed-verified:
- claim 後に関連コードが変更されている
- current head で元の failure witness が成立しない
- 必要なら対応する test / guard も確認済み
```

作者が commit hash を返信しただけ、関連ファイルが少し変わっただけ、では足りない。
witness がまだ成立するなら technical は `confirmed` のまま、GitHub だけ resolved であり得る。

## Witness

重大な finding を `confirmed` にする場合、可能な限り具体的な witness を要求する。

最低限:

- initial state
- input / operation
- call path
- actual / derived result
- expected result

```text
State:  A
Input:  B
Path:   X → Y → Z
Result: C
Expected: D
```

到達可能性を示せないなら、もっともらしいだけで `confirmed` にしない。`unverified` か、狭いエッジとして impact を落とす。

## Blocker 候補では recovery path も確認する

重大な Claim を Approve blocker / `must:` 候補として提示する前に、通常の利用・運用で抜けられる経路がないか確認する。

見るものの例:

- retry / 再実行
- 別の UI 操作や次の通常操作
- background job / reconciliation
- admin / ops の既存操作
- 自然に状態が収束する後続イベント

```text
failure is reachable
  ≠
user is permanently stuck
```

recovery があれば finding 自体を falsified にする必要はない。頻度・復旧コスト・データ整合性への影響を含めて severity / approve_blocker を更新する。

通常経路で復旧できず、特殊な手作業や直接データ修正しかない場合は、その事実を evidence として blocker 判断に含める。

## Origin

finding を出すとき、可能な限り判定する。必要なら base と head を比較する。

| origin | 意味 |
|---|---|
| introduced | この PR が作った |
| exposed | 元からあったが、この PR で顕在化した |
| pre-existing | この PR と独立に存在 |
| unknown | 判定材料が足りない |

「問題がある」と「この PR が問題を作った」を混同しない。
pre-existing なら、現在の PR を止める理由かどうかを別判断にする。原則として blocker にしないが、今回の経路で実害が拡大するなら ユーザーに聞く。

## Evidence Loop

### Inner Loop

```text
Claim を選ぶ
  → 反証を試みる
  → evidence を集める
  → witness を作る（confirmed にする場合）
  → blocker 候補なら recovery path を確認する
  → origin を判定する
  → status / impact を更新する
  → 不十分なら追加調査
  → technical terminal、または remaining uncertainty が明示されるまで
```

呼び元・先、テストの成功系と拒否系、CI を見る。「列挙して終わり」禁止。
推測と根拠を分ける。

### Outer Loop

自由探索しない。class の順を守り、各 class 内では Approve 影響 / risk が高いものから選ぶ。

```text
Investigation order:

1. dismissed-close claims
2. Human Priority Claims
3. Agent-generated claims

Within each class:
higher approve-impact / risk first
```
