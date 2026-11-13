# fess-suggest 機能観点の問題点・改善点

- タスク: `20260922_document_for_improve`（要件: [0000-requirements-definition.md](../0000-requirements-definition.md)）
- 作成日: 2026-09-23 / 対象: fess-suggest `15.9.0-SNAPSHOT`（HEAD `f7a8039`）、fess `15.9.0-SNAPSHOT`（HEAD `8a9e1e15c`）
- 前提資料: [0001-current-implementation-overview.md](../0001-current-implementation-overview.md)（特に §7.2 公開 API、§9 所見）、[refactoring_point.md](./refactoring_point.md)、[0007-demo-api-verification.md](../0007-demo-api-verification.md)（実機検証）
- 目的: **外部から観測できる振る舞い・機能仕様**の問題点を根拠つきで列挙する。内部構造・可視性・重複コード・デッドコードは `refactoring_point.md` の担当なので本書では扱わない。同書で **[要判断]** とされた 18 件は機能観点から再評価し、§3 に対応表を置く。

## 凡例と表記

- **[確認]** ソースで直接確かめた事実 / **[推測]** 実装から推し量った内容 / **[提案]** 改善案 / **[要確認]** 未確定で確認が必要な事項
- **実機由来の根拠**は「実機: `q=kennsaku` → 4 件」の形で書く。出典はデモ環境（`https://search.n2sm.co.jp/api/v1/suggest-words` ほか、2026-09-23 実施）。生データと手順は [0007-demo-api-verification.md](../0007-demo-api-verification.md)。
  - **デモ環境のバージョンは不明**で、本書の対象（fess `8a9e1e15c`）と一致する保証はない。実機結果はすべて「デモ環境での観測」であり、コード読解の根拠を置き換えるものではない。
  - **0 件応答は「引けない」と「候補が存在しない」を区別できない。** したがって「引けない」と断定するのは、**同じ候補語を別のクエリで引けることを確認した対照ペア**が取れた場合に限り [確認] とし、対照の無い 0 件は [推測] / [要確認] に留める。
- 根拠パスの短縮表記（`refactoring_point.md` に準拠）
  - 無印: `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下（例 `Suggester.java:179`）
  - `res:`: `modules/fess-suggest/src/main/resources/` 配下
  - `test:`: `modules/fess-suggest/src/test/java/org/codelibs/fess/suggest/` 配下
  - `fess:`: `modules/fess/src/main/java/org/codelibs/fess/` 配下
  - `fess-res:`: `modules/fess/src/main/resources/` 配下 / `fess-web:`: `modules/fess/src/main/webapp/` 配下
- 各項目に付けるラベル

| 軸 | 値 | 意味 |
| --- | --- | --- |
| 優先度 | **P1** / **P2** / **P3** | P1=今回の設計で必ず考慮すべき / P2=考慮が望ましい / P3=将来課題 |
| 分類 | **[欠陥]** / **[制約]** / **[品質]** / **[新機能]** | 不具合・不整合 / 設定・運用の制約 / 候補品質 / 未実装機能 |
| 今回との関係 | **[即修正候補]** / **[構成で備える]** / **[別タスク]** | バグとして今回直す価値がありユーザー判断を仰ぐ / 今回は機能変更しないが後から入れやすい構成にする / 機能変更として別途判断 |
| API 影響 | **[境界内]** / **[境界外]** | 0001 §7.2 の「fess が依存する公開 API」に触れるか |

---

## 0. サマリー

- 本書で挙げた項目は **83 件**。うち P1 が 23 件、P2 が 40 件、P3 が 20 件。分類は [欠陥] 31 / [制約] 19 / [品質] 19 / [新機能] 14。今回との関係は [即修正候補] 20 / [構成で備える] 46 / [別タスク] 17。[境界内] は 29 件。
- 通底する構造的な問題は次の 5 つ。

1. **「設定したとおりに動かない」系の欠陥が優先表示語（elevate word）と NG ワード（bad word）に集中している。** 管理画面から `apply` を渡す全経路が `false` で、NG ワード削除にはそもそも反映手段が無いため即時反映されず（X-04）、読みを指定すると語の表記自体で引けなくなり（X-02）、語数がずれると絶対にヒットせず（X-03）、日次再構築のたびに userBoost が 1.0 に戻る（X-01）。管理者が設定した意図が 4 段階で失われる。**これが機能面で最も影響の大きい塊。**
2. **失敗が外に出ない。** bulk 書き込みの失敗は fess 側で捨てられジョブは成功扱いになり（X-09）、`deleteDocumentWords` は常に成功を返し（X-15）、解析失敗・サイズ超過文書・上限超過は warn かログ無しで消える（Y-16）。しかも取り込みが失敗しても `switchIndex()` が実行され、旧 index は削除されてロールバックできない（X-08）。**「壊れた状態が黙って本番になる」経路が成立している。**
3. **「読み」がサジェストの中核なのに、生成規則が手書きの変換表 1 本に依存し、日本語以外では実質機能しない。** ローマ字は撥音 `ン→nn` のみ・長音 `ー` 未定義・促音は子音重ねなし（Z-01。**語中に撥音を含む語は自然な綴りで一切引けないことを実機で確認**。実機: `kensaku` → 0 件 / `kennsaku` → 4 件）、読み候補は 1 本のみ（Z-09）、`reading_form` を持つアナライザは 48 系統（47 言語 + 無印）のうち無印と `_ja` の 2 つだけ（Y-07）、Kuromoji ユーザー辞書はサジェストに効かない（Y-08）。
4. **既定値と設定インタフェースが噛み合っていない。** 文書走査は「1 リクエスト 1 文書・2 文書ごとに全 index refresh」（X-11, Y-01）で最大 10,000 文書・毎回ランダム抽出（Y-02）。`fess_suggest` の設定 7 キーのうち 6 キーには変更手段が無く（Y-06）、suggest 検索側のチューニング値は fess から 1 つも設定できない（Y-05）。
5. **fess と fess-suggest の間で「同じ概念の二重管理」が繰り返されている。** `suggest_analyzer.json` が同一クラスパス名で両モジュールに存在し乖離（整形 diff 228 行 / 相違行 146 行、X-24）、`_guest_` センチネルと fess の権限表現（X-18）、purge クエリの二重実装（X-10）、`tagFieldName` と `suggest.field.tags`（Y-06）。**統合境界の設計を見直す最大の理由がここにある。**

- 本書の最大の価値は §4「今回のリファクタリング設計への申し送り」にある。上記 1〜5 を後から直せる拡張点を 10 個に整理した。
- 実機（デモ環境）で裏付けた主な項目は Z-01 / Z-04 / W-01 / W-02（対照ペアあり）と、実機で見つけた X-31 / Y-19 / Z-17〜Z-19。検証の経緯と旧版からの訂正は [0007](../0007-demo-api-verification.md) に記録した。

---

## 1. 項目一覧

| ID | 概要 | 優先度 | 分類 | 今回との関係 | API 影響 |
| --- | --- | --- | --- | --- | --- |
| **X. 現行仕様の欠陥・不整合** |||||
| X-01 | elevate word の userBoost が文書/検索ログのマージで 1.0 に戻る | P1 | [欠陥] | [即修正候補] | [境界外] |
| X-02 | elevate word に読みを指定すると語の表記自体で引けなくなる | P1 | [欠陥] | [即修正候補] | [境界外] |
| X-03 | elevate word の読み語数と語の語数がずれると絶対にヒットしない | P1 | [欠陥] | [即修正候補] | [境界外] |
| X-04 | bad/elevate word の管理画面変更が即時反映されない（`apply` を渡す全経路が `false`、NG ワード削除は反映手段なし） | P1 | [欠陥] | [別タスク] | [境界外] |
| X-05 | bad word のワイルドカードが未エスケープ。`*` の登録で全語削除されうる | P1 | [欠陥] | [即修正候補] | [境界外] |
| X-06 | 既定 bad word が `* ? " '` の 4 文字 + 部分一致で、該当語が無言で全滅 | P2 | [欠陥] | [即修正候補] | [境界外] |
| X-07 | bad word の判定・削除が部分一致で、無関係な語まで消える | P2 | [欠陥] | [別タスク] | [境界外] |
| X-08 | 取り込み失敗でも `switchIndex` され、旧 index が削除されロールバック不能 | P1 | [欠陥] | [別タスク] | [境界外] |
| X-09 | bulk 書き込みの失敗が fess 側で捨てられ、ジョブが成功扱いになる | P1 | [欠陥] | [即修正候補] | [境界外] |
| X-10 | purge が「document かつ query」の語を消せず、timestamp 上書きで日数設定も効かない | P1 | [欠陥] | [別タスク] | [境界外] |
| X-11 | `Suggester.refresh()` がクラスタの全 index を refresh する | P1 | [欠陥] | [即修正候補] | [境界内] |
| X-12 | 頻度更新が read-modify-write で楽観ロックが無く、加算が失われる | P1 | [欠陥] | [構成で備える] | [境界内] |
| X-13 | `Promise.getResponse()` の待機が固定 1 分で、searchTimeout が効かない | P2 | [欠陥] | [即修正候補] | [境界内] |
| X-14 | `SuggestCreator` の `latch.await()` にタイムアウトが無く永久ハングしうる | P2 | [欠陥] | [即修正候補] | [境界外] |
| X-15 | `deleteDocumentWords` が elevate word の docFreq も 0 にし、常に成功を返す | P2 | [欠陥] | [即修正候補] | [境界内] |
| X-16 | `deleteElevateWord(apply=true)` が ID 削除でドキュメント全体を消す | P2 | [欠陥] | [即修正候補] | [境界内] |
| X-17 | `userBoost` が 1 以下に設定できず、語の降格ができない | P2 | [欠陥] | [別タスク] | [境界内] |
| X-18 | `_guest_` が fess の権限表現と一致しないセンチネルで、扱いも非対称 | P2 | [欠陥] | [即修正候補] | [境界内] |
| X-19 | `createNextIndex` の alias 付与が別リクエストで、競合対策も無い | P2 | [欠陥] | [別タスク] | [境界内] |
| X-20 | `removeDisableIndices` が全 index を取得し名前の前方一致で削除する | P2 | [欠陥] | [別タスク] | [境界内] |
| X-21 | 検索 alias と更新 alias の使い分けが機能間で不一致 | P2 | [欠陥] | [構成で備える] | [境界内] |
| X-22 | `_id` の 445 文字切り詰めで別語が衝突し、表示語と読みが食い違う | P2 | [欠陥] | [構成で備える] | [境界外] |
| X-23 | 長い検索語が `reading_i` を無制限に生成し mapping を汚染する | P2 | [欠陥] | [構成で備える] | [境界内] |
| X-24 | `suggest_analyzer.json` が両モジュールに同名で存在し乖離（整形 diff 228 行） | P2 | [欠陥] | [構成で備える] | [境界外] |
| X-25 | `restoreElevateWord` が設定 index へ再保存し `@timestamp` を書き換える | P3 | [欠陥] | [即修正候補] | [境界外] |
| X-26 | 設定取得が null 要素・未ソートを返し、欠損データで NPE になる | P3 | [欠陥] | [即修正候補] | [境界外] |
| X-27 | `suggest.field.contents` の複数指定が elevate word の fields を壊す | P3 | [欠陥] | [即修正候補] | [境界外] |
| X-28 | 人気語キャッシュのキー衝突と `cache.expire` の単位不一致 | P3 | [欠陥] | [即修正候補] | [境界外] |
| X-29 | 管理画面の語数 3 個が加算的に整合せず、elevate word が文書語に数えられる | P3 | [欠陥] | [即修正候補] | [境界外] |
| X-30 | UI が in-flight 中の入力を捨て、label も送らない | P3 | [欠陥] | [即修正候補] | [境界外] |
| X-31 | `q` 欠落・空文字が全語マッチになり、`record_count` が 10000 を返す | P3 | [欠陥] | [即修正候補] | [境界外] |
| **Y. 機能の制約・運用性** |||||
| Y-01 | 文書走査が「1 リクエスト 1 文書 / 2 文書ごと refresh / `_source` 全取得」 | P1 | [制約] | [構成で備える] | [境界内] |
| Y-02 | 文書由来の語は最大 10,000 文書・50% から。毎回ランダムに入れ替わる | P1 | [制約] | [構成で備える] | [境界内] |
| Y-03 | 認証ユーザーの検索は学習されない（`suggest.search.log.permissions`） | P1 | [制約] | [構成で備える] | [境界外] |
| Y-04 | `languages` が suggest のフィルタに使われず `lang` が候補を絞らない | P1 | [制約] | [構成で備える] | [境界内] |
| Y-05 | suggest 検索側のチューニング値が fess から 1 つも設定できない | P1 | [制約] | [構成で備える] | [境界内] |
| Y-06 | `fess_suggest` の設定 7 キーのうち 6 キーに変更手段が無い | P2 | [制約] | [構成で備える] | [境界内] |
| Y-07 | 読み変換が実質日本語専用。未指定言語は日本語アナライザにフォールバック | P2 | [制約] | [構成で備える] | [境界外] |
| Y-08 | Kuromoji ユーザー辞書がサジェストに効かない。AWS/Cloud はファイル辞書全無効 | P1 | [制約] | [即修正候補] | [境界外] |
| Y-09 | アナライザ定義を運用中に変更する手段が無い | P2 | [制約] | [構成で備える] | [境界外] |
| Y-10 | suggest 1 回あたり「語数 × 言語数 × 3 回」の同期 `_analyze`。キャッシュ無し | P2 | [制約] | [構成で備える] | [境界外] |
| Y-11 | 検索ログ 1 件ごとに設定読み込み 6 回 | P2 | [制約] | [構成で備える] | [境界内] |
| Y-12 | shards=1 / replicas=0 が JAR 内 JSON に固定 | P2 | [制約] | [構成で備える] | [境界外] |
| Y-13 | 日次フル再構築のみ。クロールとの依存関係も無い。子 JVM は `-Xmx256m` | P2 | [制約] | [別タスク] | [境界外] |
| Y-14 | サジェスト index 群がバックアップ対象外 | P2 | [制約] | [別タスク] | [境界外] |
| Y-15 | 管理画面は語数 3 個と一括削除 3 種のみ。再構築の手動キックも無い | P2 | [制約] | [別タスク] | [境界内] |
| Y-16 | warn 止まりの失敗が運用者に届かない。suggest 固有メトリクスも無い | P2 | [制約] | [別タスク] | [境界外] |
| Y-17 | `scrollTimeout`（PIT keepAlive）だけ設定手段が無く、他も fess 全体と共用 | P3 | [制約] | [構成で備える] | [境界内] |
| Y-18 | `suggest.*` の区切り文字が改行とカンマで不統一 | P3 | [制約] | [構成で備える] | [境界外] |
| Y-19 | `fn` / `label` の誤指定が無言で 0 件になり、タイポと「候補なし」が区別できない | P3 | [制約] | [構成で備える] | [境界内] |
| **Z. サジェスト品質** |||||
| Z-01 | ローマ字変換が撥音・長音・促音を標準的な表記で作らない | P1 | [品質] | [構成で備える] | [境界外] |
| Z-02 | 文書からは 1 トークン = 1 語のみ。複数語候補の供給源が検索ログだけ | P1 | [品質] | [構成で備える] | [境界外] |
| Z-03 | 時間減衰が無く `@timestamp` はスコアに使われない | P1 | [品質] | [構成で備える] | [境界外] |
| Z-04 | prefix ブーストと並べ替えが生クエリ比較で、かな種別（ひらがな/カタカナ）で並び順が変わる | P1 | [品質] | [構成で備える] | [境界外] |
| Z-05 | スコアが 4 要素の積で、freq 片方が 0 の語が構造的に不利。BM25 は破棄 | P2 | [品質] | [構成で備える] | [境界外] |
| Z-06 | `docFreq` が文書頻度ではなくトークン出現回数（tf）。idf 相当が無い | P2 | [品質] | [構成で備える] | [境界外] |
| Z-07 | 事前計算の `score` フィールドが書かれるだけで検索に使われない | P2 | [品質] | [構成で備える] | [境界外] |
| Z-08 | 表記ゆれ正規化の範囲が狭く、かな/カナ・異体字・長音が別語になる | P2 | [品質] | [構成で備える] | [境界外] |
| Z-09 | 読みが 1 本しか生成されず、多音字・固有名詞の誤読をリカバーできない | P2 | [品質] | [構成で備える] | [境界外] |
| Z-10 | `AnalyzerConverter` が 2 つの `_analyze` 結果を添字で対応付け、検証が無い | P2 | [品質] | [構成で備える] | [境界外] |
| Z-11 | 人気語が窓内で頻度を完全無視し、fess 既定の固定シードで毎回同じ結果 | P2 | [品質] | [構成で備える] | [境界内] |
| Z-12 | 重複除去が「空白除去後の完全一致」だけで、`size*2` 固定倍率 | P2 | [品質] | [構成で備える] | [境界外] |
| Z-13 | 最低頻度しきい値が無く、1 回しか出現しない語もサジェストされる | P2 | [品質] | [構成で備える] | [境界内] |
| Z-14 | `matchWordFirst` が取得済み上位 size 件の中だけで並べ替える | P3 | [品質] | [構成で備える] | [境界外] |
| Z-15 | インデックス側とクエリ側で `field` 引数が非対称（クエリ側は常に `""`） | P3 | [品質] | [構成で備える] | [境界外] |
| Z-16 | 解析対象の分割が 1000 文字単位で、境界をまたぐ語が分断される | P3 | [品質] | [構成で備える] | [境界外] |
| Z-17 | 記号だけの語・コード片が候補になっている（実機で確認） | P1 | [品質] | [構成で備える] | [境界外] |
| Z-18 | `fn`（フィールド）の語彙が経路ごとに食い違い、`fn=title` はほぼ機能しない | P2 | [品質] | [構成で備える] | [境界外] |
| Z-19 | デモ環境で `sear*` が一切引けない（原因未特定。bad word 部分一致の疑い） | P2 | [品質] | [構成で備える] | [境界外] |
| **W. 未実装の機能候補** |||||
| W-01 | 誤字補正（fuzzy / did-you-mean）が無い | P1 | [新機能] | [構成で備える] | [境界内] |
| W-02 | 中間一致（infix）補完が無い | P1 | [新機能] | [構成で備える] | [境界内] |
| W-03 | 同義語展開がサジェストに効かない | P2 | [新機能] | [構成で備える] | [境界外] |
| W-04 | サジェスト候補の選択（採用率 / CTR）を学習しない | P2 | [新機能] | [別タスク] | [境界外] |
| W-05 | ゼロ入力時のサジェストが無く、人気語がドロップダウンに統合されていない | P2 | [新機能] | [構成で備える] | [境界外] |
| W-06 | 一致部分のハイライトが無い | P2 | [新機能] | [構成で備える] | [境界内] |
| W-07 | サジェスト語の一覧・検索・個別操作の手段が無い | P2 | [新機能] | [別タスク] | [境界内] |
| W-08 | フィールド別（title / content）の重み付けが無い | P3 | [新機能] | [構成で備える] | [境界外] |
| W-09 | パーソナライズ・ユーザー個別履歴が無い | P3 | [新機能] | [別タスク] | [境界内] |
| W-10 | A/B テスト・品質評価の仕組みが無い | P3 | [新機能] | [別タスク] | [境界外] |
| W-11 | カテゴリ別の候補提示・文書候補の直接提示が無い | P3 | [新機能] | [別タスク] | [境界内] |
| W-12 | NG 語の指定が部分一致のみ。完全一致・正規表現・ラベル別が選べない | P3 | [新機能] | [構成で備える] | [境界内] |
| W-13 | サジェスト API のパラメータ・レスポンスが限定的 | P3 | [新機能] | [構成で備える] | [境界外] |
| W-14 | UI 側の未実装（inline autocomplete、Esc、IME 確定、クライアントキャッシュ） | P3 | [新機能] | [別タスク] | [境界外] |

