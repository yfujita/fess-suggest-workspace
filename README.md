# fess-suggest-workspace

[Fess](https://github.com/codelibs/fess) のサジェスト機能を改善するための開発ワークスペース。

Fess 本体と、サジェスト用ライブラリ fess-suggest の 2 つのリポジトリを `modules/` 配下に並べて配置し、調査・設計・実装のドキュメントを `agent_docs/` に蓄積していく構成になっている。
このリポジトリ自体にはアプリケーションのソースコードは含まれない（`modules/` は Git 管理外）。

## ディレクトリ構成

```
fess-suggest-workspace/
├── modules/            # 対象リポジトリ (git 管理外、scripts/clone.sh で取得)
│   ├── fess-suggest/   # Fess のサジェスト用ライブラリ
│   └── fess/           # Fess 本体 (fess-suggest の利用側)
├── agent_docs/         # 調査・設計・作業履歴ドキュメント
│   ├── global/         # タスク横断の共通リファレンス
│   └── tasks/          # タスクごとのドキュメント
├── scripts/
│   └── clone.sh        # modules/ の clone / pull
└── CLAUDE.md           # AI エージェント向けの作業ルール
```

## セットアップ

```bash
./scripts/clone.sh
```

`modules/fess-suggest` と `modules/fess` を GitHub から clone する（すでにある場合は `git pull`）。
実行後、それぞれのコミットハッシュが表示される。

## ドキュメント

### global — 共通リファレンス

タスクをまたいで参照する基礎知識を置く。

- `agent_docs/global/references/legacy/` — 改善前の fess-suggest の調査ドキュメント。
  概要 / アーキテクチャ / サジェスト内容 / Fess 本体との連携 / 課題一覧に分かれており、
  [`README.md`](agent_docs/global/references/legacy/README.md) がインデックスになっている。

記述には次の凡例を用い、根拠は `file_path:line` 形式で示す。

- **[確認]** ソースコードで直接確認できた事実
- **[推測]** 実装から合理的に推測した内容

### tasks — タスクドキュメント

`agent_docs/tasks/[タスク名]/` 配下に、そのタスクの要件定義と作業履歴を残す。

| ファイル | 内容 |
| --- | --- |
| `0000-requirements-definition.md` | タスクの要件定義 |
| `[通し番号]-[作業名].md` | 作業ごとの履歴。既存の最大番号 +1 を付ける |

これまでのタスク（時系列）:

| タスク | 内容 |
| --- | --- |
| `20260622_analyze_suggest` | 既存 fess-suggest の現状調査 |
| `20260622_improvement_proposal` | ゼロベースでの抜本的な改善案の作成 |
| `20260629_improvement_proposal_step2` | 改善案のブラッシュアップ（段階的移行方針へ） |
| `20260706_opensearch_reference` | OpenSearch の技術検証（scripted_upsert / knn、新スキーマ案） |
| `20260706_design_document` | 設計書の作成（API / データモデル / 移行・運用） |
| `20260822_implementation` | 設計にもとづく実装 |

## 作業の進め方

- 作業を行ったら、必ず該当タスク配下に作業履歴ドキュメントを残す。
- 実装中に設計の誤り・不足を見つけた場合は、実装で黙って吸収せず、
  先に設計書を改訂（版追記＋変更理由）し、作業履歴に記録してから実装する。
- AI エージェント向けの詳細なルールは [CLAUDE.md](CLAUDE.md) を参照。
