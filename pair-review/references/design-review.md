# Design Review

設計 / docs PR、または新しい entity / table、独立 lifecycle / state machine、authorization / transaction boundary、cross-service workflow を含む PR で読む。これは内部の調査手順であり、各見出しをそのままユーザーへ見せる台本ではない。実装 PR の failure / witness / origin を置き換えず、その前に設計判断を検証する。

## 調査順

```text
原典
  → 操作フロー
  → invariants
  → entity / state / relationship boundaries
  → alternatives
  → Design Claims
```

Greptile など既存 reviewer の実装欠落コメントから始めない。ユーザーの「なぜこの table が要るのか」「この entity は何を表すのか」「原典はどこか」のような設計判断を問う発言は Priority Claim とし、先に扱う。

## ユーザーへの返し方

原典、操作、境界、代替案は一度内部で通してから、結論をまとめて返す。通常は次を短く伝える。

- 設計を利用者・運用者の言葉で一文にした理解
- 判断に効く懸念。既存指摘と新規発見を区別する
- 推奨する次の確認またはコメント

`Source Map`、`invariant`、`entity boundary`、`Design Claim` などの調査語彙を、説明なしに見出しとして並べない。各段階で同意を求めず、原典の曖昧さによってモデルや結論が変わる場合だけ質問する。詳細表や内部 status は、ユーザーが根拠や手順を求めたときに開示する。

## 1. Source Map

PR 本文だけを仕様の正本にしない。入力が Slack thread なら、PR URL と同時に関連仕様、DesignDoc、スプレッドシート、添付を拾い、Change Map 前に読む。

少なくとも次を分ける。

- source of truth: 現行要件・合意済み仕様
- proposal: この PR が新しく提案する設計
- existing behavior: 現在のコードと運用
- unresolved: 原典同士の不一致、または決まっていないこと

原典間の矛盾は実装欠落より先に Design Claim にする。内部 URL、個人情報、顧客値は公開コメントへ転記しない。

## 2. Operation Flow と invariants

実装語彙へ降りる前に、利用者 / 運用者の流れを復元する。

- 誰が、何を契機に作成するか
- 誰が、どの順番で更新するか
- 何が揃うと次へ進めるか
- いつ完了・中止・再開するか
- 同じ対象で繰り返し起こるか

そこから「常に真であるべき条件」を短く抽出する。画面ラベルやカラム名を invariant の代わりにしない。

## 3. Domain inventory

PR が扱う概念を次に仕分ける。

- actor
- entity
- value / attribute
- lifecycle state
- event
- relationship

スプレッドシートの列や UI label を、そのまま domain state とみなさない。

## 4. Entity boundary

新しい entity が必要かは、実装量ではなく責務と lifecycle で見る。

- 親と別の時点で生成・完了するか
- 親 1 件に対して複数回発生し得るか
- 履歴を独立して残す必要があるか
- 担当、SLA、権限、終端条件を独自に持つか
- 親の属性として置くと「現在」と「過去」が混ざらないか

独立 entity を選んだ場合も、名前が実際の責務を表すかを確認する。将来拡張だけを理由に境界を増やさない。

## 5. State decomposition

1 つの enum に次の軸が混ざっていないか確認する。

- instruction / required action
- progress
- result
- physical state
- case lifecycle
- owner / responsibility

代替モデルを出すとき、既存 entity が既に持つ状態を新 entity に再掲しない。同じ事実を複数の mutable field で表すなら、不整合な組み合わせと SSOT を確認する。導出できる状態は、永続化が本当に必要かを問う。

## 6. Relationships と時間差

同じ lifecycle が複数回起きても、entity 間の対応を後から時刻や並び順で推測せずに済むかを見る。

- どの event / attempt が case を発生させたか
- どの entity が current を指すか
- 関連 entity が後から作られるなら delayed FK が必要か
- nullable の期間と、設定される遷移が明確か
- uniqueness / concurrency が relationship を壊さないか

より純粋なモデルが既存構造の大改修を要する場合は、理想案と今回の現実案を分ける。

## 7. Alternatives

必要なときだけ、少なくとも次を比較する。

- minimal: 現在の要件を最小の境界で満たす
- proposed: PR の案
- domain-pure: 責務と lifecycle を最も素直に表す

比較軸は、現在の複雑性、移行可能性、誤った状態の作りやすさ、履歴と繰り返し、原典との整合。実装が速いことだけで採用案を決めず、将来要件の確度だけで過剰設計もしない。

## Design Review Packet（親への内部返却）

subagent を使う場合は、PR / snapshot、原典候補、ユーザーの Priority Claim、関連 path を渡す。subagent は会話履歴を持たない前提で、必要な context を prompt に含める。

返却は短い packet に固定する。この YAML をユーザーへそのまま表示しない。

```yaml
design_review:
  source_of_truth:
    - locator: ""
      role: "source-of-truth | proposal | existing-behavior"
      finding: ""
  operation_flow: []
  entities:
    - name: ""
      lifecycle: ""
      relationships: []
  invariants: []
  candidate_claims:
    - claim: ""
      status: "supported | falsified | unverified"
      evidence: []
      impact: ""
  alternative_models:
    - name: ""
      tradeoffs: []
  unresolved_questions: []
  recommendation: ""
```

各 issue には evidence locator と impact を付ける。raw transcript や長い探索ログは返さない。subagent は GitHub 投稿、Approve、コード変更をしない。

親は packet を technical truth として採用せず、evidence を確認して Claim Ledger に統合する。`supported` は `confirmed` ではない。ユーザーとの言い直し、優先順位、Decision Gate、Human Gate は親が行う。
