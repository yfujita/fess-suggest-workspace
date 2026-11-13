# 0010 ステップ 5: `docs/0002-datamodel-design.md` の執筆

> 対象タスク: `20260706_design_document` ／ 実施日: 2026-08-13
> 対象ステップ: 作業プラン `0003-design-document-work-plan.md` §3 **ステップ 5**（5-1〜5-6）
> 前提: ステップ 4（`0009-reading-field-policy.md`）完了
> 凡例: `docs/0000-design-overview.md` §3.1 に同じ

---

## 1. 実施サマリ

| 項目 | 内容 |
| --- | --- |
| **成果物** | `docs/0002-datamodel-design.md`（新規。48,278 文字 / 81,478 バイト） |
| **決定** | **DM-1〜DM-15**（同書 §0 のサマリ表） |
| **消化した [要確認]** | `0009` §10 申し送り 1（`ElevateWord` の読みセマンティクス）。**ステップ 4 が残した唯一のステップ 5 向け [要確認] を解消した** |
| **新規発見** | **N-3**（`number_of_replicas` の削除対象は 4 ファイルではなく 7 ファイル）、**N-4**（`SuggestQueryBuilder` は語内 OR・語間 AND）、**N-5**（`SuggestItem.text` は `String[]` ではなく結合済み `String`）、**N-6**（ID 衝突がバッチ内マージで無言のデータ消失を起こす）、**N-7**（`parallel` フラグは F-10 の直接原因ではない） |
| **既存資料への訂正** | **6 件**（同書 付録 A）。うち 1 件は**ステップ 4 の成果物 `0009` 自身の訂正**である |
| **コード変更** | **なし**（P10） |

### 1.1 本ステップの最重要成果

> **ステップ 4 が「1 語 × k 候補形（`new String[][] { allReadings }`）が正しい形」と推定した `ElevateWord` の修正案は、複数語の elevate word で成立しない。** 正しい規約は**位置対応（第 1 次元 ＝ 語位置）**であり、W == 1 のときだけ全読み候補を `reading_0` に集約する。

この訂正は `0009` §5.2 の★（バックストップの前提条件）と §10 申し送り 1 の両方に及ぶ。詳細は §3。

### 1.2 本ステップが採った構成上の判断

**5 つの不変条件（INV-1〜INV-5）を先に置き、以降のすべての決定をそのいずれかを成立させるものとして書いた**（`0002` §1）。

作業プランは 5-1〜5-5 を並列の作業項目として並べているが、実際には ISS-05（`reading_i` 脱落）・F-01（上限なし）・F-04（全置換による消滅）・F-05（ID 衝突）はいずれも「同じ数個の条件が成立していない」ことの別々の症状である。症状ごとに対処を書くと、`0001` §3.4 が要求する「走査基準が実装内部の 1 箇所に閉じる」形にならない。**不変条件を先に定義したことで、F-04 が §5.6 で「INV-1 の確立により構造的に解消される」と書けるようになった**（個別の対処が不要になった）。

---

## 2. コード追検証（3 系統を並行実施）

設計判断の前に、3 つの論点についてコードを実読した。**いずれも読むだけで、変更はしていない。**

| 系統 | 論点 | 結果 |
| --- | --- | --- |
| A | `ElevateWord` の読みセマンティクス | §3 |
| B | ID 生成方式・逆引き依存・外部露出 | §4 |
| C | マージ規則の現行実装の全体像 | §5 |

加えて、mapping / settings のリソースファイルと `Suggester` の世代交代経路を直接読んだ（§6）。

---

## 3. 系統 A: `ElevateWord` の読みセマンティクスの確定 [確認]

### 3.1 `0009` の設問

`0009` §10 申し送り 1 は次を [要確認] として残していた。

> `(fess) helper/SuggestHelper.java:466-471` の入力仕様からは管理者の意図が「1 語に対する k 個の代替読み」なのか「k 語それぞれの読み」なのか判別できない。**前者だとすれば `reading_1` 以降は `SuggestQueryBuilder` から引かれない死んだデータ**であり、正しい形は `new String[][] { allReadings }`（1 語 × k 候補）になる

