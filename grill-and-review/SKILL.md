---
name: grill-and-review
description: >-
  Human-led pre-implementation review for a plan or design in a repository.
  Investigate facts from docs and code, interview the Human about real decisions,
  keep the working plan aligned with those decisions, then challenge the plan
  against source-of-truth, failure modes, lifecycle, rollout, tests, and scale.
  Use explicitly with /grill-and-review.
disable-model-invocation: true
---
# Grill and Review

実装前の Plan / Design を Human と詰め、最後にその Plan を第三者目線で反証する。
目的は「会話が盛り上がった」ではなく、**実装者が迷わず着手でき、レビュー時に原典へ戻れる Plan** にすること。

これは code review ではない。コードを書かない。GitHub Approve もしない。

## 役割

Human:

- 仕様・運用・トレードオフの最終判断をする
- 未確定事項を決める
- known limitation / accepted risk を受容するか決める

Agent:

- コード、既存テスト、仕様資料から事実を調べる
- source of truth と既存挙動を区別する
- 依存関係のある設計判断を順番に質問する
- 推奨案とトレードオフを出す
- 決まった内容を working plan に反映する
- Plan が固まったら、いったん自分の前提を疑って review する

**事実を Human に聞かない。決定を Agent が勝手にしない。**

## 入力

次のどれでもよい。

- Plan ファイル
- DesignDoc / spec / issue / ticket
- Slack thread など、変更の背景がある会話
- 「この機能を作りたい」という未整理の依頼

既存 Plan があるなら最初に読む。外部資料へのリンクがあるなら、利用可能な tool / connector で取得する。

Plan がまだ無い場合は、会話内に working plan を持ちながら grill し、最後に実装計画へまとめる。
明示的な Plan ファイルが対象なら、Human が決めた内容をそのファイルへ段階的に反映してよい。アプリコードや unrelated な repo file は変更しない。

## 全体フロー

```text
Source / Existing Behavior
        ↓
Shared Understanding
        ↓
Decision Tree Grill
        ↓
Working Plan
        ↓
Adversarial Plan Review
        ↓
Implementation Readiness
```

途中の内部ラベルを、そのまま会話の見出しとして並べなくてよい。Human には平易な言葉で返す。

## 1. まず事実を固める

質問を始める前に、今回の変更について次を分ける。

- **source of truth**: 現行要件、明示された合意、正式な仕様
- **proposal**: 今回の Plan が提案していること
- **existing behavior**: 現在コードが実際にしていること
- **unresolved**: 原典同士の矛盾、または誰かが決める必要があること

PR 本文や Plan だけを正本にしない。
コードで分かることはコードを読む。既存 test で分かることは test を読む。

最初に利用者 / 運用者の流れを短く復元する。

- 誰が何をすると始まるか
- どの順番で何が起きるか
- 成功すると何が変わるか
- 失敗・保留・再実行ではどうなるか
- 今回やらないことは何か

理解が source と矛盾していれば、設計質問へ進む前に解消する。

## 2. Decision Tree を grill する

Plan の未確定事項を、依存関係のある decision tree として扱う。

ある質問の答えが決まらないと次を決められない場合、後段の質問を先に聞かない。
今答えられる decision の集合だけを 1 round として聞く。

1 round は通常 1〜4 問。独立した質問なら同じ round にまとめてよい。
Human に大量の質問を一度に投げない。

各質問は次を含める。

```text
❓ Q1 — <何を決めるか>
<なぜこの判断が必要か。コード / 仕様から分かっている事実も短く添える>

A. ...
B. ...
C. ...

推奨: A
理由: ...
トレードオフ: ...
```

選択肢で表しにくければ自由回答でもよい。

Human の回答で前提が変わったら、その回答に依存する downstream decision を組み直す。
質問への回答を「おそらくこうだろう」で補完しない。

### 質問しないもの

次は Agent が調査する。

- 既存 function / schema / API の挙動
- feature flag の既存パターン
- transaction / retry の現在の実装
- enum や state の定義
- 既存 test が何を保証しているか
- repository convention

情報が見つからない場合だけ `unverified` として所在を示す。

## 3. Working Plan に決定を残す

各 round が終わったら、決まったことを working plan に反映する。
最後にまとめて記憶から書き直さない。

Plan には少なくとも relevant なものを残す。

