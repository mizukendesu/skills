# Scale / Runtime Evidence

SKILL.md の Scale 段階、または collection / cardinality に敏感な経路があるとき読む。起動時には読まない。
SQL をユーザーに渡す段階になったら [database-review.md](database-review.md)。

絶対本数だけでなく、「この PR で何に比例する処理が新しく増えたか」を見る。

## Cardinality vector

単一の N だけで足りないことが多い。必要なら vector を定義する。

例:

```text
R = requests
S = shipping
G = groups
K = SKU kinds
I = items
```

base / head についてコスト関数を書いて比較する。

```text
base:  Q = 4 + G
head:  Q = 5 + G + S
delta: 1 + S
```

N ごと・経路ごとに、定数か比例かを分ける。無駄（空でも走る JOIN、二重取得、重い API の ×N）を切り出す。
**この PR で新規に増えた爆発だけ**切り出す。

## Resource Amplification

DB 本数に限らない。必要に応じて:

- DB round trips
- rows scanned / written / locked
- external API calls
- network payload
- JS iterations
- sorting complexity
- memory
- transaction duration

JS 側の突合・ソート・ネストは O 記法 + vector を入れた実数で。DB と混ぜて「重い」で終わらせない。

出力例:

```markdown
## Resource amplification
- vector: R, S, G, K, I
- base: ...
- head: ...
- delta（この PR の新規増加）: ...
- 高負荷の代入例: ...
- 無駄: ...
```

試算だけで温度を決めない。実測で cardinality が小さいなら指摘を落とす。大きいなら残す。
実測 SQL の出し方は database-review。

## Domain defaults

core には業務固有の N を置かない。対象リポジトリや会話でユーザーが既定 N を置いたらそれを使う。
楽観的に小さい N を仮定しない。