### 3.2 判定: 後者（位置対応）が正である

決め手は **読み未入力時のフォールバック**である（`(fess) helper/SuggestHelper.java:464-487`）。

```java
if (StringUtil.isBlank(reading)) {
    readings = word.replace("　", TEXT_SEP).replaceAll(TEXT_SEP + "+", TEXT_SEP).split(TEXT_SEP);   // :468
} else {
    readings = reading.replace(...).split(TEXT_SEP);                                                // :470
}
```

**読みが未入力なら「単語そのものを空白分割したもの」を読みとして使う。** この既定は常に「読みトークン数 k ＝ 語数 W」を作る。**入力仕様が位置対応を前提としている**ことの直接の証拠である。

検索側とも整合する。`request/suggest/SuggestQueryBuilder.java` は、クエリ語のインデックス `i` に対して `reading_i` を引き（`:86`）、**同一語の読み候補を `should`（OR、`minimumShouldMatch(1)`）で束ね**（`:101-108`）、**語どうしを `must`（AND）で連結する**（`:112`）。すなわち:

- 「1 つの `reading_i` フィールドに複数値」＝ **同一語に対する代替読み**（OR で引かれる）
- 「複数のフィールドに 1 値ずつ」＝ **語の並び**（AND で引かれる）

通常経路（`index/contents/DefaultContentsParser.java:86-107`、`:141`、`:185-195`）も一貫して「第 1 次元＝語位置、第 2 次元＝読み候補」で `String[][]` を組み立てている。`getMaxReadingNum`（既定 10、`converter/ReadingConverter.java:31-33`）が制限するのは**第 2 次元**であり、F-02 の内容と一致する。

### 3.3 `0009` の修正案が成立しない理由

`entity/ElevateWord.java:144-146` は `text` を `new String[] { this.getElevateWord() }` の 1 要素配列にするが、**`entity/SuggestItem.java:116` が空白で結合するため、`elevateWord` が「東京 タワー」なら語数 W は 2 になる**（N-5。§7.1）。

`allReadings` を 1 スロットに入れると:

- `readings.length = 1 ≠ W = 2` となり、`0009` が守ろうとした不変条件を**別の形で破る**。
- 2 語のフレーズを 2 語のクエリで引くには `reading_0` と `reading_1` の両方が要る（`SuggestQueryBuilder.java:112` の AND）ため、**検索でヒットしなくなる**。

また `0009` §5.2 の★は「読みを 2 つ以上持つ elevate word はすべて不変条件を違反する」としているが、正確には「**k ≠ W のときに違反する**」である。W=1 の単語に 2 つの読みを与えれば違反するが、W=2 のフレーズに 2 つの読みを与えれば違反しない。

### 3.4 採った規則

`0002` §5.4 に本文として書いた 4 分岐（W==1 / k==W / k>W / k<W）。**W == 1 を特別扱いする**のは、位置対応の解が一意に定まらない唯一のケースだからであり、かつ `SuggestQueryBuilder.java:101-108` の OR 性質により全候補を活かせるためである。

### 3.5 副次的に判明したこと [確認]

- **現行では「単語＋読み 2 つ」の elevate word が人気語から除外される。** `request/popularwords/PopularWordsRequest.java:213` が `mustNot(existsQuery("reading_1"))` で単一語のみを人気語として扱うため。新規則ではこれが解消する。
- **既存テストが現行の不具合を仕様として固定していた。** `ElevateWordTest.testToSuggestItemWithCompleteData`（`:198-244`）と `testMultipleReadingsConversion`（`:399-417`）が「k 個の読み → `readings.length == k` の各 1 要素配列」を明示的に assert している。複数読みの検索到達性を検証するテストは fess-suggest / fess のどちらにも存在しない。
- 管理画面フォーム（`(fess) app/web/admin/elevateword/CreateForm.java:46-51`）・ラベル（`fess_label_ja.properties:839` =「読み」）・CSV 仕様（`(fess) app/service/ElevateWordService.java:230-236`）・設定インデックスの mapping（`(fess) src/main/config/es/fess_config_elevate_word.json` の `reading` は array 指定なしの単一 `keyword`）は、いずれも 2 解釈を区別していない。**判別可能な唯一の手がかりがフォールバック（`:468`）だった。**

