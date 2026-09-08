# Minimality Review

Correctness / safety を確認したあとに、同じ要求をもっと少ない ownership complexity で満たせないかを見る。
目的はコードゴルフではなく、**不要な state / abstraction / dependency / boundary / duplication を所有しないこと**。

Prior art: [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (MIT)。
Ponytail の「flow を理解してから最小の解を選ぶ」という考え方だけを Human-led review 用に使う。

## Guardrails

この pass は correctness の代わりではない。先に requirement / invariant / reachable failure / recovery を確認する。

短くするために削らないもの:

- explicit product requirement / Human が選んだ tradeoff
- trust-boundary validation / authorization / security
- data loss を防ぐ error handling
- 必要性を確認済みの transaction / retry / idempotency / concurrency control
- 必要性を確認済みの durable handoff / reconciliation / operator recovery
- recovery に必要な rollout / rollback / observability

より小さい案で observable behavior / safety / recovery が変わるなら simplification ではなく新しい decision。通常の Claim / grill に戻す。

**single implementation / caller / configured value は candidate のシグナルであって、削除根拠ではない。** domain / trust / transaction / provider / ownership boundary として意味があるなら残す。

minimality の探索中に reachable failure、invariant violation、security issue を見つけたら complexity finding に閉じ込めない。通常の correctness Claim に昇格して Evidence Loop / adversarial review に戻す。

## Ladder

candidate だけを上から確認する。

1. **Need** — 現在の requirement に必要か。将来用途だけなら足さない。
2. **Reuse** — 同じ ownership point / helper / type / pattern が codebase にないか。
3. **Native** — stdlib / language / browser / framework / database primitive で成立しないか。
4. **Installed dependency** — 既存 dependency で十分なら、新しい dependency / hand-rolled code を増やさない。
5. **Collapse** — abstraction / entity / state / config / layer / boundary を減らしても責務と保証が変わらないか。
6. **Centralize** — 同じ invariant / guard / transformation を正しい ownership point に一度だけ置けないか。
7. **Minimum equivalent** — 同じ behavior / safety / recovery を保つ最小の構造を選ぶ。

「短いコード」より「所有する概念が少ない」を優先する。LOC は副次指標。

## Finding の証拠

`なんとなく重い` では finding にしない。少なくとも次を確認する。

- 何が余分なのか
- caller / implementation / configured value の実数
- 何に置き換えるか
- 置き換えても維持される requirement / invariant / recovery
- introduced / exposed / pre-existing のどれか

主に state、abstraction、dependency、boundary / handoff、config / mode、duplicated invariant の delta を見る。

## Outcomes

- **Lean** — meaningful な candidate がない、または調べても削る根拠がない。
- **Simplify** — 同じ behavior / safety / recovery のまま ownership complexity を減らせる。
- **Tradeoff** — 小さい案はあるが flexibility / operability / migration cost と交換になる。Human の decision に戻す。

Plan を simplify したら、影響した failure scenario / boundary だけ再確認する。最初から全 review をやり直さない。
