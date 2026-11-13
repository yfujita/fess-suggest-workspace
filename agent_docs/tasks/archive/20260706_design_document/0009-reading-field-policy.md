# 0009 ステップ 4: `reading_*` の方針確定

> タスク: `20260706_design_document`（作業プラン `0003-design-document-work-plan.md` §3 ステップ 4）
> 実施日: 2026-08-13
> 目的: `dynamic` 方針・`reading_*` の語数上限・`index.mapping.total_fields.limit` の 3 点を、[要確認] を残さず確定させる（ステップ 5 の着手条件）。
> 凡例: **[確認]**＝実コード・実機・一次情報で直接確認済み ／ **[推測]**＝合理的な推定（断定ではない） ／ **[提案]**＝設計判断・改善候補 ／ **[確定]**＝`0000` §5・§5.1 の C / P / U ／ **[要確認]**＝未解消

> **文書番号について**: 作業プラン §3 ステップ 8 の想定割り当てでは本ステップの作業履歴は `0007-reading-field-policy.md` だった。`0006`（ステップ 2 レビュー反映）・`0008`（ステップ 3 レビュー反映）が後から挿入されたため、CLAUDE.md の採番規則「既存の最大番号 +1」に従い **`0009`** とする。`0006` 冒頭の注記（以降 1 つずつ繰り下がる）の延長であり、プラン違反ではない。

> **本書の位置づけ**: 本書は**経緯・根拠・検証結果の記録**である。決定そのものは `docs/0002-datamodel-design.md` に本文として書く（ステップ 5、未着手）。§6 に「0002 のどの節に何を書くか」を指示として置いた。プラン §3 ステップ 4 の注意点（P9）に従い、**提案書・`0005-schema-draft.md`・作業プランは書き換えていない**。

> **ファイルパス表記**: `0004` §1 と同一。無印は `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`、`(fess)` 付きは `modules/fess/src/main/java/org/codelibs/fess/`、`(res)` 付きは `modules/fess-suggest/src/main/resources/`、`(fess res)` 付きは `modules/fess/src/main/resources/` 配下。

---

## 1. 実施サマリ

| # | 実施内容 | 結果 |
| --- | --- | --- |
| 1 | `0004-new-findings.md` §3（F-01〜F-04）・§6（T-5）の根拠をコードで再検証 | **行番号のズレ 0 件。F-01〜F-06 / F-12 / T-5 はすべて有効**。結論が変わる発見なし。ただし `0004` に無い**新事実 2 件**（N-1 / N-2）を検出（§3） |
| 2 | **OpenSearch 3.7.0 の実機検証**（`dynamic` 3 案 ＋ `total_fields.limit` ＋ 未サポート値 ＋ null/空配列） | 6 系統 22 ケースを実行（§4）。**プランの推奨案（案 B）が成立しないことを確認** |
| 3 | 決定の確定 | **決定 1〜4 を確定**（§5）。完了条件の 3 点はすべて [要確認] なし（§9） |

**確定した決定**:

| # | 対象 | 決定 | プランの推奨との関係 |
| --- | --- | --- | --- |
| **決定 1** | `dynamic` 方針 | **`strict_allow_templates` ＋ `match:"reading_*"` テンプレート ＋ `reading_0..9` の明示列挙**（案 D） | **推奨案（案 B）を実機で否定して差し替え** |
| **決定 2** | 書き込み側の語数上限 | **既定 10 / 設定可能 / 設定上限 50**。切断点は `parseSearchWords` の語ループ ＋ `SuggestItem` コンストラクタの 2 段構え。**バックストップの実装のみ申し送り 1 の解消が前提条件**（§5.2 の★ / §9） | U3 [確定] を具体化（結論は同じ、**根拠文は訂正**） |
| **決定 3** | `total_fields.limit` | **`suggest.json` に `100` を明示する** | プランは「決める」とのみ。明示を採用 |
| **決定 4** | 適用範囲（プラン ステップ 4-5 への回答） | **厳格化は suggest 本体インデックスのみ。設定系 3 種は `dynamic:true` を維持** | プランは「決める」とのみ |

**作成・変更ファイル**:

| ファイル | 変更 |
| --- | --- |
| `0009-reading-field-policy.md`（本書） | 新規作成 |

**変更していないもの**: `docs/0002-datamodel-design.md`（ステップ 5 の担当・未着手）／ `docs/0000-design-overview.md`（訂正一覧の反映はステップ 7、本書 §7 が入力）／ 提案書・`20260706_opensearch_reference/0005-schema-draft.md`・作業プラン・`0004`（P9）／ プロダクションコードとリソース JSON（P10）。実機検証に用いたコードはスクラッチパッド上の使い捨てであり、**リポジトリには追加していない**。

---

## 2. 最重要成果: プランの推奨案（案 B）は OpenSearch では成立しない

本ステップで最も重要な発見を先に置く。

作業プラン `0003:193`（§3 ステップ 4 作業内容 2）は次を**推奨案**としていた。

> **推奨は案 B 系**: トップレベル `dynamic: "strict"` ＋ `dynamic_templates` を `match: "reading_*"` に限定して keyword を許可。

**これは OpenSearch では成立しない** [確認]。`dynamic: "strict"` は `dynamic_templates` を**無効化する**ため、テンプレートに合致する `reading_5` であっても `StrictDynamicMappingException` で拒否される（実機 T2-2、§4.3）。案 B を採ると、**11 語以上のサジェストクエリの取り込みがすべて失敗する** — これは案 A（`strict` ＋ `reading_0..9` の明示列挙）の欠陥として F-01 が指摘した事象そのものであり、案 B はその回避策になっていない。

正しい選択肢は、OpenSearch 2.16 で追加された第 3 の値 **`strict_allow_templates`**（本書では**案 D** と呼ぶ）である。この値は「`dynamic_templates` に合致するフィールドの動的追加は許可し、それ以外は拒否する」という、まさに案 B が意図した意味論を持つ [確認]（実機 T1、§4.2 ／ 一次情報 §11）。

この差し替えにより、`0005-schema-draft.md:89` が案 A のトレードオフとして残した **[要確認]「定数とスキーマの二重管理」も同時に解消する**（§5.1）。

---

## 3. コード再検証（プラン ステップ 4 作業内容 1）

### 3.1 結果: `0004` §3 の根拠はすべて有効 [確認]

`0004-new-findings.md` §3 が挙げた `file:line` を実コードで実査した。**行番号のズレは 1 件もなく、F-01〜F-06 / F-12 および T-5 はすべて有効**である。結論が変わる発見は無かった。本ステップの判断に直接効く主要根拠を再掲する（詳細は `0004` を正とし、本書には転記しない）。