---

## 4. 系統 B: ID 生成方式 [確認]

### 4.1 現行方式の衝突条件を精密化した

`util/SuggestUtil.java:66,68,84-90` は標準アルファベット Base64（パディングあり）＋ `substring(0, 445)`。算術で次を導出した。

- Base64 の出力長 ＝ `4 × ceil(n/3)`。445 を超えるのは **n ≥ 334 バイト**のとき。**n ≤ 333 では切り詰めも衝突も起きない。**
- 445 文字 ＝ 完全な 4 文字グループ 111 個（先頭 333 バイトを過不足なく符号化）＋ 112 番目グループの先頭 1 文字。この 1 文字は **334 バイト目の上位 6 ビットのみ**を表す。
- ⇒ 衝突条件は「**先頭 333 バイト完全一致 ＋ 334 バイト目の上位 6 ビット一致**」であり、**335 バイト目以降は長さも内容も無関係**。

**F-05 の「先頭が一致する長文が衝突する」は結論として正しいが、条件が緩い方向に不正確だった**ため訂正対象とした（`0002` 付録 A）。また「333 バイト」は文字数ではなく、**日本語なら約 111 文字**である点を本文に明記した。

### 4.2 衝突が引き起こす具体的破壊（N-6）[確認]

`index/writer/SuggestWriter.java:76-102`（`mergeItems`）は**バッチ内の重複を ID の一致だけで判定**しており、text の一致を確認していない。したがって 334 バイト以上の異なる text が同一バッチで衝突すると、**2 つの別の語が「同一アイテム」として無言でマージされ、`entity/SuggestItemMerger.java:67` が item1 の text を採るため一方の text が失われる**。例外もログも出ない。

**ID ハッシュ化の動機として、これを `0002` §4.3 に本文で書いた。** 既存資料は衝突の存在までしか書いていない。

### 4.3 可逆性の喪失は影響しない [確認]

リポジトリ全体（fess-suggest / fess の両モジュール、テスト・リソース・スクリプト）を走査した結果:

- **ID をデコードして text を復元している箇所は 0 件。** `Base64.getDecoder()` 相当の呼び出しは fess-suggest モジュールに 1 件もない。fess 本体側の Base64 デコードはロール ID・ログファイル名・JWT など suggest と無関係な用途のみ。
- **`SuggestItem.getId()` の外部露出も 0 件。** `(fess) api/v2/handlers/SuggestWordsHandler.java:107-113` は `getText()` / `getTags()` のみ、`(fess) helper/PopularWordHelper.java:120` は `getText()` のみをレスポンスに詰める。管理画面にも ID 表示はない。

作業プラン §6.2 のリスク「ID のハッシュ化で逆引きができなくなる」は、**コード上は解消**した（手作業の運用手順への依存は依然として確認不能であり、この点は変わらない）。

### 4.4 realtime の確認方法を実機（バイトコード）に格上げした

`0003` の申し送り 1 は「`setRealtime(false)` 指定がないため既定 realtime」としていたが、**既定値そのものは既存資料のどこでも確認されていなかった**。`~/.m2/.../opensearch-3.7.0.jar` を展開し `javap -c -p` で確認した。

- `org/opensearch/action/get/GetRequest`: 既定コンストラクタが `realtime = true`（`iconst_1; putfield realtime`）
- `org/opensearch/action/get/MultiGetRequest`: 同上

⇒ **MIG-15 第 1 段（multiGet 化）でもマージ規則は不変**であることを [推測] ではなく [確認] として書けた（`0002` §4.5）。

### 4.5 壊れる既存テストを特定した

