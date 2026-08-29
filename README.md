# skills

Cursor Agent Skills。クローンしたレポジトリを個人スキルへ symlink して使う。

```bash
ln -sfn path/to/your/skills/pair-review path/to/your/.cursor/skills/pair-review
```

## pair-review

他人の PR をユーザーと読む Human-led Code Review Harness。Agent は bounded investigator。GitHub 投稿と Approve はユーザー。

使い方: `/pair-review`。PR 番号、PR URL、または PR を含む Slack スレッドを渡す。