| 根拠 | 内容 |
| --- | --- |
| `entity/SuggestItemSerializer.java:59-63` | `readings.length` の分だけ `reading_i` を put（F-01） |
| `converter/ReadingConverter.java:31-33` | `getMaxReadingNum` 既定 10 ＝ **1 語あたりの読み候補数**（F-02） |
| `index/contents/DefaultContentsParser.java:86-103` | `parseSearchWords` の語ループ。語数チェック無し（F-03） |
| `index/operations/ContentIndexingOperations.java:412` | `buf.toString().trim().split(" ")`。語数チェック無し（F-03） |
| `util/SuggestUtil.java:63` / `:101-102` | `MAX_QUERY_TERM_NUM = 5`。**超過時は `return new String[0]`＝全体を捨てる**（F-03） |
| `request/suggest/SuggestQueryBuilder.java:84-86` | 検索側はクエリの語数分しか `reading_i` を引かない（F-01） |
| `(res) suggest_indices/suggest.json:1-8` | `total_fields` の記述は無い（＝既定 1000）。トップレベル `dynamic` の明示も無い（T-5） |
| `(res) suggest_indices/suggest/mappings-default.json:2-12` | `match:"*"` / `match_mapping_type:"string"` → `keyword` の `dynamic_templates` が存在する（T-5） |

一方、**`0004` に無い新事実が 2 件**判明した。いずれもステップ 4 の決定に直接影響する。

### 3.2 N-1 `ElevateWord.toSuggestItem` は第 2 の `reading_*` 増殖経路である [確認]

`src/main` 全体を走査した結果、`new SuggestItem(...)`（引数付きコンストラクタ）を呼ぶのは **4 箇所のみ**である。

| 生成箇所 | `readings.length` の決まり方 | 上限 |
| --- | --- | --- |
| `index/contents/DefaultContentsParser.java:107`（`parseSearchWords`） | 除外後の text 語数 | **無し**（F-03） |
| `index/contents/DefaultContentsParser.java:144`（`parseQueryLog`） | `SuggestUtil.parseQuery` の語数 | 5（`util/SuggestUtil.java:63`） |
| `index/contents/DefaultContentsParser.java:202`（`parseDocument`） | 常に 1（`:185` `final String[] words = { word };`） | 1 |
| **`entity/ElevateWord.java:146`（`toSuggestItem`）** | **`readings` リストの要素数**（text は常に 1 要素） | **無し** |

`entity/ElevateWord.java:144-145` は次の形であり、**読み候補 1 個につき 1 本の `reading_i` を生やす**。

```java
final String[][] readingArray =
        this.getReadings().stream().map(reading -> new String[] { reading }).toArray(count -> new String[count][]);
```

fess 側は `(fess) helper/SuggestHelper.java:466-471` で管理画面の「読み」入力を空白（および全角空白）で分割して `readings` に渡すため、**読みを空白区切りで k 個入力すると `reading_0..reading_{k-1}` が生える**。

**この発見の意味**: 語数上限を `parseSearchWords` にだけ入れてもこの経路は素通りする。決定 2 のバックストップ（§5.2）はこれを織り込んだものである。

### 3.3 N-2 `PopularWordsRequest` が `reading_1` の `exists` に依存している [確認]

`request/popularwords/PopularWordsRequest.java:213` は次のとおりで、「1 語のアイテムのみを対象にする」という条件を **`reading_1` が存在しないこと**で表現している。

```java
queryBuilder.mustNot(QueryBuilders.existsQuery(FieldNames.READING_PREFIX + "1"));
```

**この発見の意味**: `dynamic:"false"`（案 C）を採ると `reading_1` 以降が未マップになり、`exists` が 0 件マッチ、`mustNot` が no-op 化して**多語アイテムが popular words に混入する**。案 C を排除する根拠であり、実機でも裏付けた（T3-4、§4.4）。

### 3.4 引用行番号の訂正（本ステップの調査依頼に含まれていたもの）[確認]

本ステップの調査過程で引用された `Suggester.java` の行番号に誤りがあったため、正しい値を記録する。**結論には影響しない**（決定 4 の根拠は「世代交代が設計に組み込まれている」という事実であり、行番号の同定に依存しない）。

| 誤 | 正 |
| --- | --- |
| `Suggester.java:214`（`createNextIndex()`） | `createNextIndex()` は **`Suggester.java:235`**。`:214` は `createIndexIfNothing()`（`:196`）内の `setMapping` 呼び出し |
| `Suggester.java:251`（`switchIndex()`） | `switchIndex()` は **`Suggester.java:282`**。`:251` は `createNextIndex()` 内の `setMapping` 呼び出し |

決定 4 で引くべき根拠は `Suggester.java:239-251`（`getDefaultMappings()` / `getDefaultIndexSettings()` をリソースから読み、`prepareCreate` に渡している）である。

---

## 4. 実機検証（OpenSearch 3.7.0）

### 4.1 検証環境と方法

| 項目 | 内容 |
| --- | --- |
| バージョン | **OpenSearch 3.7.0**（`fess-parent:15.7.0` の `opensearch.version` = 3.7.0、`opensearch.runner.version` = 3.7.0.0。`modules/fess-suggest/pom.xml:36-40,127-129`） |
| 起動方法 | **`opensearch-runner 3.7.0.0` による埋め込み 1 ノードクラスタ**。docker が本環境で利用不可のため、`modules/fess-suggest` のテスト依存に既にある runner を使用した |
| 検証コード | スクラッチパッド上の**使い捨て**。**リポジトリには追加していない**（P10） |
| 検証対象 mapping の骨格 | `dynamic_templates`: `{"readings":{"match":"reading_*","match_mapping_type":"string","mapping":{"type":"keyword"}}}` ／ `properties`: `text`(keyword), `queryFreq`(long), `reading_0`(keyword), `reading_1`(keyword) |

**この環境で得た結果の適用範囲** [確認]: `strict_allow_templates` は OpenSearch 2.16 で追加された値であり（§11）、3.7.0 は fess 15.7 の前提バージョンと一致する。したがって本検証結果は本番構成にそのまま適用できる。ただし 2.16 未満での挙動は T5（§4.6）による**推定**であり、実機では確認していない。

### 4.2 T1: `dynamic: "strict_allow_templates"`（＝案 D）

**検証したこと**: テンプレートに合致するフィールドの動的追加が許可され、合致しないフィールドが拒否されるか。null と検索可能性も含めて確認した。