| 維持できるもの | 壊れるもの |
| --- | --- |
| `SuggestItemBoundaryTest.test_getId_sameTextSameId` / `_differentTextDifferentId` / `_multiWordOrder`（`:538-576`）— 意味論的な不変条件であり、ハッシュ化後も成立すべき | `SuggestUtilTest.testCreateSuggestTextId`（`:99-117`）・`testCreateSuggestTextIdWithLongText`（`:120-130`）・`testCreateSuggestTextIdBoundaryExactly445`（`:490-502`）・`testCreateSuggestTextIdBoundaryJustUnder445`（`:505-516`）— Base64 生値との完全一致 / 長さ 445 という**実装詳細**に依存 |

---

## 5. 系統 C: マージ規則の現行実装 [確認]

### 5.1 走査基準が 3 通りあることの確定

| 実装 | 走査基準 | 行 |
| --- | --- | --- |
| `entity/SuggestItemMerger.merge` | `item1.getText().split(" ").length`（＝ item1 の W） | `:70-74` |
| `entity/SuggestItemSerializer.toSource` / `toUpdatedSource` | `item.getReadings().length`（新 item 側） | `:59-63` / `:146-158` |
| 同 `fromSource` | 既存ドキュメント側の `reading_i` の存在（無限ループ） | `:87-95` |

加えて **`toUpdatedSource` は既存 source をコピーせず新規 `HashMap` を構築する**（`:143`）。`OpType.INDEX` の全置換（`index/writer/SuggestIndexWriter.java:59,64`）と合わさり、新 item が言及しないキーが消える。これが F-04 の実体である。

### 5.2 F-04 が実際に発生する経路を確定した

| 経路 | 成否 |
| --- | --- |
| 作業プランの例（「2 語で登録した doc に 1 語が来る」） | **成立しない**（E-07 で訂正済み。ID が違うため別ドキュメント） |
| **経路 A: elevate word の読み件数を減らして再登録** | **成立する。** `restoreElevateWord`（`WordManagementOperations.java:140-157`）が全件再適用するため設定変更のたびに再現しうる |
| **経路 B: ID 切り詰めによる衝突**（§4.2） | **成立する**（稀） |

**経路 A は INV-1 の確立で、経路 B は ID ハッシュ化で消える。** F-04 のための個別の対処が不要になった（`0002` §5.6 / DM-13）。

### 5.3 `userBoost` の合成規則の決定（DM-11）

**代替案を 3 つ比較し、いずれも却下したうえで新しい案を採った。**

| 案 | 判定 |
| --- | --- |
| `max(existing, incoming)` | **却下**。管理者が boost を 5.0 → 2.0 に**引き下げられなくなる** |
| 既存が既定値（1）でない限り保持 | **却下**。同上 |
| `kinds` に USER を含む incoming を優先 | **却下**。動作は同じだが、`kinds` は集合和で蓄積されるため「incoming が USER を含むか」と「既存が USER を含むか」が混同されやすい |
| **`userBoost` に「指定あり／なし」を導入し、指定ありの incoming のみが上書きする** | **採用** |

**採用案は MIG-04（丸め撤廃）と不可分である。** 現行は `index/contents/DefaultContentsParser.java:107-108,:144` が `userBoost = -1` というセンチネルを渡し、`entity/SuggestItem.java:131-135` の丸め（1 以下なら 1）で実質 1 にしている。**丸めを撤廃するとセンチネル `-1` がそのまま格納されてしまうため、「指定なし」という表現の導入なしには MIG-04 を実施できない。** この依存関係は既存資料のどこにも書かれていなかった。

### 5.4 `@timestamp` に max を採った

現行は無条件に新 item の値（`SuggestItemMerger.java:87` / `SuggestItemSerializer.java:183`）。実際には `SuggestItem.java:138` がコンストラクタで `now()` を入れるため後退は起きにくいが、**「後退しないこと」がコードの都合ではなく規則として保証されている状態にする**ため max を採った。

### 5.5 bad word の現行実装を 2 系統として整理した [確認]

| 仕組み | 実装 | 本設計での扱い |
| --- | --- | --- |
| ① 物理削除（`apply=true`） | `WordManagementOperations.java:77-84` の wildcard `deleteByQuery` | **廃止**（C-02） |
| ② 取り込み時フィルタ | `IndexingOperations.java:78` ＋ `SuggestItem.isBadWord`（`:455-462`） | **維持**（`BadWordPolicy` へ移設 — `0001` §3.5） |

