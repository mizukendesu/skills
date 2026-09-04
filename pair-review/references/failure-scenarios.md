# Failure Scenarios

SKILL.md の Risk Scenario Selection から読む。起動時には読まない。

単なる「起きると困る不具合の全列挙」ではない。

```text
この変更が守るべき invariant
  → high-impact failure scenario
```

網羅性より、Approve 判断を変える可能性が高い scenario を優先する。通常 **3〜5 個**。ユーザーが明示した failure scenario は Priority Claim にする。

コードの好みより先に壊れ方。各 scenario は Claim にして Evidence Loop へ渡す。

## 選び方

1. Change Map から invariant を拾う（何が常に真であるべきか）
2. この PR の変更がどの invariant を危うくするかを hypothetical に置く
3. 実害が大きい順に 3〜5 に絞る
4. 各項目: 発生条件 / 影響 / この PR で起きるか、は Evidence Loop で判定する。ここでは仮説まで

## Reachability before impact

危険に見える usecase / function 本体だけで「実害がある」と報告しない。まず通常操作からその入力・状態へ到達できるかを確認する。

必要に応じて、entry point、候補の絞り込み、UI / API 契約、権限、既存 guard、feature flag、状態遷移を上流から追う。

```text
risky implementation exists
  ≠
normal user flow can reach it
```

到達性が確認できない段階では `confirmed` にせず、hypothesis / `unverified` のまま扱う。

## Async handoff durability

state mutation のあとに queue / job / webhook / external API などへ処理を引き渡す変更では、`partial failure / retry` を任意観点にしない。**各 handoff boundary を明示的に展開して確認する。**

守りたい invariant は次。

```text
durable business state
  と
unfinished downstream work の存在

が恒久的に食い違わない
```

### Producer side

状態を確定してから非同期処理を enqueue / send する場合、少なくとも確認する。

- handoff より前に何が durable になるか
- enqueue / send が失敗したとき、誰が再試行するか
- 元の trigger がもう一度成立するか
- 先行した state mutation により trigger 条件が消えないか
- 再送不能なら、durable intent / outbox / reconciliation / operator recovery のどれが残るか

```text
state mutation succeeded
  +
handoff failed
  +
original trigger is no longer repeatable
  =
recovery gap candidate
```

`waitUntil`、fire-and-forget、ログ出力、例外の握りつぶしを recovery とみなさない。

### Consumer side

1 event / job が複数対象へ side effect を fan-out する場合、少なくとも確認する。

- 一部だけ失敗したとき、失敗が job / step の失敗として上位へ伝播するか
- catch して結果値へ変換したことで retry が止まらないか
- retry の粒度は全体 / failed item のどちらか
- 先に成功した対象を再実行しても idempotent か
- 未完了対象を後から発見できる durable marker / reconciliation があるか
- terminal failure を operator が回復できるか

```text
error was caught
  ≠
failed work is recoverable

retry exists
  ≠
this failure reaches retry
```

producer / consumer の両方がある場合は、それぞれ別 Claim として扱ってよい。1 つの「retry 対応済み」でまとめない。

## Perspective（relevant なものだけ）

全部見ない。この PR に効くものだけ選ぶ。

- data integrity（過剰消費、足りないのに引き当て、別物の同一キー集約）
- concurrency / idempotency
- partial failure / retry
- authorization
- backward compatibility
- stale / old client（サーバー先行で古いアプリが壊れるか）
- feature flag bypass（Flag OFF でも本番に出る経路）
- scale（[scale-analysis.md](scale-analysis.md) へ）
- external side effect duplication
- 前進操作の破壊、既存データの見え方変更

必要ならだけ（旧フロー 8）:

- repository 内オーケストレーションを usecase に書くべきか
- 逐次 UPDATE vs 一括
- Flag 現状値（ユーザーが渡したらその組み合わせで見る）

## 判定の粒度

Evidence Loop に入ったあと:

- `起こる / 起こらない / 狭いエッジ / unverified`
- Approve を止める理由になるか
- origin（introduced / exposed / pre-existing / unknown）

推測と根拠を分ける。到達不能なら confirmed にしない。
