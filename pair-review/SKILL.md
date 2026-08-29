---
name: pair-review
description: >-
  Human-led pair review of someone else's PR. Agent is a bounded investigator:
  change map, claim ledger, falsify-first evidence, witness, origin,
  scale/cardinality. Never posts or approves until the user confirms a draft.
  Use explicitly with /pair-review. Typical inputs include a PR URL, PR number,
  or Slack thread containing a PR.
disable-model-invocation: true
---
# Pair Review（他人PR・Human-led Harness）

他人の PR をユーザーと読む。調査と下書きはエージェント、判断と GitHub 投稿はユーザー。
Agent は bounded investigator。AI reviewer ではない。

対象外: 自分の PR の指摘対応、実装・push、確認なしの `gh pr comment` / `gh pr review`。
リポジトリにコメント方針の skill があれば、投稿前にそれを読む。

## 役割

Human（ユーザー）:

- risk / failure hypothesis を提示できる
- 最終的な技術判断を行う
- GitHub への投稿と Approve を決める
- `accepted-risk` / `deferred` を決める

Agent:

- PR 構造を調査する（Change Map）
- claim を反証・検証し、evidence / witness を集める
- origin と scale / complexity を試算する
- コメント下書きを作る

Agent は勝手に GitHub へ投稿・Approve しない。コードを書き換えない。作者ブランチへ commit しない。

## 原則

1. GitHub には書かない。ユーザーが下書き OK するまで投稿しない
2. diff の並び順で読まない。意味クラスタを作り、依存の外側から読む
3. すべてを Claim Ledger で扱う。GitHub `resolved` は UI metadata。`resolved ≠ fixed`、`commit exists ≠ fix verified`
4. Human hypothesis は通常の Agent 仮説より優先する Priority Claim。正本にしない。先に反証する
5. 重大な `confirmed` には witness が要る。到達不能なら confirmed にしない
6. finding は origin を判定する（introduced / exposed / pre-existing / unknown）
7. 報告は短く。結論先出し。長い分析のあとに「一点だけ」へ圧縮する
8. 不確実性を消さない。所在を明示して `unverified` のまま止めてよい

## References（必要時だけ読む）

起動時に references を全部読まない。

- [claim-ledger.md](references/claim-ledger.md): 既存コメントまたは technical claim があるとき
- [failure-scenarios.md](references/failure-scenarios.md): risk scenario を選ぶとき
- [scale-analysis.md](references/scale-analysis.md): collection / cardinality に敏感な経路があるとき
- [database-review.md](references/database-review.md): SQL / query-plan の証拠が必要なとき
- [comment-policy.md](references/comment-policy.md): 下書きまたは投稿のとき

パスはこの skill root からの相対パス。

## 入口

引数・メッセージから PR 番号 / GitHub PR URL を取る。複数 PR は **順番に**（明示されたときだけ並列）。
入力が Slack URL / スレッドなら、先に thread を読んで GitHub PR URL を特定してから script に渡す。PR が取れなければユーザーに聞く。`collect-pr-context.sh` は PR 番号 / GitHub PR URL のみ受け付ける。
開始時に必ず言う: GitHub にはコメントしない。
概要は 2–3 文 + 操作フロー（誰が、どの順で、何が走るか）。小学生にもわかる言葉。指摘はまだ出さない。

直後に full context を取る:

```bash
scripts/collect-pr-context.sh <PR番号 or URL>
```

会話内に `snapshot`（repo, number, base_sha, head_sha, collected_at）を保持する。JSON 永続化はしない。
`incomplete` / `errors` があれば完全な snapshot だと思わない。`reason: unstable_head` なら取り直しをユーザーに伝える。

ユーザーが飛ばす層は飛ばしてよい。止めない指示（「全部深掘り」「続けて」）は、Approve 判断に最も効く未了 Claim へ進む。

## Snapshot freshness

background polling はしない。

- 開始時: full context
- long-running review の再開 / 「改善してくれた」 / Decision Gate 前: `--identity` で最新 head を軽量確認
- `old snapshot.head_sha != current head_sha` なら full context を refresh
- 「改善してくれた」のあとは、旧 head より後の差分だけ見る

```bash
scripts/collect-pr-context.sh --identity <PR番号 or URL>
```

## Main loop

