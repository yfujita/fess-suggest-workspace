# 0013: 連結語設計書の更新

作成日: 2026-11-16 / 担当: document-writer(更新)、document-reviewer(レビュー)、記録はメインエージェント

## 1. 概要

ユーザーの指示(「設計書を更新して」。連結語設計書の更新可否の確認に対する指示と解釈した)により、`agent_tasks/20261113_implement_compound_word_suggest/task_docs/design_compound_word_suggest.md` を、今回の実装(設計書 `design_fragment_suggest.md` の 3.8)に合わせて更新した。この文書のみを編集した(コード、他の作業記録、STATUS.md は変更していない)。更新後の設計書は経緯・日付への参照を書かず単体で完結する(別設計へのパス参照のみ)。

## 2. 更新内容

1. **explain の停止条件**(3.4 の `compound.enabled` の説明、3.5、4.1、4.2 の停止手順): explain(tokenizer 段)は `compound.enabled` と `fragment.inflection.enabled` の**両方が false のときだけ**止まる。連結語だけを止めても、活用形の除外が有効なら 1 チャンクにつき 1 回残る。
2. **ベースライン測定**(7 章): `compound.enabled=false` **かつ** `fragment.inflection.enabled=false`。ベースラインと測定で `fragment.*` を同じ値にする。
3. **「断片は残す」**(2 章、6 章 #3・#14): 連結語の生成は断片を減らさず、名詞の断片は残る。促音長音のみ・記号のみ・英数 1 文字・かな 1 文字(lang が未設定または `ja` のとき)・形容詞-自立の活用形の断片は、既定で文書経路の候補から除かれる(別設計。`inflection.enabled` の既定は暫定)。
4. **3.1**: `attributes` と応答の属性に `inflectionForm` を追加(連結語では使わない)。
5. **3.2**: 両端の記号のみ・促音長音のみのトークンのトリム(`filter.enabled` のとき。中間は残す。外した結果が 2 トークン未満なら連結語なし)を追記し、擬似コード `flush(run)` の先頭に `trim` を反映、判定順(トリム → 2 未満 → トークン数上限 → 本文照合 → 文字数上限)を明記。
6. **「従来動作/従来どおり」の曖昧さの解消**(4.1 見出し、4.4、4.5、5.1 の表 4 行): 「連結語なし」「名詞の断片は残る(断片の除外規則は別設計)」「断片は出る(除外規則の対象外のもの)」に統一。
7. **7 章「実装前に確認する事項」1**: `inflectionForm` が取れるか(`_vanilla` などは未確認。取れない構成では活用形の除外が働かず、explain だけが追加で呼ばれる)を追記。

## 3. レビュー

document-reviewer の指摘: Critical なし、Important 3 件(3.2 の擬似コードにトリム未反映、2 章・6 章の「生成条件は変えない」がトリムと矛盾して読める、「従来動作/従来どおり」の曖昧さ)、Suggestion 5 件、Nitpick 1 件。Important 3 件と、更新に直接関わる Suggestion 3 件(ベースラインの `fragment.*` の統一、7 章 1 への `inflectionForm`、2 章要約の lang 条件と暫定)を反映した。反映後の確認は、メインエージェントが該当箇所を grep・実読みで確認した(「従来」の語が文書から無くなったこと、擬似コードのトリム、見出し・各記述の変更)。document-reviewer による再レビューは行っていない(文書のみの限定的な反映のため)。

## 4. 対応しなかったもの(ユーザー判断待ち)

- コード行番号の参照ずれ(3.1・3.4・1 章。以前からのもの。メソッド名の参照への置き換えか、まとめての更新が必要)。
- 3.4 の設定表に `fess.suggest.compound.break.chars` / `fess.suggest.compound.break.tokens` が無い(実装にはある。以前からの記載漏れ)。
- 3.4 の `compound.enabled` の説明に、トリムが `fragment.filter.enabled` に従う旨が無い(2 章と 3.2 に記載済みで矛盾はない)。
- 5.1 のテスト表に、トリムのケースと、`test_degradation_disabled`(`compound.enabled=false` と `inflection.enabled=false` の併記)に対応する記述が無い。
- 別設計へのパス参照が 3 か所に重複している(Nitpick)。

## 5. 次のアクション

- 上記 4 章のうち、追記・修正を希望するものをユーザーが指示する。
- 残りのユーザー判断待ちは 0011 の 5 章(`ne`・`ku` の既定、今回の設計書 `design_fragment_suggest.md` の恒久化の要否)。