| # | 投入内容 | 結果 |
| --- | --- | --- |
| T1-1 | `reading_5` を含む doc | **CREATED**（テンプレート経由で動的追加） |
| T1-2 | `reading_12` を含む doc | **CREATED** |
| T1-3 | `unknown_field` を含む doc | **拒否** — `StrictDynamicMappingException: mapping set to strict_allow_templates, dynamic introduction of [unknown_field] within [_doc] is not allowed` |
| T1-4 | `reading_abc`（数値でない接尾辞） | **CREATED**（`reading_*` に合致するため通る） |
| T1-5 | 未マップの `reading_7` に **null** | **拒否** — `StrictDynamicMappingException ... dynamic introduction of [reading_7]`。マップ済みの `reading_0: null` は成功 |
| T1-6 | 書き込み後の mapping | `dynamic=strict_allow_templates`、フィールド 7 個 = `[queryFreq, reading_0, reading_1, reading_12, reading_5, reading_abc, text]` |
| T1-7 | 動的追加された `reading_5` への term 検索 | **hits=1**（＝検索可能） |

**言えること**:

1. 案 D は「`reading_*` は可変数で許可、それ以外の未知フィールドは拒否」という**案 B が意図した意味論を実際に満たす**（T1-1/1-2/1-3）。
2. 動的追加されたフィールドは**通常どおり検索できる**（T1-7）。案 C との決定的な差である。
3. **`reading_i` に null を書き込むと未マップの場合に取り込みが失敗する**（T1-5）。これは決定 1 の付帯規則になる（§5.1）。
4. `reading_abc` のような誤ったキーは通る（T1-4）。実害は keyword が 1 本増えるだけで軽微。

### 4.3 T2: `dynamic: "strict"` ＋ `dynamic_templates`（＝プランの推奨案・案 B）

**検証したこと**: `strict` 下で `dynamic_templates` が受け皿として機能するか。

| # | 投入内容 | 結果 |
| --- | --- | --- |
| T2-1 | マップ済み `reading_0` のみ | CREATED |
| T2-2 | `reading_5`（テンプレートに合致） | **拒否** — `StrictDynamicMappingException: mapping set to strict, dynamic introduction of [reading_5] within [_doc] is not allowed` |

**言えること**: **`strict` は `dynamic_templates` を無効化する。案 B は成立しない**（§2）。プラン `0003:193` の推奨案は差し替えが必要であり、`0000` の訂正一覧に載せる（§7）。

### 4.4 T3: `dynamic: "false"` ＋ `dynamic_templates`（＝案 C）

**検証したこと**: 未マップの `reading_i` が保存されるか、検索できるか、`exists` に反応するか。

| # | 投入内容 | 結果 |
| --- | --- | --- |
| T3-1 | `reading_5` を含む doc | CREATED（ただし未マップのまま） |
| T3-2 | 書き込み後の mapping | フィールド 4 個 = `[queryFreq, reading_0, reading_1, text]`（`reading_5` は増えない） |
| T3-3 | `reading_5` への term 検索 | **hits=0**（＝検索不能） |
| T3-4 | `reading_5` への `exists` クエリ | **hits=0** |

**言えること**: 案 C は取り込みこそ通るが `reading_*` が検索不能になり、**サジェスト機能そのものが壊れる**（T3-3）。加えて T3-4 は N-2（§3.3）のとおり `PopularWordsRequest.java:213` の `mustNot(exists(reading_1))` を no-op 化し、**多語アイテムが popular words に混入する**。案 C は排除。

### 4.5 T4: `index.mapping.total_fields.limit`

**検証したこと**: limit が実際に取り込みを止めるか、止まった後に運用で回復できるか。

| # | 操作 | 結果 |
| --- | --- | --- |
| T4-0 | `total_fields.limit=8` でインデックス作成 | ack=true |
| T4-1 | 初期 mapping のフィールド数を確認 | `dynamic=strict_allow_templates`、フィールド **4 個** = `[queryFreq, reading_0, reading_1, text]` |
| T4-2 | `reading_2`〜`reading_9` を一度に追加する doc（計 12 フィールド） | **拒否** — `IllegalArgumentException: Limit of total fields [8] has been exceeded` |
| T4-3 | `_settings` API で limit を 100 に引き上げ | **acknowledged=true**（reindex 不要） |
| T4-4 | 同じ doc を再投入 | **CREATED** |

**言えること**: limit は **tripwire として実際に機能し、かつ運用中に動的に引き上げられる**（＝踏んでも逃げ道がある）。決定 3 で低めの値を設定するコストが小さいことの根拠である。

### 4.6 T5: 未サポートの `dynamic` 値

**検証したこと**: `dynamic` に未知の値を与えたときの失敗の形（＝OpenSearch 2.16 未満で `strict_allow_templates` を指定した場合に起きることの代理検証）。

| 操作 | 結果 |
| --- | --- |
| `dynamic: "bogus_value"` でインデックス作成 | **失敗** — `MapperParsingException: Failed to parse mapping [_doc]: Could not convert [dynamic.dynamic] to boolean` / `Failed to parse value [bogus_value] as only [true] or [false] are allowed.` |

**言えること**: 2.16 未満では `strict_allow_templates` が未知の値として boolean 変換に落ち、**インデックス作成の時点で即座に失敗する** [推測]（2.16 未満の実機では未検証）。少なくとも「取り込み時にじわじわ壊れる」形にはならず、**移行の最初の一手で気付ける**。決定 1 の採用に伴うバージョン要件（§5.1）のリスク評価に用いる。

### 4.7 T6: null / 空配列の `reading_i` — テンプレート 3 変種の比較

**検証したこと**: 決定 1 のテンプレートに `match_mapping_type` を付けるべきか。`dynamic: "strict_allow_templates"` を固定し、テンプレートの `match_mapping_type` だけを変えて比較した。

| 投入内容 | A: `match_mapping_type:"string"` | B: `match_mapping_type` なし | C: `match_mapping_type:"*"` |
| --- | --- | --- | --- |
| マップ済み `reading_0: null` | CREATED | CREATED | CREATED |
| **未マップ `reading_7: null`** | **拒否** | **拒否** | **拒否** |
| 未マップ `reading_7: "X"` | CREATED | CREATED | CREATED |
| **未マップ `reading_8: []`（空配列）** | **拒否** | **CREATED** | **CREATED** |
| `reading_7` 作成後の `reading_7: null` | CREATED | CREATED | CREATED |

**言えること**:

1. **null 値は型を持たないためどの変種でもテンプレートに合致せず、未マップのフィールドに対しては拒否される。** テンプレートの書き方では回避できない ⇒ **書き込み側で null をスキップするしかない**（決定 1 の付帯規則）。
2. **空配列 `[]` は `match_mapping_type:"string"` を付けた場合のみ拒否される。** したがって決定 1 のテンプレートには `match_mapping_type` を**付けない**（§5.1）。

