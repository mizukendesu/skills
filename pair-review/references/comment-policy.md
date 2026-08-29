# Comment Policy

下書きまたは GitHub 投稿のときだけ読む。起動時には読まない。
対象リポジトリにコメント方針の skill があれば、投稿前にそれを読む。こちらが投稿ゲート。tone の文言はリポジトリ側に従う。

## Human Gate

- 下書きを出す。「出しますか」で止める
- ユーザーが OK したあとだけ `gh pr comment` / `gh pr review` / inline comment API を使う
- 勝手に `gh pr review --approve` しない。問題なしでも Approve してよいか聞く
- `@cursor` は書かない（Background Agent 召喚）
- コードを書き換えない。作者ブランチへ commit しない

## 下書きのラベル

`must:` / `q:` / `suggestion:` / `imo:` / `nits:` / `praise:` / `FYI:`

相談口調。人ではなくコード。断定より観察。修正案を添える。

Claim Ledger との対応:

- Approve blocker かつ `confirmed` → `must:` 候補。ユーザーが決める
- 狭いエッジ / 非 blocker の `confirmed` → `q:` または `suggestion:`
- `unverified` で判断材料を聞く → `q:`
- `falsified` や `fixed-verified` は原則投稿しない。Decision Gate の整理に残す
- `accepted-risk` / `deferred` は Human が決めたあと、必要なら `FYI:`

## 圧縮

報告が長くなったら、最後は「ロジックは OK。一点だけ …」に圧縮する。
長い analysis をそのまま GitHub に載せない。