`deleteBadWord`（`WordManagementOperations.java:91-93`）は設定から語を削除するだけで**削除済みドキュメントを復元しない**。C-02 が「即時・可逆な論理除外」を選んだ理由がここにある。

### 5.6 F-10 の成立条件を訂正した（N-7）[確認]

F-10 は `index/SuggestIndexer.java:185` の `parallel` フラグを根拠に「並行実行時にロストアップデートが起きうる」としているが、**`parallel` は直接原因ではない**。

- `parallel` の実効箇所は `index/operations/ContentIndexingOperations.java:138-139` と `:256-257` であり、**パース処理のストリームを並列化するだけ**。書き込みは `:147` / `:275` で 1 回だけ呼ばれ、`index/writer/SuggestWriter.java:80-99` のループは逐次実行される。**1 回の呼び出しの中では競合しない。**
- 実際の成立条件は「**異なる呼び出し元が同時に書き込み系メソッドを呼び、同一 ID を含むバッチが競合すること**」。楽観ロックの欠如が唯一の根本原因である。

**F-10 の結論（`setIfSeqNo`/`setIfPrimaryTerm` が無い・multiGet では解決しない・MIG-15 第 2 段で扱う）は不変。** 根拠づけのみ訂正した。

---

## 6. mapping / settings 側の実査

### 6.1 N-3: `number_of_replicas` の削除対象は 7 ファイル [確認]

C-14（原典は `0001-unresolved-items-resolution.md` §2.14）は「4 ファイル」としているが、**fess 本体側に 3 ファイルの見落とし**があった。

| # | ファイル |
| --- | --- |
| 1〜4 | `(res) suggest_indices/` の `suggest.json` / `suggest_settings.json` / `suggest_settings_array.json` / `suggest_analyzer.json`（各 `:5`） |
| **5〜7** | **`(fess res) suggest_indices/suggest_analyzer.json` / `_aws/suggest_analyzer.json` / `_cloud/suggest_analyzer.json`（各 `:5`）** |

`settings/AnalyzerSettings.java:309-317`（`getSuggestAnalyzerPath`）が `search_engine.type` により `suggest_indices/_{type}/suggest_analyzer.json` を優先し、無ければ `suggest_indices/suggest_analyzer.json` にフォールバックする。**いずれもクラスパス解決**（`:295`）であるため、fess 本体側の同名リソースが fess-suggest 側を遮蔽しうる。どちらが優先されるかに関わらず、7 ファイルすべてを直さなければ削除は完了しない。

**このために `(fess res)` というパス短縮表記を新設した**（`0000` §3.1 は無印 / `(fess)` / `(res)` の 3 種しか定めていない）。

### 6.2 決定 4 の根拠をコードで裏づけた

`0009` 決定 4（`dynamic` の厳格化は suggest 本体のみ）の根拠を、`Suggester` の世代交代経路で確認した。

- `createNextIndex()`（`Suggester.java:235`）が `getDefaultMappings()`（`:239` → `:467-474`）と `getDefaultIndexSettings()`（`:240` → `:476-484`）でリソースから読み直し、`prepareCreate`（`:249`）で新インデックスを作る。**mapping は毎世代で作り直される。**
- 一方、設定系（`ArraySettings.java:335-383` / `AnalyzerSettings.java:130-142`）は「無ければ作る」だけで既存 mapping を更新する経路がない。

### 6.3 N-4: `SuggestQueryBuilder` は語内 OR・語間 AND [確認]

§3.2 のとおり。**この構造は `0009` §5.2 が「N 語超のクエリは 0 件になる」と述べた根拠（`:112` の `must`）と同じものだが、`should` 側（`:101-108`）の意味は既存資料のどこにも書かれていなかった。** `ElevateWord` の判定（§3）はこの `should` 側の性質に依存している。

---

## 7. 既存資料への訂正（`0000` §6 の訂正一覧へ引き継ぐ）

