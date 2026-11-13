#!/bin/zsh
UA="Mozilla/5.0"
B="https://search.n2sm.co.jp/api/v1/suggest-words"
P="https://search.n2sm.co.jp/api/v1/popular-words"
out=/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/385057d0-bf1f-4232-a603-6753c0920cea/scratchpad/probe2.out
: > $out
req() {
  label="$1"; shift
  url="$1"; shift
  printf '### %s\n%s\n\n' "$label" "$(curl -s -G -H "User-Agent: $UA" "$url" "$@" -w '\n[http %{http_code}]')" >> $out
  sleep 3
}

# 429 でやり直し
req "Z01 sokuon: q=kensakku" "$B" --data-urlencode "q=kensakku" -d num=5
req "Z01 nihon:  q=nihon"    "$B" --data-urlencode "q=nihon" -d num=5
req "Z01 gijutsu:q=gijutsu"  "$B" --data-urlencode "q=gijutsu" -d num=5
req "W02 infix:  q=ess"      "$B" --data-urlencode "q=ess" -d num=5
req "W02 infix:  q=lasticsearch" "$B" --data-urlencode "q=lasticsearch" -d num=5

# Z-02 追試: 複数語 item は存在する（"fess n2sm"）のに空白クエリで引けるか
req "Z02 q=fess n2sm"        "$B" --data-urlencode "q=fess n2sm" -d num=5
req "Z02 q=fess n"           "$B" --data-urlencode "q=fess n" -d num=5

# q=search が 0 件だった件の追試
req "q=sear"                 "$B" --data-urlencode "q=sear" -d num=10
req "q=searc"                "$B" --data-urlencode "q=searc" -d num=10
req "q=search"               "$B" --data-urlencode "q=search" -d num=10
req "q=searching"            "$B" --data-urlencode "q=searching" -d num=10

# Z-04 追試: ひらがな/カタカナで並び順が変わるか（より短い前方一致）
req "Z04 q=けんさ"           "$B" --data-urlencode "q=けんさ" -d num=5
req "Z04 q=ケンサ"           "$B" --data-urlencode "q=ケンサ" -d num=5
req "Z04 q=ケンサク結果?"     "$B" --data-urlencode "q=けんさくけっか" -d num=5

# ラベル絞り込みが本当に効くか
req "label=dbflute q=fess"   "$B" --data-urlencode "q=fess" -d num=5 -d label=dbflute
req "popular label=buzzfeed" "$P" -d label=buzzfeed
req "popular label=elasticsearch" "$P" -d label=elasticsearch
req "popular label=zzz"      "$P" -d label=zzz
req "popular field=title"    "$P" -d field=title

# ゴミ語・記号
req "q=。"                   "$B" --data-urlencode "q=。" -d num=5
req "q=)"                    "$B" --data-urlencode "q=)" -d num=5
echo "DONE" >> $out
