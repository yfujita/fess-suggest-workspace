#!/bin/zsh
UA="Mozilla/5.0"
B="https://search.n2sm.co.jp/api/v1/suggest-words"
out=/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/385057d0-bf1f-4232-a603-6753c0920cea/scratchpad/probe3.out
: > $out
req() {
  printf '### %s\n%s\n\n' "$1" "$(curl -s -G -H "User-Agent: $UA" "$B" --data-urlencode "q=$2" -d num=5 -w '\n[http %{http_code}]')" >> $out
  sleep 4
}
# 「ン→nn」機構の決定的確認: 語中のンは prefix 一致できない / 語末のンは救われる
req "kennsaku (検索=けんさく→kennsakuか)" "kennsaku"
req "nihonn (日本=にほん→nihonn)"        "nihonn"
req "sennmonn (専門=せんもん→sennmonn)"  "sennmonn"
req "gijutsu (技術=ぎじゅつ、ンなし)"     "gijutsu"
# q=search が 0 件の件: s 始まりの語は存在するか
req "store"    "store"
req "swift"    "swift"
req "se"       "se"
# 中間一致 (再実行)
req "ess"      "ess"
echo "DONE" >> $out
