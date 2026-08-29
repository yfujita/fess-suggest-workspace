# 20260629_improvement_proposal_step2

## 要件定義

サジェスト改善提案案をブラッシュアップする。

## ブラッシュアップ対象の改善案

`agent_docs/tasks/20260629_improvement_proposal_step2/docs/improvement-proposal.md`

## ブラッシュアップポイント

### 改善の進め方

段階的改善を行う

#### パッケージ構成

src/main/java/org/codelibs/fess/suggest/
 ├─ api/       ← [NEW!] To-Be の公開IF (SuggestQueryService等)
 ├─ spi/       ← [NEW!] To-Be の拡張点 (SuggestSource等)
 ├─ internal/  ← [NEW!] To-Be の新しい実装クラス群
 │
 ├─ index/     ← (既存) SuggestIndexer など。当面はそのまま
 ├─ request/   ← (既存) SuggestRequest など。当面はそのまま
 └─ Suggester.java ← (既存) 巨大ファサード。当面はそのまま

#### 進め方

まずNEWにTo-Beを実装していく。既存テストを流用する。
たとえば、マージ規則を統一する SuggestItemMergePolicy（MIG-01）を spi パッケージに作ります。
このとき、既存の SuggestItemMergerTest などのテストコードをコピー・修正し、新しい SuggestItemMergePolicy が現行と同じように正しくマージできるかを確認します。

新しい部品ができたら、既存の巨大ファサード（Suggester や SuggestIndexer）のメソッドの中身を書き換え、新しい部品を呼び出す（委譲する） ようにします。

内部の部品がすべて To-Be 構成に置き換わったら、いよいよ fess 本体側の呼び出しを、古い SuggestIndexer から 新しい SuggestIngestService へと切り替えます。
誰も使わなくなった古い index パッケージや Suggester クラスを、ここで初めて安全に削除（または @Deprecated 扱いで放置して次期メジャーで削除）します。

#### 移行における技術的ルール（過渡期の扱い）

- **データの移行（インデックス再構築）**
  スキーマ変更（score廃止等）を含む部品へ委譲を切り替える際は、既存の「二重エイリアス再構築」機構を活用し、新スキーマでインデックスを作り直した上で検索エイリアスを切り替える。
- **非同期基盤・例外の変換（アダプターの責務）**
  新しい部品は `CompletableFuture` や `Result` 型（例外を投げない）で実装する。既存ファサードから委譲する際、ファサード内で「CompletableFuture → 独自 Promise」や「Result のエラー → SuggesterException」への変換を行い、fess本体への影響を遮断する。
- **先行PoC（性能・実現性検証、任意）**
  OpenSearch バージョンは **3.7.0 で確定済み**であり、`scripted_upsert`/`knn`/`fuzzy` 等はいずれも利用可能（バージョン確定目的の PoC は不要）。段階構成（まず multiGet、次に `scripted_upsert`）はバージョンと独立に維持し、Phase 0 を残す場合は `scripted_upsert` の性能・script 複雑度やセマンティックの実現性の**実測**に充てる。

#### badword

badwordは部分マッチしたものは全てbadword扱いにしたい。

#### script_upsert

scripted_upsert は本命だが、最初の性能改善は multiGet でよさそう。prepareGet N回を multiGet 1回にする。
scriptは複雑すぎることになる可能性があるので、ちょっと怖い。