---

## 5. 確定した決定

### 5.1 決定 1: `dynamic` 方針 — `strict_allow_templates` ＋ `reading_*` テンプレート ＋ `reading_0..9` 明示列挙（案 D）

**決定**: `docs/0002-datamodel-design.md` §5-1 に、次の骨格を To-Be mapping の本文として書く。

```jsonc
{
  "dynamic": "strict_allow_templates",
  "dynamic_templates": [
    { "readings": { "match": "reading_*", "mapping": { "type": "keyword" } } }
  ],
  "properties": {
    "@timestamp": { "type": "date", "format": "epoch_millis" },
    "text":      { "type": "keyword" },
    "queryFreq": { "type": "long" },
    "docFreq":   { "type": "long" },
    "userBoost": { "type": "double" },
    "kinds":     { "type": "keyword" },
    "tags":      { "type": "keyword" },
    "roles":     { "type": "keyword" },
    "languages": { "type": "keyword" },
    "fields":    { "type": "keyword" },
    "reading_0": { "type": "keyword" },
    /* ... reading_9 まで ... */
  }
}
```

`score` は MIG-02 で廃止するため含めない。`excluded`（boolean、MIG-13）の追加はステップ 5-1 で統合するため上記骨格には現れていないが、**フィールド数の数え方（§5.3）は `excluded` を含む固定 11 個を前提としている**。最終形は 0002 §5-1 で 1 つの mapping に統合する。

**案の比較**:

| 案 | 内容 | 判定 |
| --- | --- | --- |
| 案 A | `strict` ＋ `reading_0..N-1` の明示列挙のみ | **却下**。語数上限 N を実行時に上げると mapping 追随が必須になり、追随漏れで取り込みが全停止する。`0005-schema-draft.md:89` が [要確認] として残した「定数とスキーマの二重管理」問題 |
| 案 B | `strict` ＋ テンプレート（**プランの推奨案**） | **却下**。**実機で成立しないことを確認**（T2、§4.3） |
| 案 C | `false` ＋ テンプレート | **却下**。`reading_*` が検索不能になりサジェスト機能が壊れる（T3-3）。加えて N-2 により popular words も壊れる（T3-4） |
| **案 D** | **`strict_allow_templates` ＋ テンプレート ＋ `reading_0..9` 明示列挙** | **採用** |

**採用理由の核心**: 案 D ではテンプレートが受け皿になるため、**明示列挙は正当性の要件ではなく最適化**になる。語数上限 N を 20 に上げてもインデックスを作り直さずに動く。⇒ **`0005-schema-draft.md:89` の二重管理問題が構造的に消滅する**（案 A では列挙漏れ＝障害だが、案 D では列挙漏れ＝わずかな性能劣化にすぎない）。

**`reading_0..9` を明示列挙する理由**（案 A の明示列挙とは目的が異なる点を 0002 に明記する）:

1. **取り込み時の cluster-state 更新を避ける最適化。** 動的フィールド追加は cluster-manager 経由の cluster-state 更新を伴うため、全件再投入（`(fess) exec/SuggestCreator.java`）の序盤で `reading_0`〜`reading_9` の追加が逐次発生する。事前宣言すればゼロになる。
2. **スキーマの自己文書化。** 「通常想定は 10 本」がスキーマから読める。

**`match_mapping_type` を付けない理由** [確認]: T6（§4.7）のとおり、`match_mapping_type:"string"` を付けると**空配列 `[]` の `reading_i` が拒否される**。`entity/SuggestItemSerializer.java:59-63` は `readings[i]` をそのまま put するため空配列が渡りうる（`index/contents/DefaultContentsParser.java:92-102` の `l.toArray(String[]::new)` が空になる経路。`converter/ReadingConverterChain.java:50-52` が入力 text 自体を必ず結果に含めるため通常経路では空にならないが、`normalize` が null を返す場合に到達しうる）。堅牢性のため付けない。

**あわせて 0002 に書く付帯規則**（T1-5 / T6 から導かれる）:

> **`reading_i` に `null` を書き込んではならない。** null は型を持たないため `dynamic_templates` に合致せず、未マップの `reading_i` に対しては `StrictDynamicMappingException` で**取り込みが失敗する**。`entity/SuggestItemSerializer.java:59-63`（`readings[i] == null` のとき `map.put(..., null)`）は、**null をスキップする形に改める必要がある**。

**採用に伴う制約（ステップ 6・移行運用への申し送り）**:

- **OpenSearch 2.16 以上が必須になる** [確認]。`strict_allow_templates` は 2.16 で追加された OpenSearch 独自値であり、Elasticsearch には存在しない（§11）。2.16 未満では T5 の形でインデックス作成が失敗する [推測]。
- fess 15.7 は OpenSearch 3.7.0 前提（`fess-parent:15.7.0`）なので通常構成では実害はない。ただし **AWS OpenSearch Service で 2.16 未満を使っている利用者**は初回インデックス作成で失敗する。そうした利用者の実在は `(fess res) suggest_indices/_aws/suggest_analyzer.json` の存在から示唆される [推測]。移行手順に**最小バージョン要件**として明記する。
- `reading_abc` のような誤ったキーはテンプレートに合致して通る（T1-4）。実害は keyword が 1 本増えるだけで軽微であり、許容する。

### 5.2 決定 2: 書き込み側の語数上限 — 既定 10 / 設定可能 / 設定上限 50

プラン §6.1 **U3 [確定]**（「設定可能な上限を設けて切り捨てる」）を、以下の形に具体化して確定する。

#### 切断点は 2 段構え

**1. 一次切断点: `index/contents/DefaultContentsParser.java:86-103`（`parseSearchWords`）の語ループ**

`isExcludeSearchword`（`:87-89`）による除外の**後**、正規化（`:91`）と読み変換（`:92`）の**前**に `break` する。

- `wordsList`（text 側、`:101`）と `readingList`（readings 側、`:102`）が**同一反復で同時に append される**ため、片方だけ切れる事故が構造的に起こらない。
- 除外の**後**にカウントするため「除外語だけで枠を使い切って 0 語になる」事故が起きない。`index/operations/ContentIndexingOperations.java:412` の `words` 配列を先に切ると、この事故が起きる。
- 変換の**前**に break するため、捨てる語の読み変換コストを払わずに済む。

**2. バックストップ: `entity/SuggestItem` のコンストラクタ（`:113-141`）**

「text の語数 = `readings.length` ≤ N」を不変条件として強制する。

