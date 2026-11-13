#!/bin/zsh
UA="Mozilla/5.0"
B="https://search.n2sm.co.jp/api/v1/suggest-words"
out=/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/385057d0-bf1f-4232-a603-6753c0920cea/scratchpad/probe.out
: > $out
req() {
  label="$1"; shift
  url="$1"; shift
  printf '### %s\n%s\n' "$label" "$(curl -s -G -H "User-Agent: $UA" "$url" "$@" -w '\n[http %{http_code}]')" >> $out
  printf '\n' >> $out
  sleep 1.2
}

# --- Z-04: 大文字/全角/ひらがな での prefix ブースト・並べ替え ---
req "Z04 lower: q=fess"      "$B" --data-urlencode "q=fess" -d num=5
req "Z04 Cap:   q=Fess"      "$B" --data-urlencode "q=Fess" -d num=5
req "Z04 UPPER: q=FESS"      "$B" --data-urlencode "q=FESS" -d num=5
req "Z04 zenkaku: q=ｆｅｓｓ" "$B" --data-urlencode "q=ｆｅｓｓ" -d num=5

# --- Z-01: ローマ字変換（撥音/長音/促音） ---
req "Z01 kanji: q=検索"       "$B" --data-urlencode "q=検索" -d num=5
req "Z01 hira:  q=けんさく"   "$B" --data-urlencode "q=けんさく" -d num=5
req "Z01 kana:  q=ケンサク"   "$B" --data-urlencode "q=ケンサク" -d num=5
req "Z01 romaji:q=kensaku"    "$B" --data-urlencode "q=kensaku" -d num=5
req "Z01 romaji:q=kensak"     "$B" --data-urlencode "q=kensak" -d num=5
req "Z01 hatsuon: q=senmon"   "$B" --data-urlencode "q=senmon" -d num=5
req "Z01 hatsuon: q=sennmon"  "$B" --data-urlencode "q=sennmon" -d num=5
req "Z01 chouon: q=koohii"    "$B" --data-urlencode "q=koohii" -d num=5
req "Z01 chouon: q=kohi"      "$B" --data-urlencode "q=kohi" -d num=5
req "Z01 sokuon: q=kensakku"  "$B" --data-urlencode "q=kensakku" -d num=5
req "Z01 nihon:  q=nihon"     "$B" --data-urlencode "q=nihon" -d num=5
req "Z01 gijutsu:q=gijutsu"   "$B" --data-urlencode "q=gijutsu" -d num=5

# --- W-02: 中間一致 / W-01: 誤字補正 ---
req "W02 infix: q=ess"        "$B" --data-urlencode "q=ess" -d num=5
req "W02 infix: q=lasticsearch" "$B" --data-urlencode "q=lasticsearch" -d num=5
req "W01 typo:  q=fesss"      "$B" --data-urlencode "q=fesss" -d num=5
req "W01 typo:  q=elasitc"    "$B" --data-urlencode "q=elasitc" -d num=5

# --- Z-02: 複数語クエリ ---
req "Z02 multi: q=fess 検索"  "$B" --data-urlencode "q=fess 検索" -d num=5
req "Z02 multi: q=full text"  "$B" --data-urlencode "q=full text" -d num=5
req "Z02 multi: q=fess conf"  "$B" --data-urlencode "q=fess conf" -d num=5

# --- Y-04: lang が候補を絞るか ---
req "Y04 lang none: q=search" "$B" --data-urlencode "q=search" -d num=10
req "Y04 lang=ja:   q=search" "$B" --data-urlencode "q=search" -d num=10 -d lang=ja
req "Y04 lang=en:   q=search" "$B" --data-urlencode "q=search" -d num=10 -d lang=en
req "Y04 lang=zz:   q=search" "$B" --data-urlencode "q=search" -d num=10 -d lang=zz

# --- field / label の絞り込み ---
req "field=title:  q=fess"    "$B" --data-urlencode "q=fess" -d num=5 -d field=title
req "field=content:q=fess"    "$B" --data-urlencode "q=fess" -d num=5 -d field=content
req "field=zzz:    q=fess"    "$B" --data-urlencode "q=fess" -d num=5 -d field=zzz
req "label=lucene: q=fess"    "$B" --data-urlencode "q=fess" -d num=5 -d label=lucene
req "label=zzz:    q=fess"    "$B" --data-urlencode "q=fess" -d num=5 -d label=zzz

# --- num / q の境界・異常系 ---
req "num=0:   q=fe"           "$B" --data-urlencode "q=fe" -d num=0
req "num=-1:  q=fe"           "$B" --data-urlencode "q=fe" -d num=-1
req "num=abc: q=fe"           "$B" --data-urlencode "q=fe" -d num=abc
req "num=5000:q=fe"           "$B" --data-urlencode "q=fe" -d num=5000
req "q empty"                 "$B" --data-urlencode "q=" -d num=5
req "q missing"               "$B" -d num=5
req "q=* wildcard"            "$B" --data-urlencode "q=*" -d num=5
req "q=? wildcard"            "$B" --data-urlencode "q=?" -d num=5
req "q=  (space only)"        "$B" --data-urlencode "q= " -d num=5
req "q=a (1char)"             "$B" --data-urlencode "q=a" -d num=5

# --- popular-words ---
req "popular-words"           "https://search.n2sm.co.jp/api/v1/popular-words"
req "popular-words seed=1"    "https://search.n2sm.co.jp/api/v1/popular-words" -d seed=1
req "popular-words seed=2"    "https://search.n2sm.co.jp/api/v1/popular-words" -d seed=2
req "popular-words label=fess" "https://search.n2sm.co.jp/api/v1/popular-words" -d label=fess
echo "DONE" >> $out
