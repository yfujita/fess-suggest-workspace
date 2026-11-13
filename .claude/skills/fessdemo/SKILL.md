---
name: fessdemo
description: WEB上に公開されているfessのデモ環境の実行方法。fessの実機動作を確認したい場合に利用する。
---

## デモ環境

- FessトップページURL: https://search.n2sm.co.jp/
- Fess API: https://search.n2sm.co.jp/api/v1/
- Suggest API: https://search.n2sm.co.jp/api/v1/suggest-words

### アクセス時の注意

- `User-Agent` が未指定だと 429 が返るため、curl では `-H "User-Agent: Mozilla/5.0"` を付ける。
- アクセストークンは不要（GET はトークン無しで 200）。連続リクエストは控えめに。

```bash
curl -s -H "User-Agent: Mozilla/5.0" "https://search.n2sm.co.jp/api/v1/suggest-words?q=fe&num=5"
```

## Suggest API: `GET /api/v1/suggest-words`

サジェスト候補を前方一致で返す。**`documents` とはパラメータ体系が別物**で、以下の6つしか受け付けない。

| パラメータ | 複数指定 | 型 | デフォルト | 説明 |
|---|---|---|---|---|
| `q` | 不可 | string | なし | 入力中の文字列（前方一致の対象） |
| `num` | 不可 | int | 10 | 取得件数。数値以外は 10 にフォールバック。**上限チェックなし** |
| `label` | 可 | string | なし | ラベル（suggest の tag）で絞り込み |
| `field` | 可 | string | なし | サジェスト生成元フィールド（`content`, `title` など） |
| `lang` | 可 | string | なし | 対象言語（`ja` など） |
| `callback` | 不可 | string | なし | JSONP コールバック名 |

`sort` / `start` / `offset` / `fields.*` / `as.*` / `ex_q` / `facet.*` / `geo.*` は **suggest では未対応**（指定しても無視される）。
Kind（USER / QUERY / DOCUMENT）やロール条件はサーバ側設定で決まり、クライアントからは制御できない。

### レスポンス

```json
{"query_time":1,"record_count":165,"page_size":3,
 "data":[{"text":"fess","labels":["fess","dbflute"]}]}
```

- `record_count`: ヒット総数 / `page_size`: 実際に返した件数
- `data`: 0件のときは **キー自体が出力されない**
- 各要素は `text` と `labels[]` のみ。スコアや kind は返さない。

## その他の API（概要）

いずれも GET（favorite のみ POST）。詳細パラメータが必要になったら実機で確認する。

| エンドポイント | 主なパラメータ | 備考 |
|---|---|---|
| `/api/v1/documents` | `q`, `num`(既定10/上限100), `start`, `offset`, `sort`, `fields.<name>`, `as.<cond>`, `ex_q`, `lang`, `facet.field`, `facet.size`, `geo.*`, `preference` | 全文検索。`as.*` を指定すると **`q` は無視される** |
| `/api/v1/popular-words` | `seed`, `label`, `field` | 人気キーワード。**`num` は無く件数はサーバ設定固定（10件）** |
| `/api/v1/labels` | なし | ラベル一覧。`{"record_count":N,"data":[{"label":..,"value":..}]}` |
| `/api/v1/health` | なし | 死活確認。`{"data":{"status":"green","timed_out":false}}`。※ `/api/v1/ping` ではない |
| `/api/v1/documents/all` | `documents` と同じ | NDJSON スクロール検索。**デモでは無効**（400 `Scroll Search is not available.`） |
| `/api/v1/favorites` | `queryId`（必須） | お気に入り一覧。ユーザセッション必須 |
| `/api/v1/documents/{docId}/favorite` | `queryId`（必須） | **POST**。お気に入り登録。ユーザセッション必須 |

### エラーレスポンス

- 形式は `{"message":"..."}` または `{"error_code:":"<UUID>"}`（デモは後者。キー名のコロンは Fess 側の実装通り）。
- 400（不正クエリ・機能無効）、401（トークン不正）、404（未知パス）、405（メソッド不一致）、429（UA 未指定）、503（health 異常）。
