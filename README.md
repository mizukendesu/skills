# skills

Cursor Agent Skills。クローンしたレポジトリを個人スキルへ symlink して使う。

```bash
ln -sfn path/to/your/skills/pair-review path/to/your/.cursor/skills/pair-review
```

設計 / docs PR の調査を別 context に分離する optional subagent:

```bash
mkdir -p path/to/your/.cursor/agents
ln -sfn path/to/your/skills/agents/pair-design-reviewer.md path/to/your/.cursor/agents/pair-design-reviewer.md
```

subagent は任意。未導入でも `pair-review` 本体が同じ設計レビュー手順を実行する。

## pair-review

他人の PR をユーザーと読む Human-led Code Review Harness。Agent は bounded investigator。GitHub 投稿と Approve はユーザー。

使い方: `/pair-review`。PR 番号、PR URL、または PR を含む Slack スレッドを渡す。