**E 番号の採番はステップ 7 で確定する**（既存は E-01〜E-12。`0009` §7 が 6 件を提出済みなので、本書の 6 件はその後続になる）。一覧は `docs/0002-datamodel-design.md` **付録 A** にある。要約:

| # | 対象 | 訂正の要旨 |
| --- | --- | --- |
| 1 | `0001-unresolved-items-resolution.md` §2.14（C-14） | 削除対象は 4 ファイルではなく **7 ファイル** |
| 2 | `0004-new-findings.md` §3 F-10 | `parallel` はロストアップデートの直接原因ではない（結論は不変） |
| 3 | `0004-new-findings.md` §3 F-05 | 衝突条件は「先頭 333 バイト ＋ 334 バイト目の上位 6 ビット」。日本語なら約 111 文字 |
| 4 | **`0009-reading-field-policy.md` §5.2 の★ / §10 申し送り 1** | **修正形 `new String[][] { allReadings }` は W > 1 で成立しない**。違反条件は「k ≠ W」であって「読みが複数」ではない |
| 5 | `0000` §3.1（パス短縮表記） | `(fess res)` を追加する必要がある |
| 6 | `0000` §3.4（番号台帳） | `D`（`0001`）と `DM`（`0002`）が未登録。同節は「本表に行を追加してから使う」と定めている |

### 7.1 N-5: `SuggestItem.text` は `String[]` ではない [確認]

**訂正一覧には載せない**（誤りを述べた資料が存在しないため）が、**既存資料が誰も明示していなかった前提**であり、§3.3 の判定の土台になっている。

`entity/SuggestItem` のフィールド `text` は **`String`**（`:71`）である。コンストラクタは `String[] text` を受け取るが `:116` で `String.join(" ", text)` により即座に結合し、配列長は失われる。したがって「text の語数」には「配列長」と「W ＝ `getText().split(" ").length`」の 2 つがあり、**一致するとは限らない**。`0002` §1.1 に独立した節として書いた。

**`0009` §5.2 の★が誤ったのは、この区別をせず「text 語数 1」を配列長として読んだためである。**

---

## 8. スコープ外（本ステップで**やっていない**こと）

- **プロダクションコード・リソース JSON を変更していない**（P10）。`0002` が To-Be を定めた `suggest.json` / `mappings-default.json` / `SuggestItemSerializer` / `SuggestItem` / `ElevateWord` / `DefaultContentsParser` / `FieldNames` はいずれも無変更。実装は後続タスク。
- **`docs/0000-design-overview.md` を更新していない。** §4.2 の節番号（暫定）・§6 の訂正一覧・§8.2 の着地確認表はいずれもステップ 7 の担当であり、本書 §7 と `0002` 付録 A がその入力である。
- **`docs/0003-migration-ops-design.md` を書いていない**（ステップ 6）。
- **過去タスクの文書・提案書・`0009` を書き換えていない**（P9）。訂正は `0002` 付録 A に集約した。
- **実機検証を行っていない。** `0009` が行った OpenSearch 3.7.0 の実機検証（T1〜T6）の結果をそのまま採用した。本ステップが実機に触れたのは `opensearch-3.7.0.jar` のバイトコード確認（§4.4）のみである。
- **性能測定を行っていない**（C-04）。term 数の見積り（N=10 で最大 100 term/doc）は算術であって計測値ではない。
- **テストを書いていない。** `0002` §7 はテスト**仕様**であり、実装は後続タスク（P10）。
- **F-10 を解消していない**（P12）。`0002` §4.6 と K-1 に既知の制約として記録した。

---

## 9. 完了条件の判定

作業プラン §3 ステップ 5 の各節の完了条件と照合する。