---

## 2. 項目詳細

### X. 現行仕様の欠陥・不整合

#### X-01 elevate word の userBoost が再構築で 1.0 に戻る — P1 [欠陥] [即修正候補] [境界外]
- [確認] `toUpdatedSource` は freq を加算するのに、`userBoost` は**新しい item の値で無条件上書き**する（`entity/SuggestItemSerializer.java:181`。`score` も `:182` で再計算）。
- [確認] 文書・検索ログ由来の item は `userBoost` に `-1` を渡し（`index/contents/DefaultContentsParser.java:107, 144, 202`）、コンストラクタの `if (userBoost > 1)` で **1 に丸められる**（`entity/SuggestItem.java:131-135`）。
- [確認] 再構築の順序は `storeAllElevateWords(true)` → `indexFromDocuments` → `storeSearchLog`（`fess:exec/SuggestCreator.java:255-296`）。elevate word が先に書かれ、後から文書語で上書きされる。
- **ユーザーから見て**: 文書中にも出現する語を優先表示語に登録すると、日次再構築のたびにブーストが消える。管理画面の設定値（既定 100.0、`fess:app/web/admin/elevateword/CreateForm.java:77`）は残るのに効果が無い。
- [提案] マージ規則を「上書きするフィールド」の方針オブジェクトに切り出し、userBoost は `max()` か「USER kind を持つ側を優先」にする（§4-6）。

#### X-02 elevate word に読みを指定すると語の表記自体で引けなくなる — P1 [欠陥] [即修正候補] [境界外]
- [確認] `ElevateWord.toSuggestItem()` は readings をそのまま `reading_i` にし、**語そのものを読みに含めない**（`entity/ElevateWord.java:143-149`）。対照的に文書由来の語は `l.add(word)` で表層形を読みに足している（`index/contents/DefaultContentsParser.java:194`）。
- [確認] fess 側は読み欄が空なら語を分割、入力済みなら読みだけを使う**排他**（`fess:helper/SuggestHelper.java:466-471`）。
- [確認] `WordManagementOperations.addElevateWord` は readings に `normalizer.normalize` だけを適用し、**`ReadingConverter` を通さない**（`index/operations/WordManagementOperations.java:101-113`）。
- **ユーザーから見て**: 「優先語=東京タワー / 読み=とうきょうたわー」と登録すると `reading_0=["とうきょうたわー"]` のみになり、「東京」「東京タ」と打っても出ない。逆に読み欄を空にすると `reading_0=["東京タワー"]` になり、かな・ローマ字では出ない。**どちらか一方しか動かない。**
- [確認] `test:SuggesterTest.java:414-457` は「読み=語」のケースだけを検証しており、読み指定ケースは未カバー。

#### X-03 elevate word の読み語数と語の語数がずれると絶対にヒットしない — P1 [欠陥] [即修正候補] [境界外]
- [確認] `readings[i]` は「i 番目の語の読み」という位置付きデータ（`entity/ElevateWord.java:144-146`）。クエリ側も i 番目の語を `reading_i` にだけ当てる（`request/suggest/SuggestQueryBuilder.java:86-114`）。
- [確認] fess は読み欄を空白分割するだけで、語の語数と照合しない（`fess:helper/SuggestHelper.java:466-471`）。`text` は `String.join(" ", ...)` で 1 要素（`entity/SuggestItem.java:116`）。
- **ユーザーから見て**: 「優先語=tokyo tower（2 語）/ 読み=とうきょうたわー（1 語）」→ `reading_1` が無いので 2 語入力では**絶対にヒットしない**。逆に「優先語=OpenSearch（1 語）/ 読み=オープン サーチ（2 語）」→ `reading_1` が生まれ、人気語クエリの `mustNot exists(reading_1)`（`request/popularwords/PopularWordsRequest.java:214`）から永久に除外される。

#### X-04 bad/elevate word の管理画面変更が即時反映されない — P1 [欠陥] [別タスク] [境界外]
- [確認] fess から bad / elevate word を操作する経路は **19 箇所**。うち `apply` を引数に取る **17 箇所すべてが `false`** を渡す。
  - bad word（6 箇所）: `fess:app/web/admin/badword/AdminBadwordAction.java:321, 348, 402`、`fess:app/web/api/admin/badword/ApiAdminBadwordAction.java:132, 154, 210`
  - elevate word（11 箇所）: `fess:app/web/admin/elevateword/AdminElevatewordAction.java:350, 379-380, 409, 434-435`、`fess:app/web/api/admin/elevateword/ApiAdminElevatewordAction.java:153, 177-178, 206, 236`
- [確認] 残る 2 箇所（`fess:app/web/admin/badword/AdminBadwordAction.java:376`、`fess:app/web/api/admin/badword/ApiAdminBadwordAction.java:181`）は **NG ワードの削除**で、`apply` 引数を持たない。`SuggestHelper.deleteBadWord(String)`（`fess:helper/SuggestHelper.java:530-533`）→ `SuggestIndexer.deleteBadWord(String)`（`index/SuggestIndexer.java:406-408`）→ `WordManagementOperations.deleteBadWord(String)`（`index/operations/WordManagementOperations.java:91-93`）は `settings.badword().delete(...)` だけで、**index 側へ反映する手段がそもそも存在しない**（`addBadWord` / `addElevateWord` / `deleteElevateWord` にはある `apply` 分岐が無い）。
- [確認] `apply=true` を渡すのは `fess:exec/SuggestCreator.java:255, 258` のみ。反映は cron `0 12 * * *` の `Suggest Indexer` ジョブ（`fess-res:fess_indices/fess_config.scheduled_job/scheduled_job.bulk`）。
- [確認] `apply=false` のとき `WordManagementOperations` は設定 index への保存だけを行う（`index/operations/WordManagementOperations.java:77-84`（bad word 追加）、`:103-115`（elevate word 追加）、`:125-132`（elevate word 削除））。
- **ユーザーから見て**: 「NG ワードを登録したのに候補に出続ける」「優先語を登録したのに出ない」「優先語を削除したのに出続ける」。症状は逆だが原因は同じ（最大 24 時間弱の遅延）。**ただし「NG ワードを削除したのに候補が復活しない」だけは原因が別で、即時反映 API が無く再構築を待つしかない。** UI には成功メッセージだけが出る。
- [提案] 「設定更新」と「インデックス反映」を別操作にして、後者を管理画面から独立に呼べるようにする（§4-9）。ただし即時反映は X-05 / X-07 のリスクを顕在化させるので、先に bad word のマッチ規則を直す必要がある。

#### X-05 bad word のワイルドカードが未エスケープ — P1 [欠陥] [即修正候補] [境界外]
- [確認] `apply=true` の削除は `wildcardQuery(FieldNames.TEXT, "*" + normalized + "*")`（`index/operations/WordManagementOperations.java:81`）。**エスケープしていない。**
- [確認] `SuggestUtil.escapeWildcardQuery`（`util/SuggestUtil.java:394`）は存在するが、参照元は `test:util/SuggestUtilTest.java` だけで main から呼ばれていない。
- [確認] 入力バリデーションは「空でない・空白を含まない」だけ（`settings/BadWordSettings.java:125-133`）。fess 側も `@Pattern(regexp = "[^\\s]+")` で `*` を許容する（`fess:app/web/admin/badword/CreateForm.java:47-48`）。
- **ユーザーから見て**: NG ワードに `*` を登録すると、次回の再構築で `wildcardQuery(text, "***")` となり **suggest index の全語が削除される**。`?` でも 1 文字語が全滅する。
- [推測] 管理者が意図的に `*` を入れることは稀だが、CSV アップロード（`fess:app/service/BadWordService.java` の `importCsv`）で混入する余地がある。

#### X-06 既定 bad word が 4 文字で、該当語が無言で全滅 — P2 [欠陥] [即修正候補] [境界外]
- [確認] `res:suggest_settings/default-badwords.txt` の内容は `*` `?` `"` `'` の **4 行だけ**。`get(true)` が常にこれを連結する（`settings/BadWordSettings.java:68-81`）。`SuggestIndexer` は常に `get(true)` を使う（`index/SuggestIndexer.java:181`）。
- [確認] 判定は `text.contains(badWord)` の部分一致（`entity/SuggestItem.java:455-461`）、適用は `index/operations/IndexingOperations.java:78`。
- **ユーザーから見て**: `don't` `it's` `children's` `l'hôtel` などアポストロフィ・引用符を含む語が**一切サジェストされない**。`contents_analyzer_en` は `standard` tokenizer なのでアポストロフィは語内に残る（`res:suggest_indices/suggest_analyzer.json`）。理由はどこにも表示されない。
- [確認] 既定語は normalize されない（`BadWordSettings.java:138-156`）ので、大文字を含む既定語を追加しても一致しなくなる。

#### X-07 bad word の判定・削除が部分一致 — P2 [欠陥] [別タスク] [境界外]
- [確認] 登録時フィルタ（`entity/SuggestItem.java:455-461`）と削除（`WordManagementOperations.java:81`）の両方が部分一致。
- **ユーザーから見て**: 「電車」を NG にすると「電車事故」「満員電車」も消える。keyword フィールドへの先頭ワイルドカードなので実行コストも高い。
- [確認] 完全一致・前方一致・正規表現を選ぶ手段は無い（W-12）。`fess_config.bad_word` の `targetRole` / `targetLabel` は mapping と entity にあるが、フォームにも `storeAllBadWords` にも現れない dead field（`fess-res:fess_indices/fess_config.bad_word/bad_word.json:6, 9`、`fess:opensearch/config/exentity/BadWord.java:45-46`、`fess:helper/SuggestHelper.java:501-512`）。

#### X-08 取り込み失敗でも switchIndex され、ロールバック不能 — P1 [欠陥] [別タスク] [境界外]
- [確認] `SuggestCreator.create()` は `exitCode.set(1)` した後も**無条件に** `switchIndex()` と `removeDisableIndices()` を実行する（`fess:exec/SuggestCreator.java:264-273`, `:285-294`, `:297-301`）。
- [確認] `switchIndex()` は検索 alias を新 index に張り替え（`Suggester.java:282-334`）、`removeDisableIndices()` は alias を持たない `fess.suggest*` を**全削除**する（`Suggester.java:339-360`）。直前世代を残す仕組みは無い。
- [確認] 切替を戻す API も無い（`Suggester` の public メソッドに存在しない）。
- **ユーザーから見て**: 再構築が途中で失敗すると、中途半端な新 index が公開され、直前の正常な index は削除される。ジョブログには FAIL が出る（`fess:job/SuggestJob.java:231-243` → `fess:app/job/ScriptExecutorJob.java:132-133`）が、**index はもう戻せない**。翌日の再実行を待つしかない。

#### X-09 bulk 書き込みの失敗が捨てられ、ジョブが成功扱いになる — P1 [欠陥] [即修正候補] [境界外]
- [確認] ライブラリ側は bulk の部分失敗を errors に積んで resolve する（`index/writer/SuggestIndexWriter.java:71-74` → `index/operations/ContentIndexingOperations.java:342, 352-353`）。
- [確認] **fess 側の成功コールバックが `response.getErrors()` を一切見ない**（`fess:helper/SuggestHelper.java:294-297` の `.then(response -> { refresh(); success.accept(true); }).error(...)`）。
- [確認] `SuggestCreator.create()` が `exitCode=1` を立てるのは error コールバック・`InterruptedException`・`storeSearchLog` の例外だけ（`fess:exec/SuggestCreator.java:271, 281, 293`）。
- **ユーザーから見て**: bulk が全件失敗しても exit 0、ジョブログは OK、suggest index は空のまま alias が切り替わる（X-08 と組み合わせると旧 index も消える）。気付けるのは「サジェストが出ない」という報告か、管理画面の語数 0 だけ。

#### X-10 purge が一部の語を永久に消せず、日数設定も効かない — P1 [欠陥] [別タスク] [境界外]
- [確認] fess の purge は 2 本あり、それぞれ kinds を厳密に分ける。`purgeDocumentSuggest` は `kinds=document AND NOT query AND NOT user`（`fess:helper/SuggestHelper.java:305-315`）、`purgeSearchlogSuggest` は `NOT document AND kinds=query AND NOT user`（`:322-332`）。**両方の kinds を持つ語はどちらにも当たらない。**
- [確認] `@timestamp` は更新のたびに現在時刻で上書きされる（`entity/SuggestItemSerializer.java:183`、値は `entity/SuggestItem.java:138` の `ZonedDateTime.now()`）。
- [確認] ライブラリ側 `deleteOldWords` は `@timestamp:[* TO t] NOT kinds:user`（`index/operations/DeletionOperations.java:204-213`）で意味が違い、fess からは呼ばれていない（`modules/fess/src/main` を grep して 0 件）。
- [確認] purge は `create()` が 0 のときだけ実行される（`fess:exec/SuggestCreator.java:236-240`）。
- **ユーザーから見て**: 「文書にも出たし検索もされた語」は `purge.suggest.searchlog.day` を過ぎても消えず、index が単調に増える。クロール対象から消えたページの語も出続ける。取り込みが 1 件でも失敗すると purge 自体がスキップされる。

#### X-11 `Suggester.refresh()` がクラスタ全 index を refresh する — P1 [欠陥] [即修正候補] [境界内]
- [確認] `client.admin().indices().prepareRefresh().execute()` に**index 引数が無い**（`Suggester.java:179`）。OpenSearch の仕様上これは全 index が対象。
- [確認] fess の `SuggestHelper.refresh()`（定義は `fess:helper/SuggestHelper.java:538`）の呼び出しは **12 箇所**。検索ログ反映の末尾（`:258`）、文書取り込みの成功コールバック（`:295`）、一括削除 3 種（`:372, 387, 402`）、bad/elevate word 系 7 箇所（`:423`（`storeAllElevateWords`）、`:440`（`deleteAllElevateWord`）、`:451`（`deleteElevateWord`）、`:486`（`addElevateWord`）、`:511`（`storeAllBadWords`）、`:522`（`addBadWord`）、`:532`（`deleteBadWord`））。`Log Aggregator` ジョブは cron `* * * * *`（毎分）。
- [確認] 優先語を 1 件更新する経路（`fess:app/web/admin/elevateword/AdminElevatewordAction.java:379-380` = `deleteAllElevateWord(false)` + `storeAllElevateWords(false)`）では、登録語数 N に対して **N + 3 回**の全 index refresh が走る。内訳: `deleteAllElevateWord` の `:440` が 1 回、`storeAllElevateWords` が内部で再度 `deleteAllElevateWord` を呼ぶため `:440` がもう 1 回、語ごとに `addElevateWord` の `:486` が N 回、末尾の `:423` が 1 回。
- [確認] 対照的に bad word の一括保存（`storeAllBadWords`）は語ごとに `suggester.indexer().addBadWord(...)` を直接呼ぶため（`fess:helper/SuggestHelper.java:507-510`）refresh は末尾の `:511` の **1 回だけ**。同じ「一括保存」で refresh 回数が桁違いという非対称がある。
- **ユーザーから見て**: 優先語を 1 件更新するだけで `fess.search` などの無関係な index まで N + 3 回 refresh され、検索クラスタ全体が重くなる。`res:suggest_indices/suggest.json` の `refresh_interval: 10s` も無意味化する。
- [提案] `prepareRefresh(index)` にする。純粋な修正で、外部から観測できる差は「他 index が refresh されなくなる」ことだけ。

