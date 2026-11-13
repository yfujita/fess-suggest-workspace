# 事前フェーズ用ブランチの作成

## 作業内容

事前フェーズ（`SettingsIndexCreationRaceTest` の失敗修正。work-plan §4）を実施するブランチを `modules/fess-suggest` に作成した。

- ブランチ名: `fix/settings-read-after-concurrent-init`
- 分岐元: `main`（`2ccb4f6`。`origin/main` と同一）

## 命名の理由

- リポジトリの既存ブランチ（`fix/settings-index-create-race`、`fix/pit-missing-id` など）に合わせ、`fix/` + 修正内容の kebab-case とした。
- 修正対象は「同時起動直後の settings 読み出しの失敗」であり、`AnalyzerSettings` に加えて `ArraySettings` も対象になりうるため、クラス名ではなく事象で命名した。