| 節 | 完了条件 | 判定 |
| --- | --- | --- |
| **5-1** | そのまま投入できる JSON として完成し、現行 `mappings-default.json` との差分表が付いている | **pass**（`0002` §2.1 / §2.6 の M-1〜M-8） |
| **5-2** | 4 ファイルそれぞれの To-Be が示されている | **pass**（`0002` §3.3）。ただし**対象は 7 ファイルに増えた**（§6.1） |
| **5-3** | 全フィールドについて合成規則が 1 つに決まり、既存テストで現行と同一結果になるものと意図的に変える差分が区別されている | **pass**（`0002` §5.3 の全フィールド表 ＋ §7.1 の既存テスト区別表） |
| **5-4** | 新 ID 方式が確定し（切り詰めロジックが存在しない／構成要素は `text` のみ）、③ の解消が 5-3 に委ねられていることとその根拠が本文に残り、申し送り 1・2 が消化済みと機械的に判定でき、F-04 / F-10 が既知の制約として本文に現れている | **pass**（`0002` §4.1 / §4.2 の引用ブロック / §4.5 / §7.2 の T-1・T-2 / §5.6 / §4.6 ＋ K-1） |
| **5-5** | （完了条件の明示なし。作業内容は否定形フィルタ必須ルールとレイテンシ計測の申し送り） | **pass**（`0002` §6.2 / §6.4） |
| **5-6** | レビュー観点 6 項目 | **pass**（`0002` §10 の自己レビュー表）。ただし **V6（分量）のみ「注意」判定**で、最終判断をステップ 7 の 7-5 に委ねた |

### 9.1 V10 / V11 の判定

| # | 検証項目 | 判定 |
| --- | --- | --- |
| **V10** | ID 再設計（P11 / P13） | **pass**。①② がハッシュ化で解消（`0002` §4.1）、切り詰めロジックが新方式に存在しない、構成要素は `text` のみ（§4.2）、③ は §5.3 の `userBoost` 合成規則で解消、KEEP-03 との衝突を避けた根拠が §4.2 の引用ブロックに 1 段落として残っている。0003 側（移行手順・ロールバック条件）は**ステップ 6 の担当** |
| **V11** | 既知の制約の明記（P12） | **pass**。F-04 は `0002` §5.6、F-10 は §4.6 と K-1。F-10 に「multiGet では解決しない」「MIG-15 第 2 段で一括して扱う」を併記済み |

### 9.2 分量（V6）の実測

| 文書 | 文字数 | バイト数 | 提案書（60,700 文字）比 |
| --- | --- | --- | --- |
| `0001-api-design.md`（第 2 版） | 76,492 | 116,400 | 126.0% |
| **`0002-datamodel-design.md`（初版）** | **48,278** | **81,478** | **79.5%** |

**目安（1/5 ＝ 20% 前後）は超えているが、`0001` より小さい。** 提案書の内容は転記していない。判定はステップ 7 の 7-5 に委ねる（`0000` §8.1）。

---

## 10. 未確定事項・申し送り

**`0002` §9 に 10 件として記載した。** 引き継ぎ先ごとの要約:

| 引き継ぎ先 | 件数 | 内容 |
| --- | --- | --- |
| **ステップ 6（`0003`）** | 3 | ①同一再構築に束ねる 4 変更（ID ハッシュ化 / 語数上限 / `ElevateWord` 格納形 / mapping 変更）と、旧世代共存・部分移行が成立しないこと ②最小 OpenSearch バージョンが 2.16 に上がること ③`total_fields.limit` は `_settings` API で運用中に引き上げ可能であること |
| **ステップ 7（`0000`）** | 4 | ④番号台帳に `D` / `DM` の行を追加 ⑤パス短縮表記に `(fess res)` を追加 ⑥訂正一覧に本書 §7 の 6 件を追加し E 番号を採番 ⑦`0009` §5.2 の★をどう扱うか（訂正一覧に載せるか `0009` に追記するか）の判断 |
| **後続タスク** | 3 | ⑧MIG-13 の除外フィルタのレイテンシ計測 ⑨「1 語に対する代替読み」を複数語フレーズに指定する方法が無いこと（fess 側の入力仕様拡張） ⑩`FieldNames.EXCLUDED` の追加と `userBoost` の「指定あり／なし」の型表現（実装判断） |

### 10.1 ステップ 6 が本書から受け取るべき最重要事項

> **`0002` §4.7 の「同一の再構築に束ねる 4 変更」を、1 回の全件再構築＋エイリアス切替に載せる。** 部分移行・段階適用の選択肢は存在しない。