#### X-12 頻度更新が read-modify-write で楽観ロックが無い — P1 [欠陥] [構成で備える] [境界内]
- [確認] `SuggestIndexWriter.write` は 1 件ずつ GET → マージ → `op_type=INDEX` で書く。`if_seq_no` / `if_primary_term` / version の指定は無い（`index/writer/SuggestIndexWriter.java:53-67`）。
- [確認] 並行経路は実在する。リアルタイム反映（`fess:helper/SearchLogHelper.java:485-488` → `fess:helper/SuggestHelper.java:251`）は web プロセス、再構築は別 JVM（`fess:job/SuggestJob.java:203`）で、両者が同じ更新 alias を叩く（`Suggester.java:407-410`）。
- [確認] `toUpdatedSource` は全フィールドを作り直すので、失われるのは freq だけでなく kinds・readings・fields のマージ結果も含む。
- **ユーザーから見て**: queryFreq が取りこぼされ、人気語のしきい値（既定 10）到達が遅れ、順位が不安定になる。

#### X-13 `getResponse()` の待機が固定 1 分 — P2 [欠陥] [即修正候補] [境界内]
- [確認] `Deferred.Promise.getResponse()` は `getResponse(1, TimeUnit.MINUTES)` に委譲する（`concurrent/Deferred.java:211-213`）。
- [確認] `SuggestRequest.processRequest` は `builder.execute(ActionListener)` で投げるだけでタイムアウトを渡していない（`request/suggest/SuggestRequest.java:376-390`）。呼び出し側も `builder.execute().getResponse()`（`fess:api/v2/handlers/SuggestWordsHandler.java:104`）。
- **ユーザーから見て**: OpenSearch が詰まるとサジェスト API が最大 60 秒ブロックし、`index.search.timeout` も suggest の searchTimeout も効かない。オートコンプリートがハングして見え、web スレッドを占有する。

#### X-14 `latch.await()` にタイムアウトが無く永久ハングしうる — P2 [欠陥] [即修正候補] [境界外]
- [確認] `fess:exec/SuggestCreator.java:276` の `latch.await()` に**タイムアウトが無い**。`latch.countDown()` は success / error コールバックの中（`:268, :272`）。
- [確認] `Deferred` の `resolve` / `reject` はコールバックの例外を `catch (final Exception ignore) {}` で捨てる（`concurrent/Deferred.java:91-93, :119`。refactoring_point F-03 と同一）。
- [確認] success コールバックは `refresh()` を呼ぶ（`fess:helper/SuggestHelper.java:295-296`）。
- [推測] `refresh()`（X-11 のとおりクラスタ全 index 対象）が例外を投げると `success.accept(true)` に到達せず latch が下がらないため、`SuggestCreator` プロセスがログ無しで永久にハングする。ジョブが「実行中」のまま張り付く。

#### X-15 `deleteDocumentWords` が elevate word を巻き込み、常に成功を返す — P2 [欠陥] [即修正候補] [境界内]
- [確認] `deleteWordsByKind` は第 1 段で「docFreq>=1 かつ kinds に query/user を含まない」を削除した後、第 2 段で **`rangeQuery(freqField).gte(1)` の全件**（kinds 条件なし）を読み直して docFreq=0・DOCUMENT kind 除去で書き戻す（`index/operations/DeletionOperations.java:162-195`）。
- [確認] elevate word は `docFreq=1` で登録される（`entity/ElevateWord.java:146`）ので第 2 段に含まれ、docFreq と `score` が 0 になる。
- [確認] `deleteWordsByKind` と `deleteOldWords` は**常に `new SuggestDeleteResponse(null, ...)`** を返す（`:194`, `:212`）。fess は `hasError()` だけで成功判定する（`fess:helper/SuggestHelper.java:380-397`）。一方で内部の失敗は `SuggestIndexException` として throw される（`:173-175, :186-190`）。
- **ユーザーから見て**: 管理画面の「文書の語を削除」で優先語の docFreq が 0 になる。失敗時の UI は「常に成功」か「500」の二択で、正しく判別できない。

#### X-16 `deleteElevateWord(apply=true)` がドキュメント全体を消す — P2 [欠陥] [即修正候補] [境界内]
- [確認] `_id = Base64(正規化語)` を指定した **delete**（`index/operations/WordManagementOperations.java:125-132`）。kinds から USER を外す実装ではない。
- **ユーザーから見て**: その語が文書語・クエリ語としても蓄積されていた場合、docFreq / queryFreq / readings ごと消える。「優先語をやめる」が「その語をサジェストから完全に消す」になり、次の再構築まで復活しない。

#### X-17 `userBoost` が 1 以下に設定できない — P2 [欠陥] [別タスク] [境界内]
- [確認] `if (userBoost > 1) { this.userBoost = userBoost; } else { this.userBoost = 1; }`（`entity/SuggestItem.java:131-135`）。
- [確認] 管理フォームの boost は `@Required` と `@ValidateTypeFailure` だけで下限検証が無い（`fess:app/web/admin/elevateword/CreateForm.java:61-63`）。
- **ユーザーから見て**: 「boost 0.5 で目立たなくする」ができない。0 や負値を入れてもエラーにならず 1 として扱われ、保存値と実効値が食い違う。bad word による完全削除しか選べない。

#### X-18 `_guest_` が fess の権限表現と一致せず、扱いも非対称 — P2 [欠陥] [即修正候補] [境界内]
- [確認] `SuggestConstants.DEFAULT_ROLE = "_guest_"`（`constants/SuggestConstants.java:40`）は roles 未指定時に付く内部センチネル（`entity/SuggestItem.java:120-126`）。
- [確認] `suggest()` は**常に**追加（`request/suggest/SuggestRequest.java:351-357`）、`popularWords()` は roles が空のときだけ使う（`request/popularwords/PopularWordsRequest.java:219-223`）。
- [確認] fess が渡すロールは `PermissionHelper.encode` 済みの値（`fess:helper/PermissionHelper.java:86-111`、`fess:mylasta/direction/FessProp.java:1445-1456` の `getSearchGuestRoleList`）で、`_guest_` とは決して一致しない。
- **ユーザーから見て**: ロール情報なしで登録された語（permissions 未指定の elevate word、`role` フィールドが無い文書、ライブラリ直利用）は `suggest()` では**権限に関係なく全員に見える**が、`popularWords()` では roles を渡した時点で見えなくなる。センチネルと fess の権限表現が二重管理になっている。

#### X-19 `createNextIndex` の alias 付与が別リクエストで、競合対策も無い — P2 [欠陥] [別タスク] [境界内]
- [確認] `createNextIndex` は「作成（alias なし）」→「health 待ち」→「alias 付与」を別リクエストで行う（`Suggester.java:247-253, :260, :262-267`）。対して `createIndexIfNothing` は `addAlias` を作成リクエストに含めていて原子的（`Suggester.java:213-219`）。
- [確認] `createIndexIfNothing` には `SuggestUtil.isResourceAlreadyExistsException` による競合対策が無い（`Suggester.java:224-229`）。settings 系（`settings/AnalyzerSettings.java:141-153`、`settings/ArraySettings.java:332-340`、`settings/SuggestSettings.java:216-224`）には #100 で入っている。index 名にミリ秒が入るので（`Suggester.java:463-465`）、同時起動では**別名の index が 2 つ**でき、両方に両 alias が付く。
- [推測] alias が 2 index を指すと `switchIndex()` が「Unexpected number of ... indices」で恒久的に失敗し（`Suggester.java:286-305`）、更新 alias 経由の書き込みも失敗する。alias 未付与の窓で他プロセスの `removeDisableIndices()` が走れば作成直後の index が削除される。
- refactoring_point D-03 と同じ根。

#### X-20 `removeDisableIndices` が全 index 取得 + 前方一致で削除する — P2 [欠陥] [別タスク] [境界内]
- [確認] `prepareGetIndex().addIndices("*")` で**クラスタの全 index**を取得し（`Suggester.java:344-346`）、`indexName.startsWith(index)` かつ alias 無しなら削除する（`:485-487`）。
- [確認] fess 既定では衝突しない。suggest 実体は `fess.suggest.*`、文書 alias は `fess.search` / `fess.update`（`fess-res:fess_config.properties:621-625`）、設定系は `fess_suggest*`（アンダースコア）。
- **ユーザーから見て**: クラスタを他用途と共有し `fess.suggest` で始まる index があると削除される。全 index のメタデータ取得コストもかかる。

#### X-21 検索 alias と更新 alias の使い分けが機能間で不一致 — P2 [欠陥] [構成で備える] [境界内]
- [確認] 参照系（語数）は検索 alias（`Suggester.java:444-453`）、更新系（`indexer()` 全般）は更新 alias（`:407-410`）、fess の purge は `suggester.getIndex()` = 検索 alias（`fess:helper/SuggestHelper.java:314, 331`）。
- **ユーザーから見て**: 再構築中（`createNextIndex` 済み・`switchIndex` 前）は、管理画面の語数が旧 index、`deleteAllWords` / `deleteDocumentWords` が新 index に作用する。「全件削除」しても表示件数が減らない。

#### X-22 `_id` の 445 文字切り詰めで別語が衝突する — P2 [欠陥] [構成で備える] [境界外]
- [確認] `createSuggestTextId` は Base64 が 445 文字を超えると単純に切り詰める（`util/SuggestUtil.java:77, 93-99`）。UTF-8 で約 333 バイト（日本語で約 111 文字）が閾値。
- [確認] 衝突しても `SuggestItemMerger.merge` の id 一致チェックを通る（`entity/SuggestItemMerger.java:60-62`）。`text` は最後に書いた語で上書きされ、`readings` はマージされる。
- **ユーザーから見て**: 表示テキストと読みが食い違う語ができ、無関係な語の頻度が足し込まれる。
- [推測] 文書由来トークンは `content_length_filter max:30` を通るので該当しない。長い検索語（`indexFromSearchWord`）だけが対象。

#### X-23 長い検索語が `reading_i` を無制限に生成する — P2 [欠陥] [構成で備える] [境界内]
- [確認] `indexFromSearchWord` は語数に上限を設けず空白分割する（`index/operations/ContentIndexingOperations.java:402-412`）。
- [確認] `reading_i` は dynamic_templates で keyword 化される（`res:suggest_indices/suggest/mappings-default.json:2-12`）。`res:suggest_indices/suggest.json` は `index.mapping.total_fields.limit` を引き上げていない（OpenSearch 既定 1000）。
- **ユーザーから見て**: 検索ボックスに長文を貼り付けると mapping が恒久的に汚染される。その語自体は全語 AND なので実質引けない。極端な場合はフィールド数上限に達して以降の書き込みが失敗する。

#### X-24 `suggest_analyzer.json` が両モジュールに同名で存在し乖離している — P2 [欠陥] [構成で備える] [境界外]
- [確認] 同一クラスパス名 `suggest_indices/suggest_analyzer.json` が **2 か所**にある。`res:suggest_indices/suggest_analyzer.json`（analyzer 241 個）と `fess-res:suggest_indices/suggest_analyzer.json`（analyzer 240 個）。両者を `json.dumps(indent=2, sort_keys=True)` で正規化して `diff` を取ると **出力 228 行 / 実際に相違する行 146 行**（以降の「228 行」はこの diff 出力行数を指す）。定義単位では **analyzer 14 個・filter 24 個が相違**し、tokenizer は共通名が 1 つも無い。
  - tokenizer: `kuromoji_neologd_normal` / `pattern_split` vs `fess_japanese_normal` / `fess_korean_normal`（**完全に別**）
  - filter: `reloadable_kuromoji_readingform` / `reloadable_kuromoji_part_of_speech` vs `fess_japanese_readingform` / `fess_japanese_part_of_speech`
  - `limit_token_count_filter`: `10000` vs `2147483647`、`stemmer_en_filter`: `possessive_english` vs `english`
  - 各言語の `*_keywords`: 固定サンプル語 vs `keywords_path: ${fess.dictionary.path}<lang>/protwords.txt`（例: `arabic_keywords` は lib 側 `["مرحباا"]` に対し fess 側 `keywords_path: ${fess.dictionary.path}ar/protwords.txt`）。**ただし全言語ではない**。`english_keywords` `bulgarian_keywords` `finnish_keywords` は両モジュールともインラインのサンプル語で同一
  - `title_contents_analyzer`（analyzer）、`pattern_split`（tokenizer）、`zero_width_spaces`（char_filter）は fess-suggest 側にのみ存在
  - `reading_analyzer_ko` / `reading_term_analyzer_ko` / `contents_analyzer_ko` / `contents_reading_analyzer_ko` は fess 側だけが `fess_korean_normal` を使い、fess-suggest 側は `standard`（Y-07 の内訳が 2 ファイルで違う原因）
- [確認] 読み込みは `getClassLoader().getResourceAsStream(...)`（`settings/AnalyzerSettings.java:315-327`）。web も batch も `WEB-INF/classes` が `WEB-INF/lib/*.jar` より前（`fess:job/SuggestJob.java:112-134`）なので **fess 側が勝つ**。[推測] これはクラスパス順への依存で、保証も文書化もされていない。
- [確認] `search_engine.type` 別の差し替え（`AnalyzerSettings.java:333-341`）の `_aws` / `_cloud` は fess 側にしか無い。既定値 `default`（`fess-res:fess_config.properties:14`）に対応する `_default/` は存在せずフォールバックする。
- **ユーザーから見て**: fess-suggest の単体テストは**本番と別のアナライザ構成**を検証している。ライブラリを fess 以外から使うとサンプル語の入った構成になる。2 つのファイルを手で同期し続ける必要がある。

#### X-25 `restoreElevateWord` が設定 index へ再保存する — P3 [欠陥] [即修正候補] [境界外]
- [確認] `restoreElevateWord` は `addElevateWord(..., true)` を再利用するため、設定 index への update + refresh が語ごとに再実行される（`index/operations/WordManagementOperations.java:140-157` → `:103-115` → `settings/ArraySettings.java:252-269`）。
- [確認] 設定エントリの `_id` は正規化語から作られる（`settings/ElevateWordSettings.java:154-155`）ので、重複エントリは増え**ない**。実害は `@timestamp` の書き換えと、語数 × (update + refresh) の I/O だけ。

#### X-26 設定取得が null 要素・未ソートを返す — P3 [欠陥] [即修正候補] [境界外]
- [確認] `ArraySettings.getFromArrayIndex` のコンパレータは `@timestamp` の null チェックまでするのに、比較は `o1.toString().compareTo(o2.toString())`（Map 全体の文字列）で**タイムスタンプ順になっていない**（`settings/ArraySettings.java:214-238`）。`supportedFields` の順序が保証されない。
- [確認] `ArraySettings.get()` は値が null の要素を null のまま返す（`settings/ArraySettings.java:125-136`）。`ElevateWordSettings.get()` も必須項目欠損時に配列要素を null のまま返す（`settings/ElevateWordSettings.java:114-131`）。
- [推測] 前者は `text.contains(null)` で NPE、後者は `restoreElevateWord` のループ（`WordManagementOperations.java:150-151`）で NPE になり、再構築が落ちる。欠損データ（手編集・旧フォーマット）が前提。

#### X-27 `suggest.field.contents` の複数指定が elevate word の fields を壊す — P3 [欠陥] [即修正候補] [境界外]
- [確認] 同じ設定値を 2 通りに解釈している。`split(..., ",")` で `contentFieldNameSet` に入れる一方、`contentFieldList` は**可変長引数版** `stream(String...)` を使うためカンマ分割されない（`fess:helper/SuggestHelper.java:120-124`）。
- [確認] `contentFieldList` は `addElevateWord` で `ElevateWord` の `fields` にそのまま渡る（`fess:helper/SuggestHelper.java:482-484`）。
- [推測] `suggest.field.contents=_default,content` にすると `"_default,content"` という存在しないフィールド名が 1 個付き、`fn` フィルタ（`request/suggest/SuggestRequest.java:359-361`）に一致せず elevate word が出なくなる。既定値 `_default` 単体では顕在化しない。

#### X-28 人気語キャッシュのキー衝突と単位の不一致 — P3 [欠陥] [即修正候補] [境界外]
- [確認] `getCacheKey` は各カテゴリ内で `sorted().reduce((l, r) -> l + r)` と**区切り無しで連結**する（`fess:helper/PopularWordHelper.java:151-160`）。tags が `["ab","c"]` と `["a","bc"]` で同一キーになる。
- [確認] `suggest.popular.word.cache.expire=60` のコメントは `(seconds)`（`fess-res:fess_config.properties:1518-1519`）だが、実装は `TimeUnit.MINUTES`（`fess:helper/PopularWordHelper.java:77`）。
- [確認] ただしキャッシュは `SuggestHelper.refresh()` ごとに全破棄される（`fess:helper/SuggestHelper.java:538-543`）。検索ログが毎分流れる環境では事実上キャッシュが効かず、`cache.expire` はほぼ意味を持たない。

