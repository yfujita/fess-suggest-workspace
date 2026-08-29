# 0002: 逸脱 X-1 — `Suggester.builder()` の戻り値型（区分 I）

> 本書は作業プラン `0001-work-plan.md` §4「フェーズ 0」**ステップ 0-2** の作業履歴である（§9.1 の割当てにより、逸脱手続きの発火は独立ファイルに収める）。
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[確定]** = 決定済み ／ **[要確認]** = 未解消

| 項目 | 値 |
| --- | --- |
| 実施日 | 2026-08-24 |
| 対象ステップ | **0-2** |
| 逸脱区分 | **区分 I（設計判断の誤り・不足）** — プラン §2.1 |
| 改訂した設計書 | `docs/0001-api-design.md` — **第 8 版 → 第 9 版** |
| コード変更 | **なし**（設計書の改訂のみ。逸脱手続きは「改訂を先に行う」ことを要求する） |

**結果: DoD 3 件すべて充足。ステップ D-8（`SuggesterBuilder` の実装）に進んでよい。**

---

## 1. 逸脱の内容 — 何が矛盾していたか

### 1.1 矛盾の構造

**第 8 版までの `0001` は、同一の構築 API について 2 つの両立しない要求を持っていた。**

| # | 記述 | 位置 | 要求 |
| --- | --- | --- | --- |
| **(a)** | 「4 IF の実装を組み立てた **`SuggestComponents` を返す形に変える**」 | `0001` §8.1 の 11（改訂前 L1770） | `build(...)` の**戻り値型を変える** |
| (a') | `public SuggestComponents build(Client client, SuggestSettings settings, ExecutorService executor);` | `0001` §3.9.1 のコードブロック（改訂前 L1372） | 同上 |
| (a'') | 「**`Suggester` 自身は返さない。**」 | `0001` §3.9.1（改訂前 L1392） | 同上 |
| **(b)** | 「旧 `Suggester` / `SuggestIndexer` は**クラスとして残し、public シグネチャを 1 つも変えない**」 | `0001` §8.3（改訂前 L1837-1838） | **戻り値型を変えてはならない** |
| (b') | 「**fess 本体が L1（fess-suggest だけ新版）のまま動くこと** → **維持する**」 | `0001` §8.3.1（D-28 の表） | 同上 |
| (b'') | C-01（Strangler Fig 4 段） | `0000` §5 L269 ／ `0003` §10.1 | 同上 |
| (b''') | D-13「旧 `Suggester` / `SuggestIndexer` は**シグネチャを維持したまま**新部品へ委譲する」 | `0001` §0 の決定表 | 同上 |

**`Suggester.builder()` は `Suggester` の public 18 メンバのうちの 1 つ（§8.1 の 11）である。** したがって (a) は (b) / (b''') の「public シグネチャを 1 つも変えない」の**例外ではなく違反**であった。

### 1.2 これがコンパイルエラーになる根拠 [確認]

**fess 本体は `build(...)` の戻り値を `Suggester` 型のフィールドへ直接代入している。**

| 位置 | 実物 |
| --- | --- |
| `(fess) helper/SuggestHelper.java:86` | `protected Suggester suggester;` |
| `(fess) helper/SuggestHelper.java:142` | `suggester = Suggester.builder().settings(settingsBuilder).build(searchEngineClient, fessConfig.getIndexDocumentSuggestIndex());` |

`SuggestComponents` は `Suggester` のサブタイプではない（§3.9.1 は `AutoCloseable` を継承する独立 interface として宣言している）。**したがって設計どおりに実装すると `:142` が代入不能となり、L1 の時点で `modules/fess` がコンパイルできない。** これは C-01 が守ろうとしている当のもの（L1 では fess 本体が無変更で動く）を壊す。

> **ステップ 0-1 で `modules/fess` の `mvn compile` がベースラインとして成功していること**（`0004` §1.3 (2)）が、この破壊の起点である。**「無変更でビルドできる」状態を維持することが C-01 の実証**であり、本改訂はそれを守るためのものである。

### 1.3 実際に壊れるのは 2 引数版である — プランの記述との差分

**プラン §2.2 の X-1 は §3.9（L1370・L1392）の 3 引数版 `build(Client, SuggestSettings, ExecutorService)` を矛盾の主体として書いていたが、`(fess) SuggestHelper.java:142` が呼んでいるのは 2 引数版 `build(Client, String)` である** [確認]。

| メソッド | 現行の実体 | 第 8 版までの `0001` の扱い |
| --- | --- | --- |
| `build(Client client, String id)` | **存在する。** `(sug) SuggesterBuilder.java:149` が `public Suggester build(final Client client, final String id)` [確認] | §3.9.1 のコードブロックに**現れない**。§8.1 の 11 が「`SuggestComponents` を返す形に変える」と述べる対象に含まれる |
| `build(Client, SuggestSettings, ExecutorService)` | **存在しない。** 現行 `SuggesterBuilder` の public メンバは `:39`〜`:149` の 10 件で、3 引数版は無い [確認] | §3.9.1 が新設するものとして宣言 |

**したがって矛盾は「新設する 3 引数版の戻り値型」だけの問題ではなく、既存の 2 引数版にも及ぶ。** 本改訂は**両方**を `Suggester` を返す側として明示した（§2.2）。**この点はプランの X-1 記述より範囲が広い**が、逸脱の性質（区分 I・`build` の戻り値型）は同一であるため、ステップを分けずに本ステップで一括して解消した。

---

## 2. 改訂の内容（`0001` 第 8 版 → 第 9 版）

### 2.0 前提: 版表記の是正（区分 II）

**改訂前の `0001` は冒頭が「現在の版: 第 7 版（2026-08-17）」である一方、改訂履歴の最新行は第 8 版（2026-08-22）であった** [確認]（プラン §9.2 の注記が予告していた不整合）。**冒頭表記が第 8 版への更新時に据え置かれたもの**であり、設計内容の差ではない。

**プラン §4 のステップ 0-2 作業内容 0 に従い、「改訂履歴の最新版 +1」を採って第 9 版とした。** 固定値の「第 9 版」を前提にした結果ではなく、`8 + 1 = 9` の結果として一致した。冒頭表記は本改訂で `第 9 版（2026-08-24）` に更新済みであり、**改訂履歴の最新行と一致する**。

### 2.1 採った形

**`build(...)` の戻り値型は `Suggester` のまま維持し、`SuggestComponents` を得る入口を別メソッドとして新設する。**

```java
public final class SuggesterBuilder {

    // --- SPI の登録（変更なし） ---
    // ...

    /** 4 つの公開 IF をまとめて保持するハンドルを構築する（第 9 版で新設）。 */
    public SuggestComponents buildComponents(Client client, SuggestSettings settings, ExecutorService executor);

    // --- 構築（旧ファサード。戻り値型は現行のまま維持する） ---
    /** 内部で buildComponents(...) を呼び、得た SuggestComponents を保持する Suggester を返す。 */
    public Suggester build(Client client, SuggestSettings settings, ExecutorService executor);
    /** 現行の 2 引数版（SuggesterBuilder.java:149）。settings / executor は builder の設定から解決する。 */
    public Suggester build(Client client, String id);
}
```

**新設メソッドの名称は `buildComponents` である**（プラン §4 の [提案] をそのまま採用）。

### 2.2 改訂した箇所（9 hunk）

| # | 箇所 | 改訂前 | 改訂後 |
| --- | --- | --- | --- |
| 1 | 冒頭 L3 | 「現在の版: **第 7 版**（2026-08-17）」 | 「現在の版: **第 9 版**（2026-08-24）」（§2.0 の区分 II 是正を含む） |
| 2 | 冒頭宣言 L12 | — | **第 9 版で解消する設計矛盾（逸脱 X-1）の 1 行を追加**。参照先 §3.9.1 / §8.1 の 11 / §8.3.1 |
| 3 | 改訂履歴 L30 | 最新行は第 8 版 | **第 9 版の行を追加。** 変更理由をプラン §4 の指定どおり明記（§2.3） |
| 4 | §0 決定表 D-28 の行 L69 | 「メジャーアップデートとして受容する」で終わる | 「**第 9 版で維持する側に `Suggester.builder()` とその `build(...)` を明示した**（逸脱 X-1。§8.3.1）」を追記。根拠列に「逸脱 X-1」を追加 |
| 5 | §3.9.1 コードブロック L1373-1386 | `public SuggestComponents build(Client, SuggestSettings, ExecutorService);` の 1 メソッド | `buildComponents(...)` を新設し、**`build(...)` の 2 オーバーロード（3 引数版・2 引数版）を `Suggester` を返すものとして明示** |
| 6 | §3.9.1 の箇条書き L1400-1402 | 「**`Suggester` 自身は返さない。**」 | **3 つの箇条書きに置換** — (i) `build` は `Suggester` を返し `SuggestComponents` は `buildComponents` から得る（撤回理由と `(fess)` の根拠つき）、(ii) `build` と `buildComponents` の関係（D-13 の向きが保たれること）、(iii) 新規呼び出し元は `buildComponents` を使うこと |
| 7 | §3.9.4 末尾の注記 L1451 | 「`SuggesterBuilder` の登録メソッドも D-1 に数えない」 | 「登録メソッドも、**第 9 版で新設した `buildComponents(...)` も** D-1 に数えない」 |
| 8 | §8.1 の 11 L1780 | 「**4 IF の実装を組み立てた `SuggestComponents` を返す形に変える**」 | 「**シグネチャを維持したまま存続する**（`build(...)` は `Suggester` を返し続ける）。**`SuggestComponents` は `buildComponents(...)` から得る**」 |
| 9 | §8.3.1（D-28）の表 L1866 | `Suggester.builder()` の行が**無い** | **維持する側として 1 行追加**。2 引数版・3 引数版の両方が `Suggester` を返し続けること、`(fess) SuggestHelper.java:142` / `:86` を根拠として明記 |

### 2.3 改訂履歴に記録した変更理由（第 9 版の行・要旨）

> **同書 §3.9 の「`build(...)` の戻り値を `SuggestComponents` に変える」は、同書 §8.3（旧 public シグネチャを 1 つも変えない）および C-01（L1 では fess 本体が無変更で動く）と両立しなかった。`(fess) helper/SuggestHelper.java:142` が戻り値を `Suggester` 型フィールド（`:86`）へ代入しているため、L1 でコンパイルエラーになる** [確認]。

あわせて (1)〜(5) の改訂内容と、区分 II の版表記是正、**「公開 4 IF のシグネチャ・D-1 の 30 メソッド・番号体系に変更は無い」**旨を記録した。

---

## 3. 設計判断として保たれたこと

| 論点 | 判定 |
| --- | --- |
| **D-13 の「旧クラスが新 IF を保持する向き」** | **保たれる。** `build(...)` は内部で `buildComponents(...)` を呼び、得た `SuggestComponents` を保持する `Suggester` を返す。**新 IF が旧クラスを参照する向きは生じない**ため、L3（第 4 段 / MIG-05）で `Suggester` を削除しても `SuggestComponents` は残る |
| **C-01 の 4 段** | **変わらない。** 本改訂は**むしろ C-01 を守るための改訂**である（プラン §4 の注意点） |
| **`0000` §5 の C-01 スナップショット** | **変更していない** [確認]（`0000-design-overview.md:269`。§4.3 の diff で確認） |
| **D-1 の 30 メソッド** | **変わらない。** `buildComponents(...)` は構築 API であり、`Suggester.builder()` として既に §8.1 の 11 に計上済み（§3.9.4 の注記に明記した） |
| **公開 4 IF のシグネチャ** | **変わらない。** 本改訂は `SuggesterBuilder`（構築 API）の面のみを扱う |
| **`SuggestComponents` の存在意義** | **変わらない。** 4 IF の取り出し口・SPI 実装の後始末（§3.9.4）という役割は同じ。**入口が `build` から `buildComponents` に変わっただけ**である |

---

## 4. DoD の充足確認

### 4.1 DoD 1: 改訂履歴に第 9 版の行があり、変更理由が書かれている

**充足** [確認]。`0001-api-design.md:30` に第 9 版（2026-08-24）の行があり、§2.3 の変更理由を含む。

### 4.2 DoD 2: §3.9・§8.1 #11・D-28 の 3 箇所が整合している

**充足** [確認]。**3 箇所すべてが「`build` は `Suggester` を返す」と述べている。**

| 箇所 | 行 | 記述 |
| --- | --- | --- |
| §3.9.1 | `:1381` / `:1383` | `public Suggester build(Client client, SuggestSettings settings, ExecutorService executor);` ／ `public Suggester build(Client client, String id);` |
| §3.9.1 | `:1400` | 「**`build(...)` は `Suggester` を返し、`SuggestComponents` は `buildComponents(...)` から得る**」 |
| §8.1 の 11 | `:1780` | 「**シグネチャを維持したまま存続する**（`SuggesterBuilder.build(...)` は `Suggester` を返し続ける）」 |
| §8.3.1（D-28） | `:1866` | 「`build(Client, String)` も `build(Client, SuggestSettings, ExecutorService)` も **`Suggester` を返し続ける**」 |
| §0 の D-28 行 | `:69` | 「第 9 版で維持する側に `Suggester.builder()` とその `build(...)` を明示した」 |

**「`SuggestComponents` を返す」と述べる記述は 0 件である**（改訂前の 3 箇所はすべて書き換えた）。

### 4.3 DoD 3: `0002` / `0003` に `SuggestComponents` の戻り値型に依存する記述が無い

**充足** [確認]。`grep -n "SuggestComponents" docs/*.md` の全ヒットを目視した。

| ファイル | ヒット数 | 内容 |
| --- | --- | --- |
| `0000-design-overview.md` | **1** | `:496`「V4（1 行 IF の不在）… `SuggestComponents`（`0001` §3.9.1）は SPI ではなく**構築結果の取り出し口**である」。**戻り値型に依存しない**（`build` / `buildComponents` のどちらから得ても成立する）。**改訂不要** |
| `0001-api-design.md` | 12 | 本改訂の対象。すべて §2.2 で処理済み |
| **`0002-datamodel-design.md`** | **0** | **依存する記述は無い** |
| **`0003-migration-ops-design.md`** | **0** | **依存する記述は無い** |
| `0004-corrections.md` | 0 | — |

**念のため `SuggesterBuilder` / `builder()` / `.build(` でも `0002` / `0003` を検索した**が、ヒットは `0003:689`（shards / replicas のセッターが無いという事実記述）と `0003:1087`（変更対象ファイル一覧に `SuggesterBuilder.java` を挙げるもの）の 2 件のみで、**いずれも戻り値型に依存しない** [確認]。

### 4.4 追加確認: 20260706 側スナップショットの無変更（Q7）

**`20260706_design_document/docs/` は変更していない** [確認]。ワークスペース直下は git 管理外のため `diff` で確認した。

| ファイル | 20260706 との比較 |
| --- | --- |
| `0000-design-overview.md` | **同一** |
| **`0001-api-design.md`** | **差異あり（本改訂による意図した乖離。プラン §2.3）** |
| `0002-datamodel-design.md` | 同一 |
| `0003-migration-ops-design.md` | 同一 |
| `0004-corrections.md` | 同一 |

**プラン §2.3 が予告した「本プランの改訂により両者は乖離するが、それは意図した状態である」が、本ステップで初めて現実になった。**

---

## 5. 次ステップへの申し送り

1. **ステップ D-8（`SuggesterBuilder` の実装）は、`buildComponents(Client, SuggestSettings, ExecutorService)` を新設し、`build(...)` の 2 オーバーロードを `Suggester` を返すまま維持する形で実装する。** 3 引数版 `build(Client, SuggestSettings, ExecutorService)` は**現行に存在しない新設メソッド**である（§1.3）。
2. **フェーズ E（旧ファサードの委譲）で、`Suggester` が `SuggestComponents` を保持する形にする。** `build(...)` → `buildComponents(...)` → `new Suggester(components)` の流れになる。**逆向き（`SuggestComponents` が `Suggester` を持つ）にしてはならない**（D-13）。
3. **`(fess) helper/SuggestHelper.java:142` は L1 で無変更である。** フェーズ F の C-01 実証では、`0004` §1.3 (2) のベースラインと同じく `modules/fess` を無変更のまま `mvn compile` が通ることを確認する。
4. **本ステップはコード変更を伴わない。** `modules/fess-suggest` / `modules/fess` とも差分は 0 であり、コミットは行っていない（`agent_docs/` は git 管理外・プラン §2.4）。
5. **`0001` は第 9 版になった。** ステップ 0-4 が `0002` / `0003` を改訂する際は、**それぞれの改訂履歴の最新版 +1** を採ること（`0001` の第 9 版に揃えない — プラン §9.2 の注記）。
