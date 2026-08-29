# Database Review

SQL / query-plan の証拠が必要なときだけ読む。起動時には読まない。
規模の見方の本体は [scale-analysis.md](scale-analysis.md)。

## 実行してよいもの / いけないもの

- 非ローカル SQL（production / staging / ユーザーの手元以外）は Agent が実行しない
- local DB でも、ユーザーが「実行して」と言うまで任意の更新はしない。このスキルでは SELECT 提示が既定
- EXPLAIN / EXPLAIN ANALYZE も Agent 自身では production / non-local に投げない。提案する

## 1 返答 1 本

ユーザーが実行する SELECT を **1 本**出す。結果が来るまで次の SQL を出さない。
試算だけで severity を決めない。実測で N が小さいなら指摘を落とす。大きいなら残す。

## EXPLAIN

query shape / index 利用が Approve 判断を変えそうなときだけ提案する。

1. なぜその query を疑うか（cardinality、lock、seq scan の仮説）を先に書く
2. ユーザー向けに EXPLAIN（必要なら ANALYZE）文を 1 本出す
3. 結果が来るまで次を出さない

## 出し方

- 読み取り専用に見える SELECT / EXPLAIN だけ
- 対象テーブルと、どの cardinality（S, G, K 等）を測るかを添える
- 結果の読み方の仮説を 1 行。断定しない