#### X-29 管理画面の語数が加算的に整合しない — P3 [欠陥] [即修正候補] [境界外]
- [確認] `getDocumentWordsNum` は `docFreq >= 1`（`Suggester.java:432-434`）なので、`docFreq=1` で登録される elevate word（`entity/ElevateWord.java:146`）も文書語として数える。document と query の両方を持つ語は両方に数えられるため `totalWordsNum ≠ documentWordsNum + queryWordsNum`。
- [確認] `getNum` は `setTrackTotalHits(true)` なので 10,000 件の打ち切りは起きない（`Suggester.java:444-452`）。代わりに画面表示ごとに全件カウントが 3 回走る（`fess:app/web/admin/suggest/AdminSuggestAction.java:56-58`）。

#### X-30 UI が in-flight 中の入力を捨て、label も送らない — P3 [欠陥] [即修正候補] [境界外]
- [確認] `!suggestingSts` ガードにより、リクエスト送信中の入力は debounce タイマーを張らずに捨てられる（`fess-web:js/suggestor.js:463-474`）。`$.ajax` の戻り値を保持していないので abort も後着レスポンスの破棄も無い（`:196-220`）。
- [確認] ajax の data は `q` / `fn` / `num` / `lang` のみで **`label` を送らない**（`:196-208`）。サーバ側は `label` 対応済み（`fess:api/v2/handlers/SuggestWordsHandler.java:74, 88-90`）。`SUGGESTOR_CONFIG` にも label が無く、同型の定義が 4 ファイルに重複する（`fess-web:js/search.js:49-71`、`index.js` / `advance.js` / `help.js`）。
- **ユーザーから見て**: 速く打つと候補が古いまま止まる。ラベルで絞り込んでいても候補は絞られない。

#### X-31 `q` 欠落・空文字が全語マッチになる — P3 [欠陥] [即修正候補] [境界外]
- [確認] v2 ハンドラは `q` が null のとき `setQuery` を呼ばない（`fess:api/v2/handlers/SuggestWordsHandler.java:68, 77-79`）。`SuggestRequest.query` の初期値は `""`（`request/suggest/SuggestRequest.java:89`）なので、**`q` 欠落は `q=`（空文字）と同じ「全語マッチ」になり、400 にならない。** レスポンスの `q` は `""` で返る（`:116`）。
- [確認] `SuggestRequest` は `setTrackTotalHits` を指定しない（指定しているのは `Suggester.java:449` と `index/contents/document/ESSourceReader.java:341` だけ）。実機: `q=`（空文字）→ HTTP 200 / `record_count 10000`。[推測] この 10000 は OpenSearch 既定の track_total_hits 上限値。
- **ユーザーから見て**: 必須パラメータを忘れても 400 が返らず、意味のない全語マッチが返る。`record_count` を総件数として表示する利用側は打ち切り値を見る（Z-12 と同根）。
- 実機で見えた `q` 欠落時の HTTP 500 や `num` 無検証は、デモ環境（旧バージョン）の v1 API の挙動なので HEAD の根拠にしない（HEAD には v1 API が無く、`num` の検証も `fess:api/v2/handlers/SuggestWordsHandler.java:142-155` に入っている。詳細は [0007](../0007-demo-api-verification.md)）。

### Y. 機能の制約・運用性

#### Y-01 文書走査の既定が極端に保守的 — P1 [制約] [構成で備える] [境界内]
- [確認] `suggest.source.reader.scroll.size=1`（`fess-res:fess_config.properties:1515`）が `ESSourceReader.scrollSize`（既定も 1、`index/contents/document/ESSourceReader.java:103`）になり、PIT search の `setSize` になる（`:289`）。→ **1 リクエスト 1 文書。**
- [確認] `suggest.update.doc.per.request=2`（`:1507`）ごとに `prepareRefresh(index)`（`index/operations/ContentIndexingOperations.java:345`）。→ **2 文書ごとに refresh。**
- [確認] `setFetchSource` を指定していないので毎回 `_source` 全体を転送する（`ESSourceReader.java:288-296`）。`limitOfDocumentSize` 超過文書は**取得後に**破棄する（`:250-261`、ログ無し）。
- [推測] 10,000 文書で 10,000 回の検索 + 5,000 回の refresh。再構築が非常に遅い。

#### Y-02 文書由来の語は最大 10,000 文書から、毎回ランダムに入れ替わる — P1 [制約] [構成で備える] [境界内]
- [確認] 打ち切りは `docCount > getLimitDocNum(totalDocNum, limitPercentage, limitNumber)`（`ESSourceReader.java:229-233`）で、`min(total × percentage/100, limitNumber)`（`:324-330`）。fess 既定は 50% と 10000（`fess-res:fess_config.properties:1509-1511`）。
- [確認] 走査順は `random_score`（seed に現在時刻）+ clickCount 降順（`fess:helper/SuggestHelper.java:280-289`）。
- [確認] `totalDocNum` はコンストラクタで `getTotal()` を呼んで確定する（`ESSourceReader.java:134-138`）が、fess は `new ESSourceReader(...)` の**後**に `setQuery(...)` する（`fess:helper/SuggestHelper.java:272-290`）。母数が実クエリのヒット数とずれる。
- [確認] `docCount.getAndAdd(queue.size())`（`:276`）はサイズフィルタで捨てた分を数えない。
- **ユーザーから見て**: 100 万文書のサイトでもサジェストは 1% しか見ていない。しかも毎回違う 1 万件なので「昨日出ていた候補が今日出ない」。

#### Y-03 認証ユーザーの検索は学習されない — P1 [制約] [構成で備える] [境界外]
- [確認] `suggest.search.log.permissions={user}guest,{role}guest`（`fess-res:fess_config.properties:1521`）に対し、判定は `allMatch`（`fess:mylasta/direction/FessProp.java:1425-1438`）。
- [確認] 検索ログの roles は `RoleQueryHelper.build()` の結果（`fess:helper/SearchLogHelper.java:181, 213`）。ログイン時は本人の権限のみで、ゲストロールは含まれない（`fess:helper/RoleQueryHelper.java:181-195, 228-233`。権限が空になった場合だけフォールバックする）。
- [確認] 取り込み判定は `fess:helper/SuggestHelper.java:250`。バッチ再投入も同じ関数を通る（`:173-194` → `indexFromSearchLog`）。
- **ユーザーから見て**: 全ユーザーがログインする社内 Fess では queryFreq が一切増えず、**検索ログ由来の候補（Z-02 のとおり複数語候補の唯一の供給源）と人気語がほぼ生成されない。** 既定値としてはプライバシー配慮と読めるが、機能が実質死ぬ環境がある。
- 複数語サジェストが出ない主因も本項目（Z-02 参照）。Y-01 / Y-02（文書側の供給制約）と並ぶ最優先の判断事項として §5 の問い 2 に置く。

#### Y-04 `languages` が suggest のフィルタに使われない — P1 [制約] [構成で備える] [境界内]
- [確認] `SuggestRequest.processRequest` のフィルタは tags / roles / fields / kinds のみ（`request/suggest/SuggestRequest.java:346-365`）。LANGUAGES が無い。
- [確認] `addLang` で渡した言語は normalizer / readingConverter の引数にしか使われない（`:223-225`、`request/suggest/SuggestQueryBuilder.java:82, 93, 99`）。
- [確認] 対照的に popularWords はフィルタしている（`request/popularwords/PopularWordsRequest.java:227-229`）。API と UI は lang を送っている（`fess:api/v2/handlers/SuggestWordsHandler.java:72, 85-87`、`fess-web:js/suggestor.js:205`）。
- **ユーザーから見て**: `lang=ja` を指定しても英語文書由来の語が混ざる。同じ `lang` 指定で suggest と人気語の挙動が違う。
- 実機: `q=fe` の 165 件にドイツ語・フランス語の語（`fehler`, `fenêtre`, `fermer` など）が大量に混在する。ただし `lang` 指定の効果そのものは対照が取れず未検証（Z-19）で、「フィルタに使われない」根拠はコード読解のみ [要確認]。
- [確認] **注意**: elevate word は `languages` が空（`entity/ElevateWord.java:148` が null を渡す）なので、単純に `must` フィルタを足すと elevate word が全滅する。

#### Y-05 suggest 検索側のチューニング値が fess から設定できない — P1 [制約] [構成で備える] [境界内]
- [確認] `SuggestRequestBuilder` には setter があるが、`setPrefixMatchWeight` / `setMatchWordFirst` / `setSkipDuplicateWords` / `setSuggestDetail` を `modules/fess/src/main` で grep して **0 件**。
- [確認] 既定値は `prefixMatchWeight=2.0f` / `matchWordFirst=true` / `skipDuplicateWords=true` / `size=10` / `suggestDetail=true`（`request/suggest/SuggestRequest.java:91-113`）に固定。
- [確認] `fess_config.properties` の `suggest.*` は人気語系と索引生成系だけで（`:1479-1523`）、suggest 検索用のキーは 1 件も無い。
- **ユーザーから見て**: サジェスト結果の質を運用で調整する手段がまったく無い。

#### Y-06 `fess_suggest` の設定 7 キーのうち 6 キーに変更手段が無い — P2 [制約] [構成で備える] [境界内]
- [確認] fess 側から `SuggestSettings.DefaultKeys.*` に触るのは **`SUPPORTED_FIELDS` だけ**（`modules/fess/src/main/java` を grep して `fess:helper/SuggestHelper.java:147, 150` の 2 件）。
- [確認] 変更手段が無いキー: `index`、`tagFieldName`（既定 `"label,virtual_host"`）、`roleFieldName`、`langFieldName`、`parallel`、`maxContentLength`（`settings/SuggestSettings.java:510-518, 548-565`、`settings/AnalyzerSettings.java:374`）。`parallel` は `ContentIndexingOperations` の `stream.parallel()` を制御する（`index/SuggestIndexer.java:185`）。
- [確認] `maxContentLength` は `defaultSettings()` にも入らないので、設定ドキュメント上は常に未設定（既定 50000 固定）。
- [確認] `initialize()` は設定ドキュメントが**不在のときだけ** `set(defaultSettings)` する（`settings/SuggestSettings.java:191-246`）。`SuggestHelper.java:135` が渡す `search_engine.type` も後から変えても反映されない。
- [確認] `tagFieldName` に `virtual_host` が含まれるのに fess の `suggest.field.tags=label` には無い、という二重管理の不整合がある。
- **ユーザーから見て**: 「タグ/ロール/言語フィールド名を変えたい」「並列処理で再構築を速くしたい」は、管理画面もプロパティも無く OpenSearch を直接叩くしかない。しかもその値は再作成時の再現性が無い。

#### Y-07 読み変換が実質日本語専用 — P2 [制約] [構成で備える] [境界外]
- [確認] `SUPPORTED_LANGUAGES` は 47 言語（`settings/AnalyzerSettings.java:116-118`）。analyzer は 5 系統 × 48（47 言語 + 無印）で合計 240 個（fess-suggest 側は `title_contents_analyzer` を含めて 241 個）。
- [確認] **`reading_form` を持つのは無印と `_ja` の 2 つだけ**。`reading_analyzer` 48 個の内訳は、`fess-res:` 側が「無印 + `_ja` = `fess_japanese_normal` + `reading_form`、`_ko` = `fess_korean_normal`、`_th` = `thai`、残り 44 = `{tokenizer: standard}`」、`res:` 側が「無印 + `_ja` = `kuromoji_neologd_normal` + `reading_form`、`_th` = `thai`、残り 45（`_ko` を含む）= `{tokenizer: standard}`」（両 JSON を全件パースして確認。`_ko` の差は X-24 の乖離の一部）。
- [確認] `reading_analyzer_*` と `reading_term_analyzer_*` は、48 系統のうち **46 系統が完全に同一**で、`reading_form` の有無で違うのは無印と `_ja` の 2 つだけ（両 JSON で同じ）。→ Y-10 の「2 回のうち 1 回が無駄」はこの 46 系統で成立する。
- [確認] `normalize_analyzer` 48 個のうち **42 個が完全に同一**（`keyword` tokenizer + `mapping_char` + `lowercase`）。フィルタを追加するのは `_ca` / `_fr` / `_it`（elision）、`_nl`（`stemmer_override`）、`_el`（`greek_lowercase`）、`_tr`（`turkish_stemmer` ほか。**唯一 stemmer を含む**）の 6 個だけで、両 JSON で同一。→ **`lang` 指定が `text` の正規化結果（= `_id`）を変えるのはこの 6 言語に限られる**（`_tr` の非対称は Z-08）。
- [確認] 言語未指定・サポート外言語はサフィックス無しの名前にフォールバックする（`AnalyzerSettings.java:184-200, 429-431`）。無印は `fess_japanese_normal` + `pos_filter` なので、**英語等が日本語形態素解析器と日本語品詞フィルタを通る**。
- [確認] 言語の由来は文書の `lang` フィールド 1 個（`index/contents/DefaultContentsParser.java:167`）で、fess の Tika 言語判定に完全依存する。
- **ユーザーから見て**: 日本語以外で「読み」によるサジェストは原理的に効かない。中国語も `standard` tokenizer なので漢字が 1 文字ずつ分割される。

#### Y-08 Kuromoji ユーザー辞書がサジェストに効かない — P1 [制約] [即修正候補] [境界外]
- [確認] 文書 index の日本語 tokenizer は `user_dictionary: "${fess.dictionary.path}ja/kuromoji.txt"` を持つ（`fess-res:fess_indices/fess.json` の `japanese_tokenizer`）。
- [確認] suggest 側の `fess_japanese_normal` は `{type: fess_japanese_tokenizer, mode: normal, discard_punctuation: "false"}` で **`user_dictionary` が無い**（`fess-res:suggest_indices/suggest_analyzer.json`）。同じファイル内の `fess_korean_normal` は `user_dict_path` を持つので、**言語間でも非対称**。
- [確認] `mapping_char` は `mappings` をインライン列挙し `mapping_path` を使わない。→ Admin > 辞書 > Mapping もサジェストに効かない。
- [確認] `_aws` / `_cloud` 版は `keywords_path` / `user_dict_path` を**インラインのサンプル値に置換**している（例: `arabic_keywords.keywords = ["ﻡﺮﺤﺑﺍﺍ", ...]`、`fess_korean_normal.user_words = ["덕후", ...]`）。→ **AWS OpenSearch Service / Fess Cloud ではファイル辞書がサジェストに一切効かない。**
- **ユーザーから見て**: 固有名詞を Kuromoji 辞書に登録しても検索には効くがサジェストの分割は変わらない。原因が辞書画面からは分からない。
- [提案] `user_dictionary` を 1 行足せば直る（`_aws` / `_cloud` は別途判断）。ただし Y-09 のため既存環境には反映されない。

#### Y-09 アナライザ定義を運用中に変更する手段が無い — P2 [制約] [構成で備える] [境界外]
- [確認] `AnalyzerSettings.init()` は index が**不在のときだけ** `createAnalyzerSettings(...)` を実行し、既存 index は絶対に更新しない（`settings/AnalyzerSettings.java:137-166`）。
- [確認] `updateAnalyzer(Map)` は実装が `prepareCreate` で既存 index には失敗し、しかも呼び出し元が 0 件。`deleteAnalyzerSettings()` / `checkAnalyzer()` も 0 件（refactoring_point B-05 と同一）。
- [確認] `analyzerMap` / `fieldAnalyzerMappingMap` は `static` で init 時のみ構築される（`:111-113, 161-162`）。`fieldAnalyzerMapping` を後から追加しても再起動まで反映されない。
- [確認] `protwords` は `keywords_path` 参照なので反映される余地があるが、index の close/open 手段が無い（`fess:app/web/admin/maintenance/AdminMaintenanceAction.java` に `suggest` の文字列が 0 件）。
- **ユーザーから見て**: Fess をバージョンアップして `suggest_analyzer.json` が新しくなっても、`fess_suggest_analyzer` index を手で削除しないと反映されない。`content_length_filter max:30`（30 文字超の語が出ない）も変更できない。

#### Y-10 suggest 1 回あたり「語数 × 言語数 × 3 回」の同期 `_analyze` — P2 [制約] [構成で備える] [境界外]
- [確認] 単語ごとに `normalizer.normalize`（`request/suggest/SuggestQueryBuilder.java:93` → `normalizer/AnalyzerNormalizer.java:59-71, 104-117` で言語数 × 1 回）と `readingConverter.convert`（`:99` → `converter/AnalyzerConverter.java:88-100, 123-136` で言語数 × 2 回）。すべて `actionGet` の同期呼び出し。
- [確認] 「東京 タワー」で ja と en を選ぶと **12 回の `_analyze` + 1 回の `_search`**。Y-07 のとおり無印と `_ja` を除く 46 系統では、`reading_analyzer` と `reading_term_analyzer` が同一定義なので 2 回のうち 1 回が完全に無駄。
- [確認] レスポンスキャッシュは無い。v2 API は `Cache-Control: no-store` を明示する（`fess:api/v2/SearchApiV2Manager.java:198-206`。ロールでフィルタするため意図的で、`api.json.response.headers` で上書き可能）。クライアントも `cache: false`（`fess-web:js/suggestor.js:200`）。
- [確認] 人気語は `_analyze` 0 回 + `_search` 1 回のみ。