- **N-1（§3.2）のとおり `ElevateWord.toSuggestItem` は parser を通らない第 2 の生成経路**であり、parser 側の cap だけでは守れない。
- ID 生成（`entity/SuggestItem.java:140`）と同じコンストラクタ内なので、**text / readings / ID の三者が常に整合する**。

> **★ このバックストップには順序依存があり、単独では実装できない [確認]**
>
> **現行の elevate word 経路は、この不変条件を恒常的に違反している。** `entity/ElevateWord.java:144-146` は `text` を 1 語（`new String[] { this.getElevateWord() }`）としながら `readings` を**読み候補 k 個ぶんの k 本**（`this.getReadings().stream().map(reading -> new String[] { reading })`）生成するため、読みを 2 つ以上持つ elevate word はすべて「text 語数 1 ≠ `readings.length` k」となる。
>
> したがって、**`ElevateWord.toSuggestItem` を 1 語 × k 候補形（`new String[][] { allReadings }`）に修正するのが先で、コンストラクタでの不変条件の強制はその後でなければならない。** 順序を逆にすると、**複数読みの elevate word の登録がすべて失敗する**（`(fess) helper/SuggestHelper.java:466-471` は管理画面の「読み」入力を空白分割して渡すため、実運用で普通に発生する）。
>
> この修正の可否そのものが **§10 の申し送り 1（`ElevateWord` の読みセマンティクスの確定）[要確認]** である。すなわち、**バックストップは申し送り 1 がステップ 5-3 で解消されるまで実装可能にならない**。本決定のうち**上限のセマンティクス（切り捨て・既定 10・一次切断点）は本ステップで確定**しており、**バックストップの強制のみが申し送り 1 の解消を前提条件とする**（§9）。
>
> あわせて、この修正は**既存 elevate word の格納形を変える**（`reading_0..reading_{k-1}` に 1 値ずつ → `reading_0` に k 値）。既存ドキュメントの読み替えはできないため、**ID 方式変更・語数上限導入と同一の再構築に載せる**必要がある（§10 の申し送り 4）。

**却下した切断点**:

| 却下案 | 理由 |
| --- | --- |
| `SuggestItemSerializer` | `entity/SuggestItem.java:140` で ID が確定済みのため、ID と本文が乖離する |
| 新 API の入口のみ | 2 系統（parser 経路と elevate 経路）を別々に守ることになり、片側漏れが起きる |
| `ContentIndexingOperations.java:412` | 除外前の配列を切るため、除外語だけで枠を使い切って 0 語になりうる |

#### 既定値 10 の根拠

| 観点 | 内容 |
| --- | --- |
| 既存制限との関係 | `MAX_QUERY_TERM_NUM=5`（`util/SuggestUtil.java:63`）。ただし**セマンティクスが異なる**。`parseQuery` は超過時に `return new String[0]`（`:102`）で**全体を捨てる**＝拒否であって切り捨てではない。N=10 なら searchWord 経路が queryLog 経路より厳しくなることはない |
| 説明可能性 | `getMaxReadingNum` 既定 10（`converter/ReadingConverter.java:31-33`）と揃い、「**最大 10 語 × 各 10 通りの読み**」と一言で説明できる |
| 実質的な制約 | 1 ドキュメントあたりの term 数。N=10 なら最大 100 term/doc、N=200 なら 2000 term/doc。**ここが性能上の制約**であり、`total_fields.limit` は N の制約要因にならない（N=10 で 21 フィールド、N=50 でも 61 フィールド） |
| クエリ語数分布 | 実運用のサジェストクエリは 1〜4 語が支配的と見込まれる **[推測]** |

設定上限は **50**（設定値の妥当性チェックの上限）。

#### ★ プラン §3 ステップ 4-3 / §6.1 U3 の根拠文の訂正 [確認]

プラン `0003:194` / `:407` は次を根拠としている。

> 検索側（`SuggestQueryBuilder.java:84-86`）はクエリの語数分しか `reading_i` を引かないため、上限を設けても検索結果への実害はない

**この根拠づけは厳密には誤りである。** `request/suggest/SuggestQueryBuilder.java:112` が各 `reading_i` 節を **`must`（AND）** で連結するため、**上限 N を超える語数のクエリは必ず 0 件になる**（N を超える語に対応する `reading_i` がドキュメント側に存在しないため）。

**結論（切り捨ての採用）は変わらない**が、**この根拠文を 0002 にそのまま転記してはならない**。0002 には次の形で書く。

> 上限 N を設けると N 語を超えるサジェストクエリは 0 件になる（`SuggestQueryBuilder.java:112` の `must` 連結による）。ただし N=10 は実運用のクエリ語数分布を十分覆い、queryLog 経路の既存制限 `MAX_QUERY_TERM_NUM=5` より緩いため、実害は無視できる。

#### ID への波及（0002 §5-4・0003 へ申し送り）

切り捨てにより `String.join(" ", text)`（`entity/SuggestItem.java:116`）の入力が変わるため **ID が変わる**。ただし本設計は既に ID 方式を Base64 → ハッシュに変更する予定（P11 / U1）であり、旧世代インデックスとの共存は元から成立しない。したがって**同一の再構築に吸収される**。「語数上限の導入は ID 方式変更と同一の移行に載せる」ことを 0003 に明記する。

- **副次効果（好ましい）**: text を N 語に切ると Base64 長が `ID_MAX_LENGTH=445`（`util/SuggestUtil.java:68`）を超えにくくなり、**F-05 の「先頭一致の長文が同一 ID に衝突する」問題が実質的に発生しなくなる**。
- **副次効果（許容するコスト）**: 先頭 N 語が同一の異なる長文クエリが 1 ドキュメントに合流する。現行の Base64-445 切り詰めによる非決定的な衝突より**決定的で説明可能**である。

#### 「readings だけ切って text は残す」案を却下した理由

`readings.length ≠ text 語数` を恒久化してしまう。これは 0002 §5-3 が走査基準の単一化のために潰そうとしている不変条件そのものである（`0004-new-findings.md` §5.2）。また 200 語の text がそのままサジェスト候補としてユーザに返る（`request/suggest/SuggestResponseCreator.java:93`）。

#### 設定の受け口

`settings/SuggestSettings.getAsInt(key, default)`（`:276`）が既にある。`index/SuggestIndexer.java:180-185` と同じパターンで読み、`:192` の `new DefaultContentsParser()` に渡す形が既存構造に最も馴染む [提案]。具体的なキー名と `SuggestSettingsBuilder` への露出は **0001 §3-6 と整合を取る**。

### 5.3 決定 3: `index.mapping.total_fields.limit` — `suggest.json` に `100` を明示する

