# 0010: 引き渡しメモ(Fess 組み込み・確認用)

作成日: 2026-11-16 / 担当: メインエージェント(フェーズ 8 の 1)

## 1. 成果物

- jar: `/Users/yfujita/fuji/n2sm/fess/fess-suggest-workspace/modules/fess-suggest/target/fess-suggest-15.10.0-SNAPSHOT.jar`(217,925 bytes。連結語〔PR #107 の内容〕+ 断片フィルタ + 活用形の除外を含む)。`mvn package` でテスト 960 件・失敗 0。
- コードは `modules/fess-suggest`(独立 git リポジトリ。HEAD `7db7938` に対する**未コミット**の変更)。コミットは指示があるまで行わない。
- 設計書: `agent_tasks/20261116_implement_query_evaluation_3/task_docs/design_fragment_suggest.md`。

## 2. 変更の要約

- 文書経路: 促音長音のみ(`ッ`、`ー` など)、記号のみ(`.`、`/` など)、英数 1 文字、かな 1 文字の語を候補にしない。
- 活用形: 形容詞-自立で活用形が基本形以外の語(`なかっ`、`大き`、`難し`、`なく`)を候補にしない。基本形(`ない`、`いい`、`すごい`)は残る。tokenizer 段(explain)の結果を連結語と共用する。
- 連結語: 両端の促音長音のみのトークンを外す(`ー警視庁編ー` → `警視庁編`)。中間は残す(`ぴー先生`)。
- 検索ログ経路: 促音長音のみ・記号のみの検索語を除外。最小長の規則は入れない(`ai`、`月`、`x` の検索履歴は残る)。
- `suggest_analyzer.json`、fess 本体、`fess_config.properties` は変更なし。アナライザ索引の再作成は不要。

## 3. 設定(System property)と渡し方

suggest 作成プロセスの `jvm.suggest.options`(`fess_config.properties`)に `-D...` を足す。値は生成時に 1 回だけ読むため、変更は次回の suggest 作成から有効。

| プロパティ | 既定 | 内容 |
| --- | --- | --- |
| `fess.suggest.fragment.filter.enabled` | `true` | 断片フィルタ(C1/C2、英数 1 文字、かな 1 文字)、検索ログ経路の C1/C2、連結語の端トリム |
| `fess.suggest.fragment.inflection.enabled` | `true`(**暫定**) | 形容詞-自立の活用形の除外。`filter.enabled` とは独立 |
| `fess.suggest.fragment.latin.short.enabled` | `false` | 英数 2 文字以下も除外(`jp`、`ne`、`ku`。`ai`、`pc`、`tv` なども消える)。`filter.enabled=true` のときだけ効く |
| `fess.suggest.fragment.single.han.enabled` | `false` | 単漢字も除外(`月`、`人`、`米`)。`filter.enabled=true` のときだけ効く |

- `ne`・`ku` は**既定では消えない**(英数 2 文字)。確認するには `latin.short.enabled=true` にする(略語 `ai` なども消えるトレードオフ)。
- `inflection.enabled` の既定 `true` は連結語の `compound.enabled` と同様に**暫定**。評価(下の 5 章)なしに本番の既定として確定しない。

## 4. 停止・ロールバック

`-Dfess.suggest.fragment.filter.enabled=false -Dfess.suggest.fragment.inflection.enabled=false` で従来の動作に戻る(次の suggest 作成で反映。コードの戻しは不要)。tokenizer 段(explain)のリクエストは、`compound.enabled` と `inflection.enabled` の**両方が false のときだけ**止まる。連結語だけを止めても、活用形が有効なら explain は 1 チャンクにつき 1 回残る。

## 5. ユーザーの確認手順(設計書 5.3、7 章)

1. 評価時と同じデータで suggest を再作成し、`/api/v2/suggest-words` と suggest 索引で確認する。比較は同一コーパス・同一の分類スクリプトで行い、できれば取得割合を一時的に 100% にする(`suggest.update.contents.limit.num.percentage`)。
2. `なかっ`、`よかっ`、`大き`、`難し`、`ッ`、`ッッ`、`ー`、`ーー` が候補にならない。
3. 例語(`新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種`、`円安`、`togetter.com`、`神奈川県`)が従来どおり取得でき、読み補完(`にほん`→`日本`)が退行しない。
4. 基本形(`ない`、`いい`、`すごい`)が残る。
5. 基準値との比較(ローカル 100 文書コーパス): C1 と C2 が 0、C3/C4 が 0(名詞用法のある約 12 語を除く)、C5 は 199→174、C6 は 821→777、断片の総数は 11,825→約 11,380。促音長音を含む連結語 16 件のうち 15 件が消えるか短くなる。
6. `fragment.*` の各プロパティを切り替えた再作成で、期待どおりに増減する。
7. 次の項目を合わせて確認する:
   - **性能(設計書 7 章 5・8)**: 連結語のベースライン測定(`compound.enabled=false`)には `inflection.enabled=false` を併記する。explain は通常の analyze の約 10 倍以上のコスト(ローカル実測: 1000 文字で約 23 ms、8000 文字で約 175 ms)。数万文字のチャンクを含む本文で、suggest 作成の総実行時間と**ヒープ使用量**を測る(活用形の判定のため、全チャンクの tokenizer 段の結果をフィールド処理の間保持する。code-reviewer の Suggestion 1)。多言語環境では非日本語チャンクの分も explain が増える。
   - **1 文字英数の個別設定の要否(設計書 7 章 9)**: 既定で消える 1 文字英数 25 語(`x`、`m`、`t`、`e`、`c` など)に有用なものがあれば、1 文字英数だけを残す設定を追加する。

## 6. 注意点・既知の限界

- **`_vanilla`(標準 kuromoji)未検証**: ローカルに analysis-kuromoji の jar が無く、tokenizer 段で `inflectionForm` が取れるか確認できていない。取れない構成では活用形の除外が働かず現状と同じになる(誤って除外はしない)。**除外が効いているかの見分け方**: 文書を処理した後、`getExcludedFragmentCount(INFLECTION_FORM)` が 0 のままなら、活用形が取れていない可能性が高い(デバッグログと `getInflectionUndeterminedChunkCount` で取得不可・例外・品詞なしの件数も見える)。形容詞-自立なのに `inflectionForm` が無いチャンクを数える専用カウンタは無い。
- **`analyzeText` を継承する外部コード**: `parseDocument` は protected の `analyzeText` / `analyzeTextByReading` を呼ばなくなった(チャンク記録つきの内部メソッドを使う)。これらを override している外部コードがあれば、文書の解析に反映されない。ワークスペース内には継承クラスは無い(0002)。
- **検索ログ経路**: 除外はカウンタのみで、デバッグログは出さない(語を出せず、1 語ごとのログは量が多いため)。
- `fragment.filter.enabled=false` でも `inflection.enabled=true` なら活用形は除外される(独立)。
- lang は日本語文書で `ja` 形式で入る(0002)。`ja_JP` のような値が残る場合、最小長の規則(英数・かな・単漢字)は効かない。
- 半角の濁点・半濁点(`ﾞ`、`ﾟ`)は断片フィルタに掛からない。`ﾊﾟ` は `ハﾟ` として残る(既知。実害は小さい)。
- 設計書 3.8 の更新対象(連結語の設計書の停止手順・本番有効化ゲート・「断片は残す」の記述)は、ユーザーの可否待ち(STATUS.md 参照)。
- 評価対象の `ne`・`ku` は、既定の設定では解消しない(上記 3 章)。