#### Y-11 検索ログ 1 件ごとに設定読み込み 6 回 — P2 [制約] [構成で備える] [境界内]
- [確認] `SuggestIndexer` のコンストラクタが配列設定の検索 2 回（`supportedFields`、`badword`）と設定ドキュメントの GET 4 回（`tagFieldName` / `roleFieldName` / `langFieldName` / `parallel`）を行う（`index/SuggestIndexer.java:180-185`）。`SuggestSettings.get` はキャッシュしない（`settings/SuggestSettings.java:258-273`）。
- [確認] fess は検索ログ 1 件ごとに `suggester.indexer()` を呼ぶ（`fess:helper/SuggestHelper.java:251`）。`indexer()` は毎回 `new SuggestIndexer(...)`（`Suggester.java:366-368, 407-410`）。
- [確認] 呼び出し元は `Log Aggregator` ジョブ（cron `* * * * *`）の同期処理（`fess:helper/SearchLogHelper.java:476-491`）なのでユーザーのレイテンシには乗らない。ただし再構築時は保持日数分の全検索ログが同じループを通る（`fess:helper/SuggestHelper.java:173-194`）。
- [推測] 検索ログが多いサイトでは、ここが再構築時間の支配項になりうる。

#### Y-12 shards=1 / replicas=0 が JAR 内 JSON に固定 — P2 [制約] [構成で備える] [境界外]
- [確認] `res:suggest_indices/suggest.json`（`refresh_interval: 10s`）、`res:suggest_indices/suggest_settings.json`、`res:suggest_indices/suggest_settings_array.json`（いずれも `1s`）がすべて `number_of_shards: 1, number_of_replicas: 0, auto_expand_replicas: "0-1"`。
- [確認] `fess_config.properties` に suggest 用の shard / replica キーは 0 件。`AdminMaintenanceAction` の reindex は文書 index 専用。
- **ユーザーから見て**: `auto_expand_replicas` があるので 2 ノード以上ならレプリカ 1 になるが、**shard は必ず 1 本**でスケールアウトできず、3 ノード構成でレプリカ 2 にもできない。変更には JAR 内 JSON の差し替えが必要。

#### Y-13 日次フル再構築のみ。クロールとの依存関係も無い — P2 [制約] [別タスク] [境界外]
- [確認] `Suggest Indexer` は cron `0 12 * * *`、`Default Crawler` は `0 0 * * *`（`fess-res:fess_indices/fess_config.scheduled_job/scheduled_job.bulk`）。script に待ち合わせ処理は無く、単に 12 時間後に走る。
- [確認] 増分更新の経路はリアルタイム検索ログ反映だけ（`fess:helper/SearchLogHelper.java:485-488`）。文書由来の語は再構築でしか更新されない。
- [確認] 子 JVM は `-Xmx256m`（`fess-res:fess_config.properties` の `jvm.suggest.options`）、ログは別ファイル `fess-suggest.log`（`fess:job/SuggestJob.java:179`）。
- **ユーザーから見て**: クロールが 12 時間を超えると、サジェストは前日または途中のインデックスを見る。

#### Y-14 サジェスト index 群がバックアップ対象外 — P2 [制約] [別タスク] [境界外]
- [確認] `fess:app/web/admin/backup/AdminBackupAction.java` に `suggest` の文字列が **0 件**。対象は `index.backup.targets`（`fess_basic_config` / `fess_config` / `fess_user` / `system.properties` / `fess.json` / `doc.json`）と log 系。
- [確認] bad word / elevate word のマスタは `fess_config` index にあるのでバックアップされ、再構築で復元できる（`fess-res:fess_indices/fess_config.bad_word/`、`fess_config.elevate_word/`）。
- **ユーザーから見て**: Y-06 で手動投入した `fess_suggest` の設定はリストアで失われる。サジェスト本体は派生データなので再構築できるが、`AdminBackupAction` のリストアは `SuggestHelper.init()` を再実行する（`fess:helper/SystemHelper.java:919` 経由）ため、refactoring_point H-01 のスレッドプールリークも同時に踏む。

#### Y-15 管理画面は語数 3 個と一括削除 3 種のみ — P2 [制約] [別タスク] [境界内]
- [確認] `@Execute` は `index` / `deleteAllWords` / `deleteDocumentWords` / `deleteQueryWords` の 4 つ（`fess:app/web/admin/suggest/AdminSuggestAction.java:74-130`）。API 版も同じ 4 つ（`fess:app/web/api/admin/suggest/ApiAdminSuggestAction.java:53-100`）。
- [確認] 無いもの: 再構築の手動キック（スケジューラからジョブを手動実行する必要がある）、index 切替、最終再構築日時、index 名 / alias の状態、エラー件数、アナライザ設定の検証結果。
- [確認] `suggester().suggest()` の呼び出しは `fess:api/v2/handlers/SuggestWordsHandler.java:76` の 1 箇所だけで、管理系からサジェスト語を一覧・検索する手段は無い（W-07）。

#### Y-16 warn 止まりの失敗が運用者に届かない — P2 [制約] [別タスク] [境界外]
- [確認] ジョブの失敗自体はジョブログに載る（`fess:job/SuggestJob.java:231-243` → `fess:app/job/ScriptExecutorJob.java:132-133`）。ただし出力は `max.log.output.length=4000` で切られる。
- [確認] 一方で次の失敗は warn かログ無しで消え、exit code にも errors にも載らない。
  - `Suggester` 初期化全体の失敗（`fess:helper/SuggestHelper.java:157`）、`supportedFields` の登録失敗（`:152`）
  - 人気語の生成・読み込み失敗（`fess:helper/PopularWordHelper.java:122, 128` → 空リスト）
  - `index.analyze.max_token_count` 超過文書のスキップ（`index/operations/ContentIndexingOperations.java:265-271`）
  - チャンク単位の `_analyze` 失敗（`index/contents/DefaultContentsParser.java:291-310`）→ 文書の一部だけがサジェストに入る
  - `limitOfDocumentSize` 超過文書の破棄（`ESSourceReader.java:250-261`、**ログ無し**）
  - PIT 解放の失敗（`util/SuggestUtil.java:369-382`、warn のみ・リトライ無し）
- [確認] ログ通知（`LogNotificationTarget`、`fess:exec/SuggestCreator.java:174-179`）は `log.notification.enabled` 既定 false（`fess:mylasta/direction/FessProp.java:575-577`）。
- [確認] suggest 固有のメトリクスは無い（`fess:timer/` 配下に `suggest` が 0 件）。唯一の定量情報は `printProcessingInfo` の info ログ（`ContentIndexingOperations.java:440-459`）。

#### Y-17 `scrollTimeout` だけ設定手段が無い — P3 [制約] [構成で備える] [境界内]
- [確認] タイムアウトは 6 種（`settings/TimeoutSettings.java:25-35`）。fess は 5 つを `index.*` から設定するが（`fess:helper/SuggestHelper.java:136-140`）、`scrollTimeout` は設定していない（`modules/fess/src/main/java` を grep して 0 件）。
- [確認] `scrollTimeout` は PIT の keepAlive に流用されている（`util/PitOperationHelper.java:167-175` → `ESSourceReader.java:299`）。既定 1 分。
- [推測] 大規模 index で 1 分以内に次ページを取れないと PIT が失効し、`ESSourceReader.addDocumentToQueue()` のリトライに落ちる。調整手段が無い。
- [確認] 他の 5 つも suggest 専用ではなく fess 全体の `index.*` と共用なので、「サジェスト再構築だけ延ばす」ができない。

#### Y-18 `suggest.*` の区切り文字が不統一 — P3 [制約] [構成で備える] [境界外]
- [確認] `suggest.popular.word.tags` / `fields` / `excludes` は `split(..., "\n")`（`fess:mylasta/direction/FessProp.java:1143, 1149, 1155`）。`suggest.field.*` はカンマ（`fess:helper/SuggestHelper.java:120-123`）。同一ファイル内で規則が違う。
- [確認] `FessConfig` には `getSuggestPopularWordTagsAsInteger()` などの無意味な Integer getter が生成されているが、呼び出し元は 0 件。

#### Y-19 `fn` / `label` の誤指定が無言で 0 件になる — P3 [制約] [構成で備える] [境界内]
- [確認] `fn` / `label` は検証なしにそのままフィルタになる（`fess:api/v2/handlers/SuggestWordsHandler.java:71, 73, 80-82, 92-94` → `request/suggest/SuggestRequest.java:346-361`）。存在しないフィールド名・ラベル名でもエラーにならず、単に 0 件になる。
- 実機: `field=zzz&q=fess` → 0 件、`label=zzz&q=fess` → 0 件（いずれも HTTP 200・エラーなし）。
- **[確認] 対照として、ラベル絞り込み自体は正しく効いている。** 実機: `label=dbflute&q=fess` → 1 件（`labels` に `dbflute` を含む語だけ）。人気語側も `label=buzzfeed` と `label=elasticsearch` で内容が変わり、`label=zzz` → 0 件（`data: []`）。
- **ユーザーから見て**: タイポと「該当候補なし」が区別できない。ラベル名を間違えたまま「サジェストが出ない」と判断される。

### Z. サジェスト品質

#### Z-01 ローマ字変換が撥音・長音・促音を標準的な表記で作らない — P1 [品質] [構成で備える] [境界外]
- [確認] `KatakanaToAlphabetConverter` の変換表は 135 エントリ（2 文字キー 54、複数候補キー 22）。方式は訓令式を第 1 候補・ヘボン式を第 2 候補とするハイブリッド（`シ→["si","shi"]:129`、`チ→["ti","chi"]:135`、`ジャ→["zya","ja","jya"]:223`）。
- [確認] **`ン` は `["nn"]` だけ**（`converter/KatakanaToAlphabetConverter.java:170`）。`ケンサク` → `kennsaku`（`test:converter/KatakanaToAlphabetConverterTest.java:34` で確認）。`kensaku` は生成されない。
- [確認] **`ー`（U+30FC）はマップに存在しない**（表を全件走査して確認）。`:82-86` のフォールスルーで素通しされ、`fullwidthToHalfwidth`（`util/TransliteratorUtil.java`）で半角長音 `ｰ` になる。`コーヒー` → `koｰhiｰ`。
- [確認] **`ッ` は `["tu","tsu"]`**（`:275`）。`サッカー` → `satukaｰ` / `satsukaｰ`。子音重ね（`sakka`）を作らない。
- [確認] 候補数は `getMaxReadingNum()` = 10 で打ち切る（`converter/ReadingConverter.java:31-33`、`KatakanaToAlphabetConverter.java:96`、`converter/ReadingConverterChain.java:60, 68, 83, 95-97`）。多候補語では組合せの大半が捨てられ、どれが残るかは列挙順依存。
- **[確認] 撥音の実害は実機の対照ペアで決定的に確認できた。** 読みのローマ字は撥音を `nn` に変換して格納されるため、**自然な綴りは「語中の最初の撥音より前」までしか index 側の綴りと一致しない**。結果として次の非対称が生まれる。
  - 撥音が**語末にしか無い**語（にほん → `nihonn`）は、自然な綴り `nihon` が前方一致するので**偶然救われる**。
  - 撥音が**語中にある**語（けんさく → `kennsaku`、せんもん → `sennmonn`）は、自然な綴りが前方一致にならず**一切引けない**。

| 実機クエリ | 件数 | 解釈 |
| --- | --- | --- |
| `kensaku` / `kensak` | 0 | 自然な綴り。`kennsaku` の前方一致にならない |
| `kennsaku` | 4（検索 / 検索結果 / ケンサク / 検索漏れ） | `ン→nn` で生成された読みと一致 |
| `senmon` | 0 | 自然な綴り |
| `sennmon` / `sennmonn` | 1（専門） | `sennmonn` への前方一致 / 完全形 |
| `nihon` / `nihonn` | 4（日本語 / 日本テレビ 他） | **語末の撥音なので自然な綴りでも前方一致する** |
| `gijutsu` | 1（技術） | 撥音を含まないので正常 |

- 日本語では**語中の撥音は頻出**（ケンサク、センモン、カンサイ、コンピュータ…）なので、影響範囲は「一部の語」では済まない。**ローマ字（IME 未変換）入力でのサジェストは、語中に撥音を含む語では機能しない。**
- 長音・促音は実機で対照ペアが取れず未実証（`koohii` / `kohi` → 0 件だが候補の存在を確認できない）。根拠はコード読解のみ。
- 参考（コードから導かれる一致可否 [推測]）: `toukyou` / `touk` → ○（`toukyou` の前方一致）、`tokyo` → ×（長音省略）、`koohii` / `kohi` → ×（index 側は `koｰhiｰ`）、`sakka` → ×（index 側は `satukaｰ`）。

#### Z-02 文書からは 1 トークン = 1 語のみ。複数語候補の供給源が検索ログだけ — P1 [品質] [構成で備える] [境界外]
- 問題は検索側ではなく**供給側**にある。複数語の候補は存在すれば途中入力でも前方一致で引ける（実機: `q=fess n2sm` / `q=fess n` → いずれも 1 件 `fess n2sm`）。
- [確認] `parseDocument` はトークン 1 個ごとに `final String[] words = { word }` で `SuggestItem` を作る（`index/contents/DefaultContentsParser.java:185, 202`）。→ `reading_0` だけ。n-gram / shingle / 隣接トークン連結のロジックは無い。
- [確認] クエリは i 番目の語を `reading_i` に `must` で当てる（`request/suggest/SuggestQueryBuilder.java:86-114`）。最終語のみ prefix、それ以外は term 完全一致。
- [確認] 複数語の item を作るのは検索ログ由来（`parseSearchWords`、`:79-112`）、クエリログ由来（fess 未使用）、elevate word だけ。
- [確認] ja の `contents_analyzer` は `pos_filter` で動詞・形容詞・副詞・助詞・接尾辞・代名詞・連体詞などを落とす（`pos_filter` の stoptags は両モジュールとも 74 件。`res:suggest_indices/suggest_analyzer.json` / `fess-res:suggest_indices/suggest_analyzer.json` を JSON パースして計数）。残るのはほぼ名詞単体。
- **ユーザーから見て**: 検索ログが無い/少ない導入初期はサジェストが単語しか返せない。**2 語目を打った瞬間、検索ログに無い組み合わせは候補が 0 になる**（実機: `q=fess 検索` → 0 件。対照なし [推測]）。語順違い（`天気 東京` → `東京 天気`）や語の欠落（`東京 予報` → `東京 天気 予報`）にも対応しない。1 語目のタイプミスがあると一切候補が出ない。
- **→ Y-03 との連動**: 複数語候補の唯一の供給源が検索ログなので、**全員がログインする環境（Y-03）では複数語サジェストが恒久的に空になる**。Z-02 の実害の大部分は Y-03 の既定値で決まる。

#### Z-03 時間減衰が無く `@timestamp` はスコアに使われない — P1 [品質] [構成で備える] [境界外]
- [確認] function_score の要素は prefix weight / docFreq / queryFreq / userBoost の 4 つだけ（`request/suggest/SuggestQueryBuilder.java:142-167`）。`@timestamp` は使われない。
- [確認] `@timestamp` の参照はマージ時の上書き（`entity/SuggestItemMerger.java:87`、`entity/SuggestItemSerializer.java:183`）と削除クエリ（`index/operations/DeletionOperations.java:209`、`fess:helper/SuggestHelper.java:305-332`）だけ。
- [確認] 頻度は加算のみ（`SuggestItemMerger.java:92-93`、`SuggestItemSerializer.java:175-180, 243-249`）。時間窓別の頻度を保持するフィールドは mapping に無い（`res:suggest_indices/suggest/mappings-default.json`）。
- **ユーザーから見て**: 一度でも再出現すると `@timestamp` が現在時刻になり purge されず（X-10）、過去の流行語が高い freq のまま上位に張り付く。逆に「急上昇中の語」を上位に出す仕組みも無い。減衰を後から入れるための素材（過去の時間窓別頻度）もインデックスに無い。

#### Z-04 prefix ブーストと並べ替えが生クエリ比較で、かな種別で並び順が変わる — P1 [品質] [構成で備える] [境界外]
- [確認] `buildFunctionScoreQuery` の filter は `prefixQuery(FieldNames.TEXT, query)` に**正規化前の生クエリ**を渡す（`request/suggest/SuggestQueryBuilder.java:146-148`。呼び出しは `request/suggest/SuggestRequest.java:342`）。
- [確認] 一方 `text` に入るのは加工済みの語で、経路によって加工器が違う。
  - **文書経路**: `parseDocument` は `contents_analyzer_<lang>` の出力トークンをそのまま `word` にする（`index/contents/DefaultContentsParser.java:181` の `token.getTerm()`。`analyzeText`（`:235-236`）→ `analyzer.analyze(...)` → `AnalyzerSettings.getContentsAnalyzerName`（`settings/AnalyzerSettings.java:238-239`））。**引数の `normalizer` は `parseDocument` 内で一度も使われない**（同ファイルでの `normalizer` の実参照は `:91` と `:139` のみ）。`contents_analyzer` も `char_filter: ["mapping_char"]` + `filter` 先頭の `lowercase` を含むため、大文字・全角は結果的に潰れる。
  - **検索語経路**: `parseSearchWords` が `normalizer.normalize(...)`（`:91`）で `normalize_analyzer_<lang>`（keyword tokenizer + `mapping_char` + `lowercase`）を通す。
  - → いずれの経路でも `text` は小文字・半角化されているため、生クエリ比較が効かないという Z-04 の結論は変わらない。