```jsonc
{ "index": { "mapping": { "total_fields": { "limit": 100 } } } }
```

**根拠**:

- 必要数は N=10 で **21 フィールド**（固定 11 ＋ `reading_0..9`）、設定上限 N=50 の最悪ケースでも **61**。100 は十分な余裕がありつつ既定 1000 の 1/10 であり、**暴走が「1000 本のゴミフィールドと肥大した cluster state」になる前に止まる**。
- T4-3 のとおり `_settings` API で **reindex なしに引き上げられる**ため、運用上の逃げ道がある。
- 決定 1・決定 2 と組み合わせた場合、これは load-bearing な制御ではなく **tripwire** である。暴走には「語数上限のバイパス」かつ「フィールド名が `reading_*` に合致」の**両方**が必要で、実質コードバグのみ。それでも安価な保険である。

**明示しない場合のリスク（＝現状）**: 既定 1000 が効き、到達すると `IllegalArgumentException: Limit of total fields [1000] has been exceeded`（T4-2 で実機確認）で**取り込みが失敗**する。到達条件は「解析可能な語を 989 語含む単一の検索クエリが 1 回投入されること」であり、bot やコピペ流入で現実に起こりうる **[推測]**。

なお **OpenSearch には Elasticsearch 8.x の `index.mapping.total_fields.ignore_dynamic_beyond_limit` に相当する緩和機構が存在しない** [確認]（`opensearch-3.7.0.jar` 全体を走査して当該設定名の出現 0 件）。したがって超過は必ずハードエラーになる。

### 5.4 決定 4: `dynamic` の厳格化は suggest 本体インデックスにのみ適用する（プラン ステップ 4-5 への回答）

| インデックス | 生成元リソース | 方針 |
| --- | --- | --- |
| `{index}.{timestamp}`（**suggest 本体**） | `(res) suggest_indices/suggest.json` / `(res) suggest_indices/suggest/mappings-default.json` | **`strict_allow_templates` 化する**（決定 1） |
| `fess_suggest`（設定ドキュメント） | `(res) suggest_indices/suggest_settings.json`（settings のみ。mapping ファイルは**存在しない**） | **`true` のまま維持** |
| `fess_suggest_array.{id}` / `_badword.{id}` / `_elevate.{id}` | `(res) suggest_indices/suggest_settings_array.json` ＋ `settings/ArraySettings.java:366-378` のコード内 mapping | **`true` のまま維持** |
| `fess_suggest_analyzer` | `(res) suggest_indices/suggest_analyzer.json` / `(res) suggest_indices/analyzer/mapping-default.json` | **現状維持** |

**この分岐の根拠（設計原則として 0002 に明文化する）**:

> **`dynamic` の厳格化は、インデックス再作成が設計に組み込まれているインデックスにのみ適用する。**

- **suggest 本体**は `createNextIndex()`（`Suggester.java:235`）→ `switchIndex()`（`:282`）の世代交代が設計に組み込まれており、**mapping は毎世代でリソース定義から作り直される**（`Suggester.java:239-251`）。厳格化してもバージョンアップで壊れない。
- **設定系**は `settings/ArraySettings.java:335-383`（`createMappingIfEmpty`）と `settings/AnalyzerSettings.java:130-142`（`init`）がいずれも「無ければ作る」だけで、**既存インデックスの mapping を更新する経路が存在しない** [確認]。ここを厳格化すると、**v15.7 で作られた strict mapping が、将来のバージョンで追加された新フィールドの書き込みを恒久的に拒否する**（アップグレード時のハードエラー）。
- 加えて `fess_suggest` は `settings/SuggestSettings.set(String, Object)`（`:315-332`）にキーのバリデーションが無く、**任意の文字列キー**が入る設計である（fess は `search_engine.type` を投入 — `(fess) helper/SuggestHelper.java:135`）。そもそも厳格化できない。

**[提案]（今回のスコープ外・後続の改善候補として記録のみ）**: `fess_suggest` には mapping ファイルが一切無いため、全キーが既定の dynamic mapping で `text` + `.keyword` の多重フィールドになり、フィールド数が実質 2 倍になっている。`match:"*"` → `keyword` のテンプレートを持つ mapping を新設する価値がある。ただし `search_engine.type` のようなドット付きキーが mapping 側でオブジェクトに展開される一方 `_source` にはリテラルキーとして残る二重性があり（読み出し `settings/AnalyzerSettings.java:310` は `_source` を参照）、明示 properties を書く場合は実機確認が要る **[要確認]**。**本決定（決定 4）の結論には影響しない。**

---

## 6. ステップ 5 への指示（0002 のどの節に何を書くか）

本書は経緯の記録であり、**0002 には結論のみを本文として書く**（V6: 根拠の非転記）。

| 0002 の節 | 書く内容 | 本書の該当 |
| --- | --- | --- |
| **§5-1（To-Be mapping）** | 決定 1 の mapping をそのまま本文にする（`score` 廃止 MIG-02・`excluded` 追加 MIG-13 と統合して**1 つの JSON** にする）。テンプレートに `match_mapping_type` を付けない理由を 1 行。**`reading_i` への null 書き込み禁止規則**を付帯規則として書く。`reading_0..9` の明示列挙が「正当性の要件ではなく最適化」である旨を明記（案 A との差）。**統合後の JSON（`excluded` 込みの最終形）のみを正とし、本書 §5.1 の骨格 JSON を引用・再掲しないこと** — 部分形が 2 つ存在すると、どちらが正か将来曖昧になる | §5.1 |
| **§5-1 または §5-2** | 語数上限 N の仕様（既定 10 / 設定可能 / 上限 50）と、**訂正済みの根拠文**（`must` 連結により N 語超は 0 件になるが実害は無視できる）。プランの旧根拠文は転記しない | §5.2 |
| **§5-2（index settings）** | 決定 3（`total_fields.limit: 100`）を `suggest.json` の To-Be に含める。**決定 4 により他 3 ファイルには入れない**。`fess_suggest` への mapping 付与は [提案] として記録のみ。**あわせて N と limit の連動を明示的な制約として書く**（下記） | §5.3 / §5.4 |
| **§5-2 または §5-1 冒頭** | 決定 4 の設計原則「`dynamic` の厳格化は、インデックス再作成が設計に組み込まれているインデックスにのみ適用する」を明文化し、4 インデックスの適用表を置く | §5.4 |
| **§5-3（マージ規則）** | 決定 2 のバックストップ（`SuggestItem` コンストラクタで text 語数 = `readings.length` ≤ N を強制）を走査基準の単一化と接続する。**N-1 により `ElevateWord.toSuggestItem` の `readings` セマンティクスをここで確定させる**（§10 の申し送り 1）。**`ElevateWord` を 1 語 × k 候補形に直すことがコンストラクタ不変条件の実装の前提条件である**ことを明記する（順序を逆にすると複数読みの elevate word 登録が全滅する — §5.2 の★） | §3.2 / §5.2 |
| **§5-4（ID 再設計）** | 語数上限の導入で ID が変わること、F-05 の衝突が実質的に消えること、ID ハッシュ化と同一の再構築に載せることを明記。**`ElevateWord` の格納形変更（`reading_0..k-1` → `reading_0` に k 値）も同じ再構築に載せる**対象である旨を併記 | §5.2 |