- purpose / scope / out of scope
- source of truth
- user / operator flow
- trigger / entry point
- domain rules / invariants
- data / state changes
- sync / async boundary
- authorization / transaction boundary
- retry / idempotency / concurrency
- feature flag / rollout / rollback
- observability / operational follow-up
- test cases / acceptance criteria
- PR split / dependency order
- known limitations

全部の Plan に全部の見出しを強制しない。今回の実装判断に必要なものだけを書く。

repo 全体の glossary や ADR は自動では作らない。
用語や長期的 architecture decision を別 artifact に残したい場合は Human が明示したときだけ扱う。

## 4. Plan を一度疑って review する

Decision tree が埋まったら、その Plan を自分が作ったものとして擁護しない。
**別の reviewer が渡された Plan を読むつもりで反証する。**

まず「起きると困ること」を 3〜5 個に絞り、通常経路から到達するか確認する。

relevant な観点だけを見る。

### Source alignment

- Plan が source of truth と一致しているか
- source 同士の差を勝手に吸収していないか
- existing behavior を仕様と誤認していないか

### Flow / state

- 同じ操作を繰り返しても成立するか
- partial success の後に再開できるか
- state transition に抜けや二重遷移がないか
- derived state と persisted state が矛盾しないか

### Async / concurrency

- 判定時点と実行時点で前提が変わらないか
- retry で副作用が二重にならないか
- duplicate event / at-least-once delivery で壊れないか
- TOCTOU / race によって別結果にならないか

### Failure / recovery

- 途中失敗で何だけ残るか
- transaction boundary は適切か
- normal retry / reconciliation / operator action で回復できるか
- rollback / kill switch が本当に効くか

### Authorization / boundary

- UI 非表示だけで server action が通らないか
- external / internal actor の権限境界が plan にあるか
- cross-service / cross-app の責務が曖昧でないか

### Scale / runtime

- この変更で何に比例する処理が増えるか
- collection / query / external call が入力サイズで増幅しないか
- fan-out / serial loop / lock scope が現実的か

明らかに scale-sensitive でなければ深掘りしなくてよい。

### Tests / rollout

- acceptance criteria が重要な failure scenario を押さえているか
- happy path しか plan にない状態になっていないか
- flag OFF / rollback / migration 前後が説明できるか
- deploy 順序に依存するなら順序が plan にあるか

## 5. finding が出たら Plan に戻す

review で問題が出ても、その場で実装へ進まない。

- **fact の不足** → Agent が追加調査
- **decision の不足** → 次の grill round
- **Plan の記述不足** → working plan を修正
- **known limitation** → Human が受容するか決める

Agent は勝手に `accepted risk` にしない。

review 後に Plan を直したら、変更した部分に効く failure scenario だけ再確認する。最初から全探索し直さない。

## 6. Implementation Readiness

最後は結論だけで終わらず、Human が coverage を確認できる形で返す。

```text
結論: Ready | Ready with accepted constraints | Needs decisions | Not ready

確認したこと:
- 今回の source / operation flow で確認したこと
- failure / retry / lifecycle で確認したこと
- code / test / scale で確認したこと

Plan に反映した主な決定:
- ...
- ...

残っていること:
- unresolved / unverified
- 専用 test は無いが構造上成立すると判断した範囲
- Human が明示的に受容した known limitation
```

`Ready` は「絶対にバグがない」ではない。
**実装者が新しい product decision を発明せずに着手でき、残る不確実性が Human に見えている**状態を指す。

## Stop condition

次を満たしたら終わる。

- source と existing behavior の関係を説明できる
- user / operator flow が決まっている
- decision tree の frontier が空
- implementation に必要な boundary / failure / rollout が plan に残っている
- high-impact failure scenario を review 済み
- remaining uncertainty / known limitation が明示されている
- Human と shared understanding に到達している

終わっても自動で実装しない。
Human が「実装して」「次へ」と明示したら、この skill の責務は完了。

## 口癖 → 動作

| Human | 動作 |
|---|---|
| これ grill して | source を読み、未確定 decision の最初の round |
| これで認識あってる？ | source / code と照合して、fact と decision を分離 |
| 原典どこ？ | source of truth を追う。推測と明示仕様を分ける |
| A / B / それで | decision を working plan に反映して次の frontier |
| plan review して | grill 済みなら adversarial review。未決定があれば grill に戻す |
| 実装してよい？ | Implementation Readiness。結論 + 確認したこと + 残り |
| pair-review して | Plan が対象ならこの skill の review phase と同型。PR / 実装済みコードなら pair-review の責務 |

$ARGUMENTS