- [確認] `isFirstWordMatching` も生クエリで `text.contains(query)` を見る（`request/suggest/SuggestResponseCreator.java:133`）。
- [確認] 両者とも **ひらがなクエリと複数語クエリでは常に無効**（`SuggestQueryBuilder.java:146` の `isSingleWordQuery && !isHiraganaQuery`、`SuggestResponseCreator.java:133`）。
- **[確認] 実機で観測できた実害 — 同じ読みの候補集合なのに、入力したかな種別で並び順が変わる。** 件数は同じで並び順だけが変わる。

| 実機クエリ | 件数 | 並び順（上位） |
| --- | --- | --- |
| `けんさく` | 4 | 検索, 検索結果, **ケンサク**, 検索漏れ |
| `ケンサク` | 4 | **ケンサク**, 検索, 検索結果, 検索漏れ |
| `けんさ` | 6 | 検索, 検索結果, 検審, **ケンサク**, 検索漏れ |
| `ケンサ` | 6 | **ケンサク**, 検索, 検索結果, 検審, 検索漏れ |
| `検索`（漢字） | 4 | 検索, 検索結果, 検索漏れ, ケンサク |

- 実機結果は上記のコード読解と正確に一致する。ひらがな入力では `isHiraganaQuery` によりブーストが切れて**頻度順**になり、カタカナ・漢字入力では `prefixQuery(text, 生クエリ)` が一致した候補（カタカナ入力なら `ケンサク`、漢字入力なら `検索*`）だけが 2.0 倍されて先頭に来る。
- **ユーザーから見て**: IME 変換前のひらがな入力こそサジェストの主戦場なのに、そこでだけ順位付けの仕組みが切れる。**同じ語を探しているのに入力した文字種で順位が変わる**ため、「前方一致する語が上に来る」という期待が満たされない。
- 大文字・全角クエリでも理屈上はブーストが効かないが、実機では差が出なかった（`fess` / `FESS` / `ｆｅｓｓ` で上位の並びが一致。[推測] 候補のほぼ全件が `fess` で始まるため）。

#### Z-05 スコアが 4 要素の積で、freq 片方が 0 の語が不利 — P2 [品質] [構成で備える] [境界外]
- [確認] `boostMode = REPLACE` / `scoreMode = MULTIPLY`（`request/suggest/SuggestQueryBuilder.java:163-164`）→ **クエリの BM25 スコアは完全に破棄される。** どの読みに何語マッチしたかはスコアに反映されない。
- [確認] 各 function は `missing(0.1f)` + `LOG2P`（`:151-157`）なので、freq 0 側は `log10(2.1) ≈ 0.32` が係数として掛かる。文書由来のみの語（`queryFreq=0`）は常に約 0.32 倍される。
- [確認] 完全一致ボーナス・語長ペナルティ・マッチ位置（前方 vs 中間）・フィールド重み（title / content）はいずれも存在しない。
- **ユーザーから見て**: 「東京」で検索したとき「東京」と「東京都中央卸売市場築地市場」が同じ 2.0 倍を受け、頻度だけで順序が決まる。

#### Z-06 `docFreq` が文書頻度ではなくトークン出現回数 — P2 [品質] [構成で備える] [境界外]
- [確認] `parseDocument` がトークン 1 個ごとに `docFreq=1` の item を作り（`index/contents/DefaultContentsParser.java:202`）、同一バッチで同 id をマージして加算する（`index/writer/SuggestWriter.java:76-102`、`entity/SuggestItemMerger.java:92-93`）。
- **ユーザーから見て**: 長文 1 件に 50 回出る語と 50 文書に 1 回出る語が同格になる。「珍しいが重要な語」を評価する idf 相当の要素は皆無。OCR 崩れ・ナビゲーション文字列・コード片が偶然多出すると高い docFreq を得る。

#### Z-07 事前計算の `score` フィールドが使われない — P2 [品質] [構成で備える] [境界外]
- [確認] 書き込みは 4 箇所（`entity/SuggestItemSerializer.java:73, 182, 217`、`util/SuggestUtil.java:223`、初期値は `entity/SuggestItem.java:360`）、mapping にも定義がある（`res:suggest_indices/suggest/mappings-default.json`）。
- [確認] **読み出しは 0 件**。`FieldNames.SCORE` の参照は書き込みだけで、fess 側にも無い。
- [確認] しかも式が検索時（積 + log）と違う（和 × userBoost）ので、「事前計算スコア」としても使えない。
- **ユーザーから見て**: index を直接見た人や外部連携が `score` を信用すると誤る。X-15 のとおり `deleteDocumentWords` 後は elevate word の `score` が 0 になるのに順位は変わらない。

#### Z-08 表記ゆれ正規化の範囲が狭い — P2 [品質] [構成で備える] [境界外]
- [確認] 既定の normalizer は `AnalyzerNormalizer` だけ。`HankakuKanaToZenkakuKana` / `FullWidthToHalfWidthAlphabetNormalizer` / `ICUNormalizer` はコメントアウトされている（`util/SuggestUtil.java:280-288`）。
- [確認] **吸収されているもの**: 大文字小文字（`lowercase` filter）、全角英数 62 文字、半角カナの濁音結合 20 種と単独半角カナ（`mapping_char` の 142 エントリ）。
- [確認] **誰も担当していないもの**（`mapping_char` を全件走査して不在を確認）:
  - 半角**半濁音** `ﾊﾟ` `ﾋﾟ` `ﾌﾟ` `ﾍﾟ` `ﾎﾟ`、単独の `ﾞ` `ﾟ` → `ﾊﾟｿｺﾝ` が「パソコン」と一致しない
  - 半角**長音** `ｰ`（U+FF70）→ `ｺｰﾋｰ` が「コーヒー」と別語
  - ひらがな ⇄ カタカナの統一 → `text` 上では「東京都」「とうきょうと」「トウキョウト」が別ドキュメント（読み側は `AnalyzerConverter` の `hiraganaToKatakana` で統合される）
  - 異体字・旧字体（髙/高、齋/斎）、記号・ハイフン類の統一、前後の空白の trim
- [確認] `_id = Base64(text)` なので `text` が完全一致しないと別ドキュメントになり、**頻度が分散する**。重複除去（Z-12）も潰せない。
- [確認] **索引側と検索側で正規化器が別**という非対称がある（Z-04 参照）。文書経路の `text` は `contents_analyzer_<lang>`、検索語経路とクエリ側は `normalize_analyzer_<lang>`（`request/suggest/SuggestQueryBuilder.java:93` → `normalizer/AnalyzerNormalizer.java:59-71, 104-117` → `settings/AnalyzerSettings.java:228-229`）。Y-07 のとおり `normalize_analyzer` に追加フィルタがあるのは `_ca` / `_nl` / `_fr` / `_el` / `_it` / `_tr` の 6 言語だけで、そのうち **`_tr` だけが `turkish_stemmer` を持ち、対応する `contents_analyzer_tr` は stemmer を持たない**（残る 5 言語は elision / lowercase / `stemmer_override` が両側に揃っているので対称）。
  - [推測] `lang=tr` では、クエリが語幹化される一方で index 側の `text` は語幹化されていないため、term 一致が成立しなくなる余地がある（実機未検証）。
- [確認] さらに elevate word / bad word の正規化は `normalizer.normalize(word, "")` で **言語を渡さない**（`index/operations/WordManagementOperations.java:78, 104-106`）ため、常に無印の `normalize_analyzer`（追加フィルタなし）が使われる。上記 6 言語では登録時とクエリ時で正規化が食い違う。
- [確認] 副次: `mapping_char` に `Ｇ=>g` `Ｊ=>j` `Ｋ=>k` があり他は大文字（`Ａ=>A` 等）。後段の `lowercase` で吸収されるため現状は無害だが、`lowercase` を外すと壊れる潜在バグ。

#### Z-09 読みが 1 本しか生成されない — P2 [品質] [構成で備える] [境界外]
- [確認] `AnalyzerConverter.LangAnalyzerConverter.convert` は連結した 1 本だけを `List` に入れて返す（`converter/AnalyzerConverter.java:164-170`）。`reading_i` は配列なので複数読みを持てる設計なのに、生成側が 1 本。
- **ユーザーから見て**: 形態素解析が誤読すれば誤った読みだけが保存され、正しい読みでは永久に引けない。固有名詞（人名・地名）と多音字が対象。
- [確認] ユーザー辞書の経路は死んでいる。`KatakanaConverter` は `isEnableTokenizer` が常に false・`createTokenStream` が常に null で `toKatakana` が必ず `IOException` を投げ、`init()` の中身も丸ごとコメントアウト（`converter/KatakanaConverter.java:69-79, 99-101, 135-146`）。`SuggestConstants.USER_DICT_PATH` の実参照は 0 件。
- [確認] 残る手段は elevate word の読み手入力だけだが、X-02 のとおり読み変換されない。OpenSearch 側の Kuromoji ユーザー辞書も Y-08 のとおり効かない。

#### Z-10 `AnalyzerConverter` が 2 つの `_analyze` 結果を添字で対応付ける — P2 [品質] [構成で備える] [境界外]
- [確認] `reading_analyzer` と `reading_term_analyzer` を 2 回呼び、`readingTokenList.get(i)` ↔ `termTokenList.get(i)` で対応付ける。検証は null チェックだけで**サイズ一致を見ていない**（`converter/AnalyzerConverter.java:140-142`）。対照的に `index/contents/DefaultContentsParser.java:174-176` はサイズ不一致を検出して読みを捨てる。
- [確認] `text.indexOf(term, offset)` で位置を復元するため、char_filter で表層が変わるトークンは `pos == -1` で `continue` され、その部分の読みが丸ごと欠落する（`:150-159`）。
- [推測] トークン数が食い違う言語構成では `IndexOutOfBoundsException` または誤った読み連結になる。

#### Z-11 人気語が窓内で頻度を無視し、固定シードで毎回同じ結果 — P2 [品質] [構成で備える] [境界内]
- [確認] rescore は `setQueryWeight(0).setRescoreQueryWeight(1)`（`request/popularwords/PopularWordsRequest.java:243-247`）→ 窓内では 1 次スコア（queryFreq）が**完全に無視され**、31 位は絶対に出ないのに 1 位と 30 位が同確率になる。
- [確認] fess 既定は `suggest.popular.word.seed=0`（`fess-res:fess_config.properties:1481`）で、`PopularWordHelper` がそのまま渡す（`fess:helper/PopularWordHelper.java:95, 114`）。`RandomScoreFunctionBuilder().setField("_seq_no")` は決定的なので、**毎回まったく同じ 10 語が同じ順で返る。** ライブラリ既定は `System.currentTimeMillis()`（`PopularWordsRequest.java:80`）。
- [確認] `_seq_no` に依存するため、再構築で振り直されると並びが総入れ替えになる。
- 実機: `seed=1` / `seed=2` で内容が総入れ替えになる（random_score は効いている）。返却は常に 10 件で、件数を増やす手段は API に無い（W-13）。
- [確認] `mustNot exists(reading_1)` で 1 語に限定（`:214`）→ 「複数キーワードで検索された履歴」は人気語に絶対に出ない。`excludeWords` は `termsQuery(TEXT, ...)` の完全一致のみ（`:231`）。重複除去も無い。

#### Z-12 重複除去が「空白除去後の完全一致」だけ — P2 [品質] [構成で備える] [境界外]
- [確認] `text.replace(" ", "")` をキーに `HashSet` で判定する（`request/suggest/SuggestResponseCreator.java:94-100`）。取得件数は `size * 2` 固定（`request/suggest/SuggestRequest.java:332-336`）。
- **ユーザーから見て**:
  - 「東京」と「トウキョウ」「とうきょう」は潰せず並んで出る（Z-08）。
  - 「株 式」と「株式」のように空白除去で偶然一致する別語は片方が消える。残るのはスコア順で、実行ごとに変わりうる。
  - `2 * size` 件中に重複が `size` 件を超えると返却件数が `size` に届かず、補充もしない。`record_count` は大きい値を返すので「候補はあるのに出てこない」状態になる（`request/suggest/SuggestResponse.java:52-61` → `fess:api/v2/handlers/SuggestWordsHandler.java:117-120`）。
- [確認] UI 側も `num * 2` を要求して（`fess-web:js/suggestor.js:204`）クライアントで再度重複除去する（`:274, 284-285`）ので二重に絞られる。

#### Z-13 最低頻度しきい値が無い — P2 [品質] [構成で備える] [境界内]
- [確認] `SuggestRequest.processRequest` のフィルタに freq の range が無い（`request/suggest/SuggestRequest.java:346-365`）。popularWords にはある（`request/popularwords/PopularWordsRequest.java:215`）。
- [確認] 語長の下限も無い（`content_length_filter` は `max: 30` のみ）。1 文字の語も候補になる。
- [確認] fess 側の絞り込みは `suggest.min.hit.count=1`（検索 0 件のログを除外、`fess:helper/SuggestHelper.java:202-205`）とセッション重複抑止（`:207-220`）だけ。**ヒット 1 件でも採用される**のでタイポがそのまま候補に載り、X-04 のため即座に消せない。
- **ユーザーから見て**: 誤字・ゴミトークン・1 回きりの語がノイズとして混ざる。候補が少ないクエリで可視化される。
- [提案] `suggest` 側に freq 下限のオプションを設けるのが最も低コストな改善余地。

#### Z-14 `matchWordFirst` が取得済み上位 size 件の中だけで並べ替える — P3 [品質] [構成で備える] [境界外]
- [確認] `words.size() < size` でループを打ち切ってから 2 バケットを連結する（`request/suggest/SuggestResponseCreator.java:89-120`）。スコアの再計算ではなく安定分割。
- [確認] `text.contains(query)` なので前方一致と中間一致を区別しない（「東京」で「新東京国際空港」も先頭バケットに入る）。
- **ユーザーから見て**: 11 番目以降にある完全一致語は決して先頭に来ない。関数スコアに組み込まれていないのが根本問題。

#### Z-15 インデックス側とクエリ側で `field` 引数が非対称 — P3 [品質] [構成で備える] [境界外]
- [確認] クエリ側は `normalize` / `convert` に **常に `""`** を渡す（`request/suggest/SuggestQueryBuilder.java:93, 99`）。インデックス側は実フィールド名を渡す（`index/contents/DefaultContentsParser.java:91-92`）。
- [確認] `getAnalyzerName` は field が非 blank かつ `fieldAnalyzerMapping` に登録があればフィールド固有アナライザを使う（`settings/AnalyzerSettings.java:184-200`）。
- [推測] `fieldAnalyzerMapping` を設定するとインデックス側とクエリ側で別アナライザになり一致しなくなる。fess は登録しないので既定では顕在化しない（Y-09）。`title_contents_analyzer` は定義だけあって未配線。

#### Z-16 解析対象の分割が 1000 文字単位 — P3 [品質] [構成で備える] [境界外]
- [確認] `fess.suggest.max.analyzed.content.length` の既定は 1000（`index/contents/DefaultContentsParser.java:75`）。`analyzeTextInternal`（`:261-278`）が本文をこの単位に区切って `_analyze` を呼ぶ。
- [確認] `fess_config.properties` にキーが無く（grep 0 件）、システムプロパティのみ。子プロセスには `jvm.suggest.options` 経由で渡す必要があり、web 側と別に設定しないと値がずれる。
- **ユーザーから見て**: 「切り捨て」ではなく「分割単位」なので、境界をまたぐ複合語が別トークンに分かれる。
- [確認] 別系統の上限として `maxContentLength`（既定 50000）があり、超過時は無言で空リストを返す（`settings/AnalyzerSettings.java:374, 385-387`）。文書経路は 1000 文字ずつなので当たらず、実質は 50000 文字超の検索語（`isExcludeSearchword` で無言に除外、`DefaultContentsParser.java:344-358`）だけが対象。