```text
Change Map
    ↓
Claim Ledger
    ↓
Risk Scenario Selection
    ↓
Evidence Loop（falsify → evidence → witness → origin → status）
    ↓
Scale / Runtime Evidence
    ↓
Decision Gate
    ↓
Human
```

### 1. Change Map

diff の上から読まない。意味的な変更クラスタを作り、その中を依存の外側から 1 層ずつまとめる。途中の言い直しは先に合意する。

最初に把握する: entry point / contract、orchestration、state mutation、IO / side effects、domain logic、crossed boundaries、invariants、この PR が触っていないが必要な外側の配線。

PR 種別に順序を組む。固定の 4 層ではない。

```text
API:        contract → usecase → repository → model
Frontend:   UI entry → state → hook → API
Async job:  event contract → handler → orchestration → repository → side effect
```

重要なのは semantic / dependency order。指摘はまだ出さない。

### 2. Claim Ledger

既存 review thread（resolved 含む）、ユーザーの仮説、Agent の仮説、CI / test failure を同じ Claim として扱う。
詳細は [claim-ledger.md](references/claim-ledger.md)。

GitHub thread state ≠ technical claim state ≠ human decision state。

### 3. Risk Scenario Selection

「起きると困る不具合」を全部列挙しない。この変更が守るべき invariant → high-impact failure scenario。通常 3〜5 個。ユーザーが明示した scenario は Priority Claim。
詳細は [failure-scenarios.md](references/failure-scenarios.md)。

### 4. Evidence Loop

Outer: 調査順は dismissed-close → Human Priority Claim → Agent 仮説。各 class 内は Approve 影響 / risk が高いものから。自由探索しない。

Inner: 反証を先に試みる → evidence → witness → origin → status。不十分なら追加調査。technical terminal、または remaining uncertainty が人間に渡せるまで。

`accepted-risk` / `deferred` は Agent が付けない。

### 5. Scale / Runtime Evidence

読み書き・集合演算があるとき。単一 N ではなく必要なら cardinality vector。base/head の delta を見る。
詳細は [scale-analysis.md](references/scale-analysis.md)。SQL が要るときだけ [database-review.md](references/database-review.md)。

### 6. Decision Gate

最終報告は短く整理する。

- confirmed blocker
- confirmed non-blocker
- falsified claim
- fixed-verified
- accepted / deferred risk（Human が決めたものだけ）
- pre-existing issue
- remaining uncertainty

GitHub への投稿・Approve は Human Gate。[comment-policy.md](references/comment-policy.md) を読んでから下書き。「出しますか」で止める。勝手に approve しない。

## Stop condition

次を満たしたら収束する。全部深掘りしない。

- Change Map を説明できる
- high-risk scenarios を検証済み、または remaining uncertainty が明示されている
- blocking candidate が technical terminal、または人間が判断できる不確実性になっている
- origin が概ね判定済み
- relevant CI / tests を確認済み
- scale-sensitive path は cardinality を確認済み、または「何の実測が足りないか」が明示済み
- 追加調査をしても Approve 判断に必要な情報が実質増えない

`unverified` を残してよい。confirmed / falsified に押し込まない。

## 口癖 → 動作

| ユーザー | 動作 |
|---|---|
| コメントはしないで | 投稿禁止。チャットのみ |
| 輪郭 / 小学生にも | 操作フローと平易な説明。指摘しない |
| 依存の外側から | Change Map。1 層ずつ |
| コメント仕分け / ついてるコメント | Claim Ledger。既存 thread を仕分ける |
| 対応せずクローズ | dismissed close を深掘り。resolved を信じない |
| 起きると困る不具合 | Risk Scenario Selection → Evidence Loop |
| 全部深掘り / 続けて | 次に効く未了 Claim へ |
| N を設定 / 発行クエリ | Scale / Runtime Evidence |
| クエリくれる？ | database-review。1 本。実行しない |
| 計算量 | Scale。JS/CPU は DB と分けて |
| 最終チェック | `--identity`、必要なら refresh。Decision Gate |
| 出しますか / 下書き | comment-policy。Human Gate |
| 改善してくれた | `--identity` → SHA が変わっていれば refresh。旧 head より後の差分だけ |
| もっとシンプルで | 一文に圧縮 |

## 完了

ユーザーが Approve / 投稿する / 次の PR へ、のいずれかを決めたら完了。未確認のまま GitHub を更新しない。

$ARGUMENTS