**§5-2 に書く連動の制約**（決定 2 と決定 3 が別々にドリフトするのを防ぐため、不変条件として明文化する）:

> **固定フィールド数 ＋ 語数設定上限 ＋ 余裕 ≤ `index.mapping.total_fields.limit`** を保つこと。現在の値では **11（固定）＋ 50（語数設定上限）＋ 余裕 ＝ 61 ≤ 100** である。**語数上限の設定可能上限を引き上げる場合は `total_fields.limit` も併せて見直す**こと。この 2 つの数値は独立に変更してはならない。

---

## 7. 既存資料への訂正（`0000-design-overview.md` §6 の訂正一覧へ引き継ぐ）

`0004-new-findings.md` §7 と同じ表形式で以下を追加する。**E 番号の採番はステップ 7 で確定する**（既存は E-01〜E-12。本書の 6 件は E-13〜E-18 相当）。

| 対象 | 誤っている記述 | 訂正内容 | 根拠 |
| --- | --- | --- | --- |
| 作業プラン `0003:193`（§3 ステップ 4-2 の推奨案） | 「トップレベル `dynamic:"strict"` ＋ `dynamic_templates` を `match:"reading_*"` に限定して keyword を許可」 | **OpenSearch では成立しない。`strict` は `dynamic_templates` を無効化する。** 正しくは `dynamic:"strict_allow_templates"`（OpenSearch 2.16+） | 本書 §4.3 の T2（実機） |
| 作業プラン `0003:194` / `:407`（§3 ステップ 4-3 / §6.1 U3 の根拠） | 「検索側はクエリの語数分しか `reading_i` を引かないため実害がない」 | `SuggestQueryBuilder.java:112` の `must` 連結により、**上限 N を超える語数のクエリは必ず 0 件になる**。結論（切り捨て採用）は不変だが根拠文は書き換えが必要 | 本書 §5.2 |
| `20260706_opensearch_reference/0005-schema-draft.md:89` の [要確認] | 「案 A は `MAX_READING_NUM` とスキーマの二重管理が生じる」 | `strict_allow_templates` を使えば明示列挙は最適化にすぎず、**二重管理は生じない**。この [要確認] は解消 | 本書 §5.1 |
| `docs/opensearch-verification-reference.md:119, :137` | 案 A(strict) 推奨・案 B（テンプレートを `reading_*` 限定）併記 | 案 B の前提が誤り。**案 D（`strict_allow_templates`）に読み替える** | 同上 |
| `0004-new-findings.md` §3 の想定範囲 | `reading_*` 増殖経路として `indexFromSearchWord` 経路のみを挙げている | **`entity/ElevateWord.java:143-148` が第 2 の無制限経路である**（N-1） | 本書 §3.2 |
| `modules/fess-suggest/README.md:7, 15, 34` | 「OpenSearch/Elasticsearch」「2.x+ recommended」 | Elasticsearch では動作しない（`org.opensearch.transport.client.Client` に依存 — `index/writer/SuggestIndexWriter.java:26-30`）。決定 1 の採用で **OpenSearch 2.16+ が最小要件**になる | 本書 §5.1 |

**提案書・`0005-schema-draft.md` 本体は書き換えていない**（P9）。訂正は `0000` §6 の訂正一覧に集約する。

---

## 8. スコープ外（本ステップで**やっていない**こと）

- **`docs/0002-datamodel-design.md` を書いていない。** 本書は経緯・根拠の記録であり、決定の本文化はステップ 5。§6 に指示だけを置いた。
- **`docs/0000-design-overview.md` の訂正一覧を更新していない。** ステップ 7 の担当であり、本書 §7 がその入力（`0005` §5 の申し送り 2 に対応）。
- **提案書・`0005-schema-draft.md`・`opensearch-verification-reference.md`・作業プラン・`0004` を書き換えていない**（P9）。
- **プロダクションコード・リソース JSON を変更していない**（P10）。決定 1〜3 の適用対象である `suggest.json` / `mappings-default.json` / `SuggestItemSerializer` / `DefaultContentsParser` / `SuggestItem` はいずれも無変更。実装は後続タスク。
- **実機検証コードをリポジトリに追加していない。** スクラッチパッド上の使い捨て。
- **ステップ 5-3 の判断を先取りしていない。** N-1 で判明した `ElevateWord.toSuggestItem` の `readings` セマンティクスは**ステップ 5-3 で確定させる**（§10 の 1）。
- **2.16 未満の OpenSearch を実機で検証していない。** T5 は 3.7.0 上で未知の値を与えた代理検証であり、2.16 未満での挙動は [推測] である。
- **性能測定を行っていない。** term 数（N=10 で最大 100 term/doc）の見積りは算術であって計測値ではない。

---

## 9. 完了条件の判定

作業プラン §3 ステップ 4 の完了条件: 「`dynamic` 方針・語数上限・`total_fields.limit` の 3 点が [要確認] を残さず確定している」。

| 項目 | 状態 |
| --- | --- |
| `dynamic` 方針 | **確定**（決定 1。`strict_allow_templates` ＋ `reading_*` テンプレート ＋ `reading_0..9` 明示列挙。実機検証済み） |
| 語数上限 | **確定**（決定 2。既定 10 / 設定可能 / 上限 50、一次切断点は `parseSearchWords` の語ループ）。ただし**バックストップの実装のみ前提条件つき** — 下記 |
| `total_fields.limit` | **確定**（決定 3。`suggest.json` に 100 を明示） |

→ **3 点すべてが [要確認] を残さず確定した。ステップ 5 に着手可能。**

**決定 2 の但し書き（§5.2 の★）**: 正確には「**上限のセマンティクス（切り捨て方式・既定 10・設定上限 50・一次切断点）は本ステップで確定**、**バックストップ（`SuggestItem` コンストラクタでの不変条件の強制）はステップ 5-3 での申し送り 1 の解消が前提条件**」である。現行の `ElevateWord.toSuggestItem` は不変条件を恒常的に違反しているため、`ElevateWord` 側の修正より先にコンストラクタで強制すると複数読みの elevate word 登録が全滅する。**この前提条件は本ステップの完了条件（`dynamic` 方針・語数上限・`total_fields.limit` の 3 点）を損なわない** — 上限の値と方式は確定しており、残るのは強制箇所の実装順序だけである。

