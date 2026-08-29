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