#### Z-17 記号だけの語・コード片が候補になっている — P1 [品質] [構成で備える] [境界外]
- **実機で候補として実在することを確認した**（0 件ではないので対照は不要）。実機: `q=)` → **47 件**（`)`, `);`, `){`, `)。`, `)、` …）、`q=。` → 7 件（`。(`, `。{`, `。$$`, `。...`, `。[（`）、`q=？` → 7 件（`？)`, `？...`, `？.........`, `？〜』（`, `？⇒「`）。
- [確認] **文書経路（ja）では落ちる想定**。`contents_analyzer` / `contents_analyzer_ja` の tokenizer は `discard_punctuation: "false"` で記号をトークン化するが、`pos_filter`（`fess_japanese_part_of_speech`）の stoptags 74 件には記号系 8 タグ（`記号` / `記号-一般` / `記号-句点` / `記号-読点` / `記号-括弧開` / `記号-括弧閉` / `記号-空白` / `記号-アルファベット`）が含まれる（`fess-res:suggest_indices/suggest_analyzer.json` を JSON パースして確認）。
- [確認] **検索ログ経路には品詞フィルタも語長フィルタも無い。** `parseSearchWords` は `normalizer.normalize`（`normalize_analyzer` = `keyword` tokenizer + `mapping_char` + `lowercase`）を通すだけで（`index/contents/DefaultContentsParser.java:91`）、`pos_filter` も `content_length_filter max:30` も経由しない。除外は `isExcludeSearchword`（50000 文字超）と bad word の `contains` 判定のみで、fess 側も `suggest.min.hit.count=1` だけ（Z-13）。
- [推測] したがって供給源は検索ログ経路が最有力。ただし `);` `){` はコード片なので、`pos_filter` を持たない言語別アナライザ（`contents_analyzer_en` は `standard` tokenizer + `pos_filter` なし）経由の可能性も残る。**API は kind を返さないため（W-13）、クライアントからは供給源を特定できない [要確認]。**
- **ユーザーから見て**: `(` や `。` を打った瞬間に記号の羅列が候補に出る。既定 bad word（`* ? " '`）では除去できず（X-06）、個別に消す手段も無い（W-07）。あわせて `fess/\`（`labels` が空配列）という語も観測しており、**ラベル絞り込みでも除去できない候補が存在する。**
- [提案] 語長下限（Z-13）と、経路に依存しない「候補として採用してよい語」の判定を 1 箇所に集める（§4-4 の「トークン列 → item 列」の変換点）。

#### Z-18 `fn`（フィールド）の語彙が経路ごとに食い違う — P2 [品質] [構成で備える] [境界外]
- 実機: `q=fess` → 58 件に対し `field=content` → **56 件**、`field=title` → **1 件（`fess` のみ）**。56 + 1 < 58 で、どちらにも属さない語が 2 件ある。
- [確認] `fields` に入る値が経路ごとに違う。
  - 文書由来: 実フィールド名（`content` / `title`。`index/contents/DefaultContentsParser.java:202`、対象は `suggest.field.index.contents=content,title`、`fess-res:fess_config.properties:1503`）
  - 検索ログ由来: 検索時のフィールド名のうち `suggest.field.contents`（既定 `_default`）に含まれるものだけ（`fess:helper/SuggestHelper.java:121, 226-239, 252`）→ 実質 **`_default` 固定**
  - elevate word: `contentFieldList` = `suggest.field.contents` = `_default`（`fess:helper/SuggestHelper.java:124, 483`。X-27 と同じ値）
- [確認] UI は `fn: ["_default", "content", "title"]` の 3 つすべてを送るので（`fess-web:js/search.js:52`）既定では隠れる。**API 利用者が `fn=content` だけを指定すると、検索ログ由来の語と優先語が全部落ちる。**
- [要確認] `field=title` が 1 件しか無い理由は、(a) タイトルが短く抽出語が少ないという自然な結果か、(b) デモ環境の `suggest.field.index.contents` が `content` のみか、クライアントからは区別できない。いずれにせよ **`fn=title` による絞り込みは実用にならない。** W-08（フィールド別重み付け）を入れる際の前提になる。

#### Z-19 デモ環境で `sear*` が一切引けない（原因未特定） — P2 [品質] [構成で備える] [境界外]
- 実機: `sear` / `searc` / `search` / `searching` すべて **0 件**。一方 `q=se` → **531 件**（security / service / settings / setting / 制御 …）、`q=swift` → 6 件。**`s` 始まりの語が大量にあるのに `search` だけが存在しない。** 全文検索製品のデモとしては不自然。
- [推測] 最も整合する説明は **bad word の部分一致**（X-06 / X-07 / W-12）。NG ワードに `search` が登録されていれば `isBadWord` の `text.contains(badWord)`（`entity/SuggestItem.java:455-461`）で `search` / `searching` / `searches` / `research` が**まとめて登録拒否**される。観測（`sear*` 全滅かつ `se*` は健全）はこの挙動と一致する。X-05 のワイルドカード未エスケープ（`sear*` の登録で `*sear**` 削除）も候補。
- [要確認] 原因はクライアントからは特定できない（§5 の問い 10）。デモ環境固有の設定が原因でも、**部分一致 NG ワードで語群が無言で全滅する**（X-06 / X-07）実例として残す。

### W. 未実装の機能候補

> 本章の「無い」判定はすべて grep で 0 件を確認したもの。検索語と対象を明記する。部分的にあるものは到達点を示す。

#### W-01 誤字補正（fuzzy / did-you-mean）が無い — P1 [新機能] [構成で備える] [境界内]
- [確認] `modules/fess-suggest/src/main` を `fuzz` / `Levenshtein` / `spell` / `didYouMean` / `typo` / `completion` で grep → **すべて 0 件**。クエリは term / prefix のみ（`request/suggest/SuggestQueryBuilder.java:106-110`）。
- [確認] **対照的に fess 本体の通常検索には fuzzy がある**（`fess:mylasta/direction/FessConfig.java` の `query.fuzzy.prefix_length` 系と `query.boost.fuzzy.*`）。「検索は fuzzy 可、サジェストは不可」という非対称。
- **[確認] 実機でも実証済み**（対照ペアあり）。実機: `q=fesss` → 0 件。同じ環境で `q=fess` は 58 件あるので、1 文字の挿入ミスで候補が完全に消えることが確認できた。実機: `q=elasitc` → 0 件（こちらは `elastic` 系候補の存在を確認できておらず対照なし [推測]）。
- [確認] 部分的な代替: 読み経由の別表記一致（ローマ字→漢字、ひらがな→カタカナ）。ただしこれはエイリアス一致で、編集距離ベースの補正ではない。
- [提案] 必要な拡張点: `SuggestQueryBuilder.buildQuery`（`fuzzyQuery` を should に追加、fuzziness / prefix_length を設定化）、`SuggestRequest` / `SuggestRequestBuilder`（パラメータ）、`SuggestWordsHandler` + `suggest.*` プロパティ。`reading_i` は keyword なので fuzzy 自体は可能。did-you-mean（訂正後クエリの提示）はレスポンススキーマの追加も要る。0 件時のフォールバックに限定する段階設計が現実的。

#### W-02 中間一致（infix）補完が無い — P1 [新機能] [構成で備える] [境界内]
- [確認] `modules/fess-suggest/src/main` を `ngram` / `infix` で grep → 0 件。両モジュールの `suggest_analyzer.json` を `edge_ngram` で grep → 0 件。`wildcardQuery` は bad word 削除の 1 箇所だけ（`index/operations/WordManagementOperations.java:81`）。
- **[確認] 実機でも実証済み**（対照ペアあり）。実機: `q=ess` → 4 件で、内容は `essence` / `essentielle` / `essr` / `essentielles` と**すべて前方一致**。同じ環境に 58 件ある `fess` は 1 件も含まれない。実機: `q=lasticsearch` → 0 件（`elasticsearch` という候補語の存在は確認できていないので対照なし [推測]）。
- [確認] 唯一の「語中一致」要素は `isFirstWordMatching` の `text.contains(query)` だが、これは並べ替えのみでヒットさせる仕組みではない（Z-14）。
- [提案] インデックススキーマ変更が必須。`res:suggest_indices/suggest/mappings-default.json` に `reading_*` / `text` のサブフィールド（`edge_ngram` / `ngram`）を追加し、analyzer を足す。**dynamic_templates が全 string を keyword にしているため、`reading_i` には明示 mapping か dynamic template の追加が必要。** index サイズへの影響が大きいので §5 の未解決の問いに置いた。

#### W-03 同義語展開がサジェストに効かない — P2 [新機能] [構成で備える] [境界外]
- [確認] 両モジュールの `suggest_analyzer.json` を `synonym` で grep → **0 件**。`modules/fess-suggest/src/main` も 0 件。
- [確認] 一方 fess の文書 index には `synonym_graph`（`synonyms_path=${fess.dictionary.path}synonym.txt`）がある（`fess-res:fess_indices/fess.json`）。
- [確認] 管理画面の同義語辞書（`fess:app/web/admin/dict/synonym/AdminDictSynonymAction.java`）は `synonym.txt` を編集するだけで、**suggest には一切反映されない**（suggest のクエリは `reading_i` への term / prefix で analyzer を通らない）。
- [提案] (a) 索引時展開 = `suggest_analyzer.json` に `synonym_graph` を追加（`AnalyzerSettings` は `${fess.dictionary.path}` 置換に対応済み、`settings/AnalyzerSettings.java:315-326`）、(b) クエリ時展開 = `ReadingConverterChain` に SynonymConverter を足す。keyword フィールドへの term 一致なので (a) の方が確実。ただし Y-09 のため既存環境には反映されない。

#### W-04 サジェスト候補の選択（採用率 / CTR）を学習しない — P2 [新機能] [別タスク] [境界外]
- [確認] 候補クリックはフォーム submit になる（`fess-web:js/suggestor.js:295-302`）→ 通常の検索ログとして残り、次回再構築で queryFreq に加算される。**間接的なフィードバックループは存在する。**
- [確認] ただし検索ログの mapping に「サジェスト由来か」を示すフィールドが無い（`fess-res:fess_indices/fess_log.search_log/search_log.json` の全プロパティを確認）。`SuggestWordsHandler` は検索ログを書かないので impression も残らない。→ **採用率は算出不可能。**
- [確認] 文書クリックは別ループで効く（`ClickLog` → clickCount → suggest 索引対象文書の走査順、`fess:helper/SearchLogHelper.java:598-634`、`fess:helper/SuggestHelper.java:288`）。これは「どの文書から語を拾うか」への影響で、候補の学習ではない。
- [提案] `/api/v2/suggest-words` に requestId / impression ログ、選択イベント用エンドポイント（既存の `fess:api/v2/handlers/ClickHandler.java` に倣う）、search_log に origin フィールド、suggest 側は `userBoost` とは別の学習スコア用フィールド。

#### W-05 ゼロ入力時のサジェストが無く、人気語がドロップダウンに統合されていない — P2 [新機能] [構成で備える] [境界外]
- [確認] `suggestor.js` は `inputText.length < settingMinTerm`（minterm=1、`fess-web:js/search.js:68`）で box を隠すだけで、フォーカス時の人気語表示は無い（`fess-web:js/suggestor.js:190-194`）。
- [確認] 人気語は JSP でページ内にサーバレンダリングされる（`fess-web:WEB-INF/view/search.jsp`、`index.jsp`、`searchNoResult.jsp`。`fess:app/web/base/FessSearchAction.java:151`）。ドロップダウンとは別の UI。
- [確認] トレンド（急上昇）の算出は無い（`decay` / `gauss` の grep が 0 件、時間窓別頻度も無い。Z-03）。
- [提案] フロントで focus 時に `/api/v2/popular-words` を呼ぶ（`suggestor.js` の `suggest()` 分岐 + `SUGGESTOR_CONFIG`）。トレンドはスキーマ設計から必要。

#### W-06 一致部分のハイライトが無い — P2 [新機能] [構成で備える] [境界内]
- [確認] `modules/fess-suggest/src/main` と fess の suggest 経路を `highlight` で grep → 0 件。
- [確認] API が返すのは `text` と `types`（tags）だけ（`fess:api/v2/handlers/SuggestWordsHandler.java:106-113`）。UI は XSS 対策で `.text()` 固定（`fess-web:js/suggestor.js:287`）。`escapeHtml` ヘルパ（`:101-103`）は未使用。
- [提案] 読み経由でマッチした場合は表示文字列上の一致位置が自明でないため、**サーバ側で一致範囲（offset / length）を算出して返す**のが正確。`SuggestResponse` / `SuggestItem` とレスポンススキーマの拡張が要る。

#### W-07 サジェスト語の一覧・検索・個別操作の手段が無い — P2 [新機能] [別タスク] [境界内]
- [確認] Y-15 のとおり管理画面には一覧も検索も無い。`suggester().suggest()` の呼び出しは `fess:api/v2/handlers/SuggestWordsHandler.java:76` の 1 箇所だけ。
- [確認] ライブラリ側には `SuggestIndexer.delete(id)` / `deleteByQuery` があるが（`index/SuggestIndexer.java:263-292`）、fess からは使われていない。`deleteOldWords`（`:447`）も 0 件。
- **ユーザーから見て**: 「この不適切な候補だけ消したい」への手段は (a) bad word 登録 + 再構築待ち、(b) 全削除、(c) OpenSearch を直接叩く の 3 択。
- [確認] elevate word / bad word には CRUD + 検索 + CSV upload/download が揃っている（`fess:app/web/admin/elevateword/AdminElevatewordAction.java`、`.../badword/AdminBadwordAction.java`。各 14 の `@Execute`）ので、**不足しているのは「suggest index の実体」を見る手段だけ。**
- [確認] `update` / `upload` は `deleteAllElevateWord` + `storeAllElevateWords` を呼び、後者の内部でも `deleteAllElevateWord` を呼ぶため `ElevateWordBhv.selectList` が 3 回走る（`fess:helper/SuggestHelper.java:411-441`）。語数が多いと管理画面の保存が重い。

#### W-08 フィールド別の重み付けが無い — P3 [新機能] [構成で備える] [境界外]
- [確認] `fields` はフィルタにしか使われない（`request/suggest/SuggestRequest.java:359-361`）。`buildFunctionScoreQuery` にフィールド boost は無い。
- [確認] `suggest.field.index.contents=content,title` は対象の列挙だけで重みが無く（`fess-res:fess_config.properties:1503`）、title と content で同じ `contents_analyzer` が使われる。
- [提案] (a) 索引時に反映（`index/contents/DefaultContentsParser.java:202` の `docFreq=1` 固定をフィールド別係数に）、(b) クエリ時に `fields` の function を追加。(a) は複数フィールド由来語のマージ（`entity/SuggestItemSerializer.java` の `mergeListField`）との整合が要る。

#### W-09 パーソナライズ・ユーザー個別履歴が無い — P3 [新機能] [別タスク] [境界内]
- [確認] `modules/fess-suggest/src/main` を `personaliz` で grep → 0 件。fess にも検索履歴 UI は無い（`searchHistory` / `search_history` / `recent.*search` の grep は LLM 会話履歴のみ）。
- [確認] 検索ログは `user` / `userSessionId` / `userInfoId` を持つ（`fess-res:fess_indices/fess_log.search_log/search_log.json`）が、suggest への取り込みは全ユーザー集約 + role フィルタのみ。`sessionId` は重複投入抑止にしか使わない（`fess:helper/SuggestHelper.java:207-220`）。
- [提案] suggest index に user 次元を足す（`FieldNames` + mapping + `SuggestItem` / `Serializer` / `Merger`）か、per-user recent queries の別 index を作って `SuggestWordsHandler` でマージ。Y-03 のプライバシー設計とセットで判断が要る。

#### W-10 A/B テスト・品質評価の仕組みが無い — P3 [新機能] [別タスク] [境界外]
- [確認] 両モジュールを `abtest` で grep → 0 件。`experiment` / `variant` は JVM オプション（`UnlockExperimentalVMOptions`）等の無関係な hit のみ。rank_eval 相当も無い。
- [確認] W-04 のイベントログが前提。加えて Y-02（毎回ランダムな 1 万件）のため、そもそも語彙が実行間で変動することを押さえる必要がある。

#### W-11 カテゴリ別の候補提示・文書候補の直接提示が無い — P3 [新機能] [別タスク] [境界内]
- [確認] レスポンスは語のフラットリスト（`request/suggest/SuggestResponse.java`、`fess:api/v2/handlers/SuggestWordsHandler.java:106-113`）。UI も 1 本の `<ol>` を作るだけ（`fess-web:js/suggestor.js:266-329`）。
- [確認] `SuggestItem.Kind.DOCUMENT` は「文書から抽出した**単語**」で文書そのものではない。suggest の mapping に url / title / docId は無い（`res:suggest_indices/suggest/mappings-default.json`）。
- [確認] 素材はある。`tags`（label + virtual_host）が SuggestItem に入っており API も `types` で返しているが、**UI は無視している**（`suggestor.js:266` で `hits[i].text` しか使わない）。→ クライアント側グルーピングは小さい拡張で可能。
- [提案] 文書候補の直接提示は `/api/v2/search` を数件で叩く instant-result 型が現実的。suggest index に持たせるなら全層に手が入る。

#### W-12 NG 語の指定が部分一致のみ — P3 [新機能] [構成で備える] [境界内]
- [確認] `SuggestItem.isBadWord` は `contains` 固定（`entity/SuggestItem.java:455-461`）。バリデーションは「空でない・空白を含まない」だけ（`settings/BadWordSettings.java:125-133`）。
- [確認] 無いもの: 完全一致 / 前方一致 / 正規表現の選択、ラベル・ロール別の NG（X-07 の dead field）、URL パターンによる除外（文書側の絞り込みは `reader.setQuery` の matchAll + random score だけ、`fess:helper/SuggestHelper.java:284-289`）、suggest 検索時の除外パラメータ。
- [確認] 人気語の除外は完全一致のみ（`request/popularwords/PopularWordsRequest.java:231`）。
- [提案] `BadWordSettings` にマッチ種別を持たせる（保存形式が `ArraySettings` の配列なので構造化が要る）+ `BadWord` entity の未使用フィールド活用。X-05 / X-07 の修正と同時に行うのが合理的。

#### W-13 サジェスト API のパラメータ・レスポンスが限定的 — P3 [新機能] [構成で備える] [境界外]
- [確認] 受け付けるのは `q` / `num` / `fn` / `lang` / `label`、暗黙に role・virtual host・kinds（`fess:api/v2/handlers/SuggestWordsHandler.java:68-102`）。GET 限定（`:62-66`）。
- [確認] 返すのは `q` / `page_size` / `record_count` / `query_time` / `suggest_words[{text, types}]`（`:106-121`）。
- [確認] 無いもの: ページング / オフセット、`detail`（score / freq / kinds。`suggestDetail` は内部にあるが未公開）、kind の明示指定、freq しきい値、ハイライト（W-06）、did-you-mean（W-01）、`lang` の実効化（Y-04）。`record_count` は重複除去前・size 制限前の総ヒット数なのでページングの目安に使えない（Z-12）。

#### W-14 UI 側の未実装 — P3 [新機能] [別タスク] [境界外]
- [確認] 実装済み: debounce 300ms、`minterm`、↑↓での選択と Enter 確定、マウス hover / click、ARIA 属性、XSS 対策の `.text()`、クライアント重複除去、v1 / v2 両形式対応（`fess-web:js/suggestor.js` 全 478 行）。
- [確認] 無いもの: inline autocomplete（type-ahead 補完）、Esc で閉じる、Tab 補完、外クリックでの close（blur 依存）、IME の `compositionend` 対応（`keydown` / `keyup` / `input` のみ）、結果のクライアントキャッシュ、in-flight abort（X-30）、label 送信（X-30）、ハイライト（W-06）、フォーカス時の人気語（W-05）。
- [確認] `SUGGESTOR_CONFIG` が 4 ファイルに重複するため、UI 拡張は 4 箇所を同時に更新する必要がある（`fess-web:js/search.js:49-71`、`index.js`、`advance.js`、`help.js`）。

---

## 3. `refactoring_point.md` の [要判断] 18 件との対応

同書 §3 で機能面の評価を本書に委ねた項目を、機能観点から再評価した。

| refactoring_point.md | 本書での評価 | 結論 |
| --- | --- | --- |
| C-05 / C-06（不正ドキュメント読み込み時の例外） | X-26 と同根。欠損データで NPE になる経路が `ArraySettings` / `ElevateWordSettings` にもある | **`MapValueExtractor` を適用して既定値へ寄せる方が機能的に正しい。** 再構築が NPE で落ちるより望ましい |
| C-08（空のタグフィールド設定時の `[""]`） | 実害は [推測] のまま。fess は常に値を設定する（Y-06 のとおり変更手段が無いので既定 `"label,virtual_host"` 固定） | 空配列にする。機能面の反対理由なし |
| D-03（`Suggester` の index 作成に競合対策が無い） | **X-19 として P2 に格上げ。** alias 付与が別リクエストである点（`createIndexIfNothing` との非対称）も併せて直すべき | **入れる方が正しい。** ただし §4-8 のライフサイクル切り出しとセットで |
| D-07（`toLowerCase` の Locale） | 既存 index を見失うリスクは残るが、index 名は `SuggestSettings` の `index` キーに保存される（Y-06）ので影響は限定的 [推測] | `Locale.ENGLISH` を付ける。移行手順を設計書に記載 |
| E-10（クエリログ経路の削除） | 機能面では `parseQueryLog` だけが複数語 item を作れる第 2 の経路。ただし fess は使わず、Z-02 の解決策にもならない | **削除してよい。** フレーズ生成は §4-4 のスキーマ拡張で別に解く |
| F-01 / F-03 / F-04 / F-06 / F-07（例外階層とエラー伝搬） | **X-09（bulk 失敗の消失）・X-14（コールバック例外の握りつぶしで永久ハング）・X-15（常に成功）・Y-16（warn 止まり）がすべてこの根に繋がる** | **機能面から強く支持。** §4-7 として申し送りに格上げ |
| F-05（`deleteOldWords` が結果を捨てる） | **X-15 として P2。** `deleteWordsByKind` も同じで、fess の管理画面が常に成功を表示する | 戻り値を伝播させる |
| F-09（割り込みフラグの復元漏れ） | X-14 と関連。中断時に「成功」で resolve されると再構築の失敗が見えなくなる | 実施を推奨 |
| H-01（fess 側のスレッドプールリーク） | Y-14 のリストア経路で踏む。機能面の観測結果は「リストアを繰り返すとスレッドが増える」だけ | fess 側の修正。本タスクのスコープは §5 の問い |
| H-06（`ESSourceReader` の PIT 解放漏れ） | Y-02 の「上限到達」分岐がまさにその経路。fess は try-with-resources で閉じるので実害なし | 塞ぐ方向で実施 |
| I-01 / I-02（命名と `scrollSize` 既定値） | **`scrollSize` の既定 1 は Y-01 の主因。** `setScrollSize` は境界 API なので、既定値変更は fess 側の設定値（`suggest.source.reader.scroll.size=1`）も同時に変えないと効果が無い | 旧名は残す。既定値は §5 の問い |
| J-09（テスト用解析プラグイン） | **X-24 と同根。** `res:suggest_indices/suggest_analyzer.json` 自体がテスト用フィクスチャ相当（サンプル語・`reloadable_kuromoji_*`）で、`src/main/resources` に置かれてリリース JAR に入っている | **アナライザ定義の所有権として §4-10 に格上げ** |
| 0001 §9-7 roles 既定値 | **X-18。** `_guest_` は fess の権限表現と決して一致しないセンチネル | 非対称の解消 + センチネルの二重管理の見直し |
| 0001 §9-7 `removeDisableIndices` の前方一致 | **X-20。** fess 既定では衝突しないが、クラスタ共有時と X-19 の窓でリスク | 世代管理に寄せる（§4-8） |
| 0001 §9-7 `restoreElevateWord` の二重保存 | **X-25。** `_id` が正規化語由来なので重複エントリは増えない。残る実害は `@timestamp` 書き換えと I/O | 影響小。P3 |
| 0001 §9-7 bad word の部分一致 | **X-05 / X-06 / X-07。** 未エスケープによる全語削除リスクが新たに判明 | エスケープは即修正候補。マッチ種別は W-12 |
| 0001 §9-2（N+1 書き込み） | **X-12（ロストアップデート）として機能面の欠陥に格上げ。** 性能だけの話ではない | §4-6 |

---

## 4. 今回のリファクタリング設計への申し送り

「機能変更は行わないが、機能変更が容易になる構成を検討する」という要件に対し、**どの機能改善を後から入れるために、どの拡張点を今回の設計で用意すべきか**を効果順に示す。

### 4-1. テキスト処理を OpenSearch 非依存のポートとして切り出す（最優先）
- 対象: `analysis/SuggestAnalyzer`、`normalizer/Normalizer`、`converter/ReadingConverter`。
- **前提**: `SuggestAnalyzer` が OpenSearch の `AnalyzeToken` を返しているため現状では差し替えられない（refactoring_point **B-04**）。自前の `SuggestToken`（term / offset / position）に置き換えることが出発点。
- これが前提になる項目: **Z-01**（ローマ字変換）、**Z-08**（表記ゆれ）、**Z-09**（複数読み）、**Y-07**（言語別読み）、**Y-08**（ユーザー辞書）、**Y-10**（`_analyze` 回数）、**W-03**（同義語）。
- 設計で用意するもの: (a) ポートの入出力を自前型にする、(b) 既定実装（`_analyze` 呼び出し）とローカル実装を並置できるようにする、(c) **正規化・読み生成の規則を宣言的なリソース（変換表）に外出しし、コードから切り離す**、(d) **「索引時の正規化器」と「検索時の正規化器」が同一であることをポートの契約として明示する**（現状は前者が `contents_analyzer_<lang>`、後者が `normalize_analyzer_<lang>` で別物。`_tr` では stemmer の有無が食い違う。Z-04 / Z-08）。

### 4-2. 読み生成の「候補数」と「変換規則」を設定可能にする
- `ReadingConverter.convert` は既に `List<String>` を返すので契約は足りている。問題は `AnalyzerConverter` が 1 本しか返さないこと（Z-09）と `getMaxReadingNum()` が 10 固定であること（Z-01）。
- 設計で用意するもの: 読み候補数を構成値にする / `KatakanaToAlphabetConverter` の 135 エントリの変換表をリソース化し、撥音・長音・促音の規則を後から追加できる形にする。

### 4-3. クエリ構築とスコアリングを差し替え可能な戦略にする（機能追加の入口を 1 点に集める）
- 現在 `SuggestQueryBuilder.buildQuery` / `buildFunctionScoreQuery` は `SuggestRequest` の `@Deprecated` 匿名サブクラス経由で呼ばれている（refactoring_point **A-07**）。これを `SuggestQueryStrategy`（IF）+ 既定実装に分離する。
- **同時に、戦略には正規化済みクエリを渡す。** これで Z-04（生クエリ比較）が構造的に起こり得なくなる。
- ここに集約できる項目: **W-01**（fuzzy）、**W-02**（infix のクエリ側）、**Z-03**（時間減衰）、**Z-05**（完全一致・語長・マッチ位置）、**Z-13**（freq しきい値）、**W-08**（フィールド重み）、**Y-04**（言語フィルタ）、**Y-05**（チューニング値の注入）。
- 効果が最大なのはこの 1 点。**順位付け系（Z-03 / Z-04 / Z-05 / Z-13 / Z-14）と W 章の検索側の項目がここに乗る。**

### 4-4. インデックススキーマを版付きで管理し、拡張の余地を残す
- 現状 `res:suggest_indices/suggest/mappings-default.json` は JAR 内に固定され、移行手段は再構築だけ（0001 §9-9）。
- 設計で用意するもの: (a) スキーマ版を index 名か設定に記録する、(b) `reading_i` を dynamic_templates 任せにせず**明示 mapping + サブフィールドを足せる形**にする、(c) `index.mapping.total_fields.limit` と shards / replicas を設定値にする（**X-23**、**Y-12**）。
- これが前提になる項目: **W-02**（edge_ngram サブフィールド）、**Z-03**（時間窓別 freq）、**W-06**（一致位置）、**W-09**（user 次元）、**W-11**（url / title）、**Z-02**（フレーズ候補）。
- **Z-02（文書からフレーズが作れない）は「候補の生成単位」の問題**なので、`ContentsParser` の出力を「1 トークン = 1 item」に固定しない構造（トークン列 → item 列の変換を差し替え可能にする）を用意しておく。

### 4-5. 設定のスナップショット化と、fess から設定できる範囲の明文化
- refactoring_point の提案 3（設定を不変スナップショットにする）と同時に、**`SuggestRequest` / `SuggestIndexer` の構成値を record にまとめ、fess からの注入口を 1 つに絞る**（refactoring_point **A-03**）。
- これが前提になる項目: **Y-05**（suggest 側チューニング）、**Y-06**（設定 7 キー）、**Y-11**（1 件ごとの設定読み込み）、**Y-17**（タイムアウト）。
- 今回は構成だけ用意し、`fess_config.properties` へのキー追加は別タスクにする。ただし**「何を外から与えられるべきか」のリストは設計書に明記する**（Y-05 / Y-06 の表がそのまま使える）。

### 4-6. 書き込みのマージ規則を明示的な方針オブジェクトにする
- `toUpdatedSource` が userBoost と `@timestamp` を無条件上書きしていることが **X-01**（優先語のブースト消失）と **X-10**（purge が効かない）の直接原因。マージ規則を `SuggestItemMerger` に完全に寄せ、**フィールドごとの合成規則（和集合 / 加算 / 上書き / max）を宣言的に持たせる。**
- 併せて `SuggestWriter` の契約を「items → 結果」に保ったまま、実装を scripted upsert / `_update` / multi-get に差し替えられるようにする（**X-12**、refactoring_point 提案 2）。

### 4-7. 失敗の伝わり方を 1 本にする（機能面から最も強く支持される項目）
- refactoring_point F 章（F-01〜F-07）の統一は、機能面では **X-09**（bulk 失敗の消失）・**X-14**（永久ハング）・**X-15**（常に成功）・**Y-16**（warn 止まり）を同時に解く。
- 設計で用意するもの: (a) `Response` に `getErrors()` の契約を持たせる、(b) 「例外を投げる」か「errors に積む」かを層ごとに固定する、(c) **fess が exit code とジョブログに反映できる形で返す**、(d) `Deferred` のコールバック例外をログに出す。
- (d) が無いと X-14（`refresh()` の例外で latch が下がらない）が残る。

### 4-8. index ライフサイクルを「世代」として扱う
- `createNextIndex` / `switchIndex` / `removeDisableIndices` を `SuggestIndexLifecycle` に切り出し（refactoring_point **A-02**）、次の 3 点を構造に織り込む。
  1. **alias 付与を作成リクエストに含める**（X-19。`createIndexIfNothing` は既にそうなっている）
  2. **保持世代数を引数にして直前世代を残す**（X-08 のロールバック不能を解く）
  3. **切替の前提条件を検証フックにする**（語数 > 0、errors 無し、など。X-08 / X-09）
- 併せて検索 alias / 更新 alias のどちらを使うかを API ごとに明示する（**X-21**）。`removeDisableIndices` の対象判定を前方一致から「自分が作った世代の集合」に変える（**X-20**）。

### 4-9. 「設定更新」と「インデックス反映」を分離する
- 現在 fess は bad / elevate word で `apply` を取る全 17 経路を `false` で呼び、さらに **NG ワード削除（`deleteBadWord`）には `apply` 引数も index 反映の実装も無い**（**X-04**）。`apply` boolean を捨て、`settings` 更新と `applyBadWords()` / `applyElevateWords()` の 2 操作に分ける。**この分離で「削除だけ反映手段が無い」という欠落も同時に埋まる**（操作が対称になるため）。
- bad word の反映はワイルドカードではなく**マッチ規則オブジェクト**を介すようにする（**X-05** の未エスケープ、**X-07** の部分一致、**W-12** のマッチ種別が一括で解ける）。
- elevate word 側は **X-02 / X-03** を構造的に防ぐため、「語とその読みの対応」を `ElevateWord` の生成時点で検証し、**語の表層形を必ず読みに含め、読み変換を通す**入口を 1 箇所にする。

### 4-10. アナライザ定義の所有権を決める（統合境界の問題）
- **X-24** の二重管理は fess / fess-suggest 境界の設計問題。選択肢は 3 つ。
  1. fess-suggest 側を「テスト用フィクスチャ」と明示して `src/test/resources` へ移す（リリース JAR から外れる）
  2. リソース名を分けて（例 `suggest_indices/suggest_analyzer-default.json`）、どちらを使うかを設定で明示する
  3. 現状維持 + クラスパス順への依存を文書化する
- どれを選ぶかは「fess 以外の利用者がいるか」に依存する（refactoring_point §5 の問い 1 と同じ前提）。**Y-08**（ユーザー辞書）・**Y-09**（更新手段）もここに乗るので、アナライザ定義の**バージョンと更新手段**をセットで設計する。

### 着手順の推奨
**4-7（失敗の伝搬）→ 4-1 + 4-3（ポートと戦略の切り出し）→ 4-8（世代管理）→ 4-6（マージ規則）→ 4-4（スキーマ）→ 4-5（設定）→ 4-9 / 4-10（境界の判断）。**
4-7 を先に置く理由は、以降のどの変更も「壊れたことに気付けない」現状では安全に検証できないため（refactoring_point のフェーズ 0 = I/O 契約テストと同じ論理）。

---

## 5. 未解決の問い

1. **X-04（`apply=false` 固定）は仕様か不具合か。** 即時反映に変えると管理画面の応答時間が伸び、X-05 / X-07 のワイルドカード削除リスクが顕在化する。4-9 の分離を入れた上で、既定をどちらにするか。**なお NG ワード削除だけは反映手段自体が無いので、こちらは仕様か実装漏れかを別に判断する必要がある。**
2. **Y-03（認証ユーザーの検索を学習しない）の既定を変えるか。** `suggest.search.log.permissions` の `allMatch` はプライバシー配慮と読めるが、全ユーザーがログインする環境では検索ログ由来の候補と人気語が機能しない。設定で選べるようにするか、既定を変えるか。複数語候補の供給源の判断（問い 9）と表裏。
3. **Y-01 / Y-02 の既定値（`scroll.size=1`、`doc.per.request=2`、`limit.num=10000`、50%）を変えるか。** 変えると再構築の負荷特性とサジェストの語彙が変わる。実測が必要。
4. **X-08（失敗しても切替）を直すのは fess 側の修正。** 本タスクのスコープに含めるか（refactoring_point の H-01 と同じ問い）。ライブラリ側は 4-8 の検証フックを用意するだけに留めることもできる。
5. **X-24 のアナライザ定義をどちらのモジュールが所有するか。** fess-suggest 単体利用者の有無で結論が変わる。
6. **Z-01 のローマ字変換を自前テーブルで直すか、既存ライブラリ（ICU の `Katakana-Latin` 等）に寄せるか。** icu4j は #99 で optional になったので、必須化するかの判断が絡む。
7. **W-02（infix）を入れるか。** `edge_ngram` サブフィールドを足すと suggest index が数倍になる見込み [推測]。Y-12（shards=1 固定）と合わせて容量の検討が必要。
8. **`parallel` 設定（Y-06）が有効化された実績があるか。** `ContentIndexingOperations` の `stream.parallel()` は common ForkJoinPool を使うため、有効化時の挙動（Y-01 の refresh 頻度との相互作用を含む）が未検証。
9. **Z-02 のフレーズ候補をどう供給するか。** 文書から shingle を作ると index が膨らみ、検索ログに頼ると Y-03 の制約を受ける。どちらを主経路にするかで 4-4 のスキーマ設計が変わる。
10. **Z-19（`sear*` が引けない）の原因を確認するか。** デモ環境のサーバ側設定（NG ワード一覧）を確認すれば切り分けられる。結果が「NG ワードの部分一致」なら X-06 / X-07 の優先度を上げる材料になる。
