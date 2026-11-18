# 0005 設計書の作成(フェーズ3)

担当: document-writer。コード・既存ファイルの変更なし。

## 成果物
`agent_tasks/20261116_improve_design_query_evaluation_3/task_docs/design_fragment_suggest.md`(新規、275 行。目安の 200 行より長い。表が多いため)

構成: 1 背景と原因 / 2 方針(検討した他案、除去件数の見積もり)/ 3 変更内容(3.1 対象、3.2 プロパティ、3.3 断片フィルタの擬似コード、3.4 活用形の除外と tokenizer 段の共用、3.5 連結語の端トリム、3.6 検索ログ経路、3.7 データへの影響)/ 4 エッジケース・互換性・移行 / 5 テスト方針 / 6 他の改善点との相互影響とスコープ外 / 7 リスクと要確認事項。経緯語(ユーザー、決めた、回答、フェーズ、承認、作業記録、NNNN など)が残っていないことを grep で確認済み。

## コードと突き合わせて確認した事実
- 0003 の記述と食い違いはなし。行番号は現在の main に直した: `AnalyzerSettings.init` `:155-190`、`updateAnalyzer` `:278`(0002 は `:275`。呼び出し元は main 内に無い)、`parseDocument` `:346-402`(ループ `:371`、isBlank `:373`、readings の index 参照 `:376`、件数不一致の縮退 `:366`)、`trimSymbolTokens` `:664`、`isSymbolToken` `:677`、`isExcludeSearchword` `:860`、`parseSearchWords` `:270`、`attributes` 指定 `AnalyzerSettings:475`、`toAnalyzeToken` の属性コピー `:568`。
- `Character.isLetterOrDigit` を java で実測: `ー` `ッ` `ｰ` は true。`〇`、ローマ数字、`①` は false で、単独トークンなら C2 として除外される(エッジとして明記)。
- Fess の検索ログは `SuggestHelper.indexFromSearchLog` → `indexSearchWord` → `indexFromSearchWord` → `parseSearchWords`。`parseQueryLog` は Fess から使われていないため対象外。
- 既存環境への反映: `SuggestCreator` が毎回 `createNextIndex()`(`:252`)→ `switchIndex()`(`:298`)→ `removeDisableIndices()`(`:301`)。`DefaultContentsParser` は `SuggestIndexer:192` で生成され、設定はコンストラクタで 1 回読む。
- lang なしの `contents_analyzer` も Kuromoji を使う。最小長規則の適用範囲は「lang が null/空/ja」。
- `DefaultContentsParser` は `ContentIndexingOperations` の並列ストリームから共有される。
- 現状の `analyzeText` は全チャンクのトークンを 1 本のリストに連結し、offset はチャンクごとに 0 から始まる。A' の対応付けにはチャンクの記録が要る(設計書 3.4 の実装要件)。
- 見積もりの内訳: 443 = C1 4 + C2 194 + 活用形 176 + 英数1文字 25 + かな1文字 44 − 重複 3。0003 の合計と一致。

## 設計書での小判断
- プロパティ(案): `fess.suggest.fragment.filter.enabled`(既定 true。文書経路の C1/C2/英数1/かな1、検索ログ経路の C1/C2、連結語の端トリムをまとめて切替)、`.inflection.enabled`(既定 true。形容詞-自立の活用形の除外)、`.latin.short.enabled`(既定 false。M2)、`.single.han.enabled`(既定 false。W1)。M2 と W1 は `filter.enabled=true` のときだけ効く。真偽値は `compound.enabled` と同じ `parseBoolean` 方式。
- 連結語が無効のときの扱い: tokenizer 段の explain は `compound.enabled` または `inflection.enabled` が true なら 1 チャンク 1 回呼ぶ(両方 false のときだけ呼ばない)。活用形の除外が連結語の停止スイッチで黙って無効になるのを避けるため。連結語有効なら呼び出し回数は増えない。負荷が問題なら `inflection.enabled=false`。連結語の既存説明(`DefaultContentsParser` の Javadoc、連結語設計書 3.4/4.2 の「false で explain を止める」)は、活用形が有効な間は成り立たないため、実装時に更新する。
- 活用形の判定: 品詞が形容詞-自立 かつ `inflectionForm` が空でない文字列 かつ `基本形` と完全一致しない。属性が取れない場合は除外しない。文語基本形(`なし`)は除外側に入る。
- 検索ログ経路の除外は `isExcludeSearchword` の先頭(アナライザを呼ぶ前)。言語を問わず、最小長規則は入れない。
- C1 の文字集合は {ッ っ ー ｰ ｯ}。英数は ASCII のみ(全角は `mapping_char` で正規化済み)。

## 要判断(メインエージェントの所見): `ne`・`ku`
評価書 #3 の観測のうち `ne`・`ku` は英数 2 文字で、M1(英数 1 文字まで)の既定では消えない。M2(`latin.short.enabled=true`)で消えるが、`ai`(737)・`pc`・`tv` など略語約 23 語も失う(0003 §4)。設計書 5.3・7 章には「M2 有効時にだけ確認する」と書かれている。要件の To-Be は「意味のない断片が候補にならない。または候補となる断片が少なくなる」であり、M1 は後者を満たす。M2 を既定にするかは #7・#8 と合わせて判断する前提で、ユーザーに完了報告時に伝える。

## 未対応事項
- document-reviewer でレビューする(次工程)。
- 設計書の恒久化(`docs/global/` への配置)の要否をユーザーに確認する。
- 設計書 7 章の要確認事項: `_vanilla`、`SuggestTestServer`、fess-suggest 同梱定義(`reloadable_kuromoji_tokenizer`)の tokenizer 段で `inflectionForm` が取れるか。Java クライアント経由の再出力で `inflectionForm` が落ちないか(実機確認は REST の応答のみ)。通常の `analyze` の最終段 offset が tokenizer 段と一致するか(実機確認は explain の最終段のみ)。`attributes` 追加による応答サイズ・処理時間、連結語無効時の負荷(未測定)。`analyzeText` を継承して差し替えている外部コードの有無。