作業プラン §3 ステップ 6 は「二重エイリアス切替手順」を新規書き起こしとしているが、**本書の決定により切替は「選べる方式の 1 つ」ではなく「唯一の方式」になった**。ロールバック条件も、旧インデックスを削除する前に戻せる範囲に限られる。

---

## 11. 参照した一次情報

### 11.1 プロダクションコード / リソース

無印 ＝ `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`、`(fess)` ＝ `modules/fess/src/main/java/org/codelibs/fess/`、`(res)` ＝ `modules/fess-suggest/src/main/resources/`、`(fess res)` ＝ `modules/fess/src/main/resources/`。

- **ID**: `util/SuggestUtil.java` ／ `entity/SuggestItem.java` ／ `entity/SuggestItemSerializer.java` ／ `index/operations/WordManagementOperations.java` ／ `index/writer/SuggestIndexWriter.java` ／ `index/writer/SuggestWriter.java` ／ `constants/SuggestConstants.java`
- **マージ**: `entity/SuggestItemMerger.java` ／ `entity/SuggestItem.java` ／ `entity/SuggestItemSerializer.java` ／ `index/operations/IndexingOperations.java` ／ `index/operations/ContentIndexingOperations.java` ／ `index/SuggestIndexer.java`
- **読み**: `entity/ElevateWord.java` ／ `index/contents/DefaultContentsParser.java` ／ `converter/ReadingConverter.java` ／ `converter/ReadingConverterChain.java` ／ `request/suggest/SuggestQueryBuilder.java` ／ `request/popularwords/PopularWordsRequest.java`
- **スキーマ**: `Suggester.java` ／ `settings/AnalyzerSettings.java` ／ `settings/ArraySettings.java` ／ `settings/SuggestSettings.java` ／ `constants/FieldNames.java` ／ `request/suggest/SuggestRequest.java`
- **リソース**: `(res) suggest_indices/suggest.json` ／ `suggest/mappings-default.json` ／ `suggest_settings.json` ／ `suggest_settings_array.json` ／ `suggest_analyzer.json` ／ `analyzer/mapping-default.json` ／ `(fess res) suggest_indices/suggest_analyzer.json` ／ `_aws/suggest_analyzer.json` ／ `_cloud/suggest_analyzer.json`
- **fess 本体**: `(fess) helper/SuggestHelper.java` ／ `(fess) api/v2/handlers/SuggestWordsHandler.java` ／ `(fess) helper/PopularWordHelper.java` ／ `(fess) app/web/admin/elevateword/CreateForm.java` ／ `(fess) app/service/ElevateWordService.java` ／ `(fess) src/main/config/es/fess_config_elevate_word.json` ／ `(fess res) fess_label_ja.properties` ／ `fess_label_en.properties` ／ `(fess) src/main/webapp/WEB-INF/view/admin/elevateword/admin_elevateword_edit.jsp`
- **テスト**: `SuggestItemTest` ／ `SuggestItemBoundaryTest` ／ `SuggestItemMergerTest` ／ `SuggestItemSerializerTest` ／ `SuggestUtilTest` ／ `ElevateWordTest` ／ `SuggestIndexerTest`

### 11.2 バイトコード

`~/.m2/repository/org/opensearch/opensearch/3.7.0/opensearch-3.7.0.jar` を展開し `javap -c -p` で `org/opensearch/action/get/GetRequest` および `MultiGetRequest` のコンストラクタを確認（§4.4）。

### 11.3 タスク内文書

`docs/0000-design-overview.md`（§3.1 / §3.2 / §3.3 / §3.4 / §4.2 / §5 / §5.1 / §6）／ `docs/0001-api-design.md`（§3.4 / §3.5 / §3.7 / §6 / §10）／ `0003-design-document-work-plan.md`（§3 ステップ 5 / §5 / §6.1）／ `0004-new-findings.md`（§3 / §5.2）／ **`0009-reading-field-policy.md`（決定 1〜4 / §6 / §10）** ／ `docs/improvement-proposal.md`（`:132-133` / `:376-402`）