本書に残る [要確認] は次の 2 件のみであり、**いずれも上記 3 点には含まれず、決定 1〜4 の結論にも影響しない**。

1. `ElevateWord` の読みセマンティクス（§10 の 1。ステップ 5-3 で解消）。**決定 2 のバックストップ実装の前提条件でもある**（上記）
2. `fess_suggest` のドット付きキーの mapping 展開（§5.4 の [提案] に付随。今回スコープ外）

---

## 10. 未確定事項・申し送り

| # | 事項 | 引き継ぎ先 |
| --- | --- | --- |
| **1** | **`ElevateWord.toSuggestItem` の `readings` セマンティクスの確定** [要確認]。`entity/ElevateWord.java:144-145` は「読み候補 k 個 → `reading_0..k-1`」だが、`(fess) helper/SuggestHelper.java:466-471` の入力仕様からは管理者の意図が「1 語に対する k 個の代替読み」なのか「k 語それぞれの読み」なのか判別できない。**前者だとすれば `reading_1` 以降は `SuggestQueryBuilder` から引かれない死んだデータ**であり、正しい形は `new String[][] { allReadings }`（1 語 × k 候補）になる | **ステップ 5-3**（0002 §5-3）。**決定 2 のバックストップの前提条件**であり、これが解消されるまでコンストラクタでの不変条件の強制は実装できない（§5.2 の★ / §9） |
| **2** | **決定 1 の mapping・付帯規則の本文化** | ステップ 5-1（§6 の表） |
| **3** | **決定 3 の `suggest.json` 反映と、他 3 ファイルに入れない旨の明記** | ステップ 5-2（§6 の表） |
| **4** | **同一の再構築に載せる変更の束**。①語数上限導入で **ID が変わる**（§5.2）。②申し送り 1 の解消に伴う `ElevateWord` の修正で**既存 elevate word の格納形が変わる**（`reading_0..reading_{k-1}` に 1 値ずつ → `reading_0` に k 値）。**いずれも既存ドキュメントの読み替えができない**ため、ID ハッシュ化（P11 / U1）と**同一の全件再構築＋エイリアス切替**に束ねる | ステップ 5-4 / **ステップ 6**（フェーズ内のスキーマ変更を 1 回の再構築に束ねるルールに合流させる） |
| **5** | **最小 OpenSearch バージョンが 2.16 に上がる**。AWS OpenSearch Service で 2.16 未満を使う利用者は初回インデックス作成で失敗する | **ステップ 6**（移行前提として明記。利用者への影響確認を含む） |
| **6** | **`total_fields.limit` は `_settings` API で運用中に引き上げ可能**（reindex 不要、T4-3） | ステップ 6（運用手順に記載） |
| **7** | **`0000` §6 訂正一覧への 6 件追加と E 番号の採番** | ステップ 7（`0000` §8.1 の 7-2） |
| **8** | **README のバージョン記述**（`README.md:7, 15, 34`）の修正 | MIG-25（`0000` §7 の 25-a）に本書 §7 の内容を合流させる |
| **9** | **`fess_suggest` への mapping 新設** [提案]（スコープ外） | 本タスク完了後の改善候補。ドット付きキーの mapping 展開の実機確認が前提 [要確認] |

---

## 11. 参照した一次情報

**プロダクションコード / リソース**（`file:line` は §3・§5 に記載）:

- `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`: `entity/SuggestItem.java` / `entity/SuggestItemSerializer.java` / `entity/ElevateWord.java` / `index/contents/DefaultContentsParser.java` / `index/operations/ContentIndexingOperations.java` / `index/SuggestIndexer.java` / `index/writer/SuggestIndexWriter.java` / `request/suggest/SuggestQueryBuilder.java` / `request/popularwords/PopularWordsRequest.java` / `converter/ReadingConverter.java` / `converter/ReadingConverterChain.java` / `settings/SuggestSettings.java` / `settings/ArraySettings.java` / `settings/AnalyzerSettings.java` / `util/SuggestUtil.java` / `Suggester.java`
- `modules/fess-suggest/src/main/resources/suggest_indices/`（`suggest.json` / `suggest/mappings-default.json` ほか 4 ファイル）
- `modules/fess/src/main/java/org/codelibs/fess/helper/SuggestHelper.java`、`modules/fess/src/main/resources/suggest_indices/_aws/suggest_analyzer.json`
- `modules/fess-suggest/pom.xml:36-40`（parent `fess-parent:15.7.0`）、`~/.m2/.../fess-parent-15.7.0.pom:60-61`（`opensearch.version=3.7.0` / `opensearch.runner.version=3.7.0.0`）
- `modules/fess-suggest/README.md:7, 15, 34`

**実機**: OpenSearch 3.7.0（`opensearch-runner 3.7.0.0` 埋め込み 1 ノード）。§4 の T1〜T6。加えて `opensearch-3.7.0.jar` の走査により `org/opensearch/index/mapper/ObjectMapper$TypeParser.class` に `strict_allow_templates` / `false_allow_templates` が存在すること、`ignore_dynamic_beyond_limit` が存在しないことを確認。

**外部一次情報**:

- OpenSearch Documentation, "Dynamic mapping parameter" — https://docs.opensearch.org/latest/mappings/mapping-parameters/dynamic/
- opensearch-project/OpenSearch PR #14555 / #14737（`strict_allow_templates` の追加。**2.16.0 で導入**） — https://github.com/opensearch-project/OpenSearch/pull/14737
- opensearch-project/OpenSearch Issue #11276（`dynamic_templates` は許可しつつ他の動的マッピングを禁止したい、という要求の原典） — https://github.com/opensearch-project/OpenSearch/issues/11276

**タスク内文書**:

- `0003-design-document-work-plan.md` §3 ステップ 4（`:186-198`）・ステップ 5（`:200-234`）・§5（V1〜V11）・§6.1 U3（`:407`）
- `0004-new-findings.md` §3（F-01〜F-04）・§6（T-5）・§7・§8
- `0005-design-overview-skeleton.md` §5（申し送り 2）／ `0006-step2-review-reflection.md`（接頭辞台帳・番号繰り下がり）／ `0008-step3-review-reflection.md`（体裁）
- `20260706_opensearch_reference/0005-schema-draft.md:78-96`（案 A/B/C の比較）
- `docs/opensearch-verification-reference.md:119, :137`
