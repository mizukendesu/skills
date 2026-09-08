# Minimality Review

Correctness / safety を確認したあとに、同じ要求をもっと少ない複雑性で満たせないかを見る。
目的はコードゴルフではなく、**不要な state / abstraction / dependency / boundary / duplication を所有しないこと**。

Prior art: [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (MIT)。
Ponytail の「まず実際の flow を理解し、その後で最小の解を選ぶ」という考え方を、Human-led review 用に限定して使う。

## この pass の位置づけ

Minimality は correctness の代わりではない。
先に main review で requirement / invariant / reachable failure / recovery を確認し、**必要性が証明されたものを削らない**。

次を満たしてから行う。

- 変更の user / operator flow と主要 invariant を説明できる
- relevant な failure scenario と recovery を確認済み、または remaining uncertainty が明示されている
- trust / authorization / transaction / durability boundary の必要性を判定できる
- Plan review なら、Human が決める product / design decision が概ね確定している

「簡単になる」代わりに observable behavior、safety、recovery、明示要件が変わるなら、それは simplification ではなく新しい design decision。通常の review / grill に戻す。

## Protected complexity

次は短くするために削らない。

- trust boundary の input validation
- authorization / security control
- data loss を防ぐ error handling
- accessibility の基本要件
- 必要性を確認済みの transaction / retry / idempotency / concurrency control
- 必要性を確認済みの durable handoff / reconciliation / operator recovery
- rollout / rollback / observability のうち、明示的な運用要件または recovery に必要なもの
- source of truth にある explicit product requirement
- Human が明示的に選択した tradeoff

これらが過剰に見える場合は、勝手に削らず「そもそもの requirement / boundary が必要か」を別 Claim / decision として扱う。

## Minimality ladder

meaningful な追加ごとに上から止まる。

1. **Need** — その追加は要求を満たすために本当に必要か。speculative な将来用途だけなら足さない。
2. **Reuse** — 同じ責務を持つ既存 helper / type / state / pattern / service が codebase にないか。
3. **Native** — stdlib / language / browser / framework / database の primitive で同じ invariant を守れないか。
4. **Installed dependency** — 既に導入済みの dependency で十分なら、新しい dependency や hand-rolled implementation を増やさない。
5. **Collapse** — 新しい abstraction / entity / state / config / layer / boundary が一つの実装・一つの caller・一つの値のためだけに存在していないか。
6. **Centralize** — 同じ invariant / guard / transformation を複数箇所に複製せず、正しい ownership point に一度だけ置けないか。
7. **Minimum equivalent** — ここまで必要なら、同じ behavior / safety / recovery を保つ最小の構造を選ぶ。

「短いコード」より「所有する概念が少ない」を優先する。1 行に圧縮して理解しづらくなる変更は minimality ではない。

## 何を数えるか

LOC は副次指標。主に次の delta を見る。

- persistent / transient state の数
- abstraction / interface / wrapper / indirection の数
- dependency の数
- sync / async / service boundary と handoff の数
- config / feature flag / mode / branch の数
- ownership が重複する invariant の数
- files / modules の数（責務が明確な分割まで無理に潰さない）
- LOC

例:

```text
Complexity delta:
- 1 abstraction
- 1 config knob
- 1 duplicate invariant
- ~30 LOC
```

LOC が減っても state や boundary が増えるなら「単純化」とは扱わない。

## Finding の証拠

「なんとなく重い」で指摘しない。候補ごとに最低限次を確認する。

- 何が余分なのか
- caller / implementation / configured value は実際にいくつあるか
- codebase / native primitive で何に置き換えられるか
- 置き換えても何の requirement / invariant / recovery が維持されるか
- PR 由来か、既存構造を露出しただけか

pair-review では meaningful な finding を他の concern と混ぜず、独立した Claim として扱う。minimality finding だけを理由に correctness blocker の severity を継承させない。

## Outcomes

- **Lean** — 実質的に削れるものがない。そのまま進める。
- **Simplify** — 同じ behavior / safety / recovery のまま ownership complexity を減らせる。
- **Tradeoff** — より小さい案はあるが、明示的な flexibility / operability / migration cost との交換になる。Human の decision に戻す。

Plan を simplification で変更したら、その変更が触れた failure scenario / boundary だけ再確認する。最初から全 review をやり直さない。
