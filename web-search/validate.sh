#!/bin/sh


cd "$(dirname "$0")" || exit 1
TOP=$(git rev-parse --show-toplevel)
eval_dir="$TOP/web-search"
scripts_dir="$eval_dir/scripts"

NODE_DIR="$TOP/.tools/nodejs18/bin" 
export PATH="$NODE_DIR:$PATH"

in="$eval_dir/inputs"
out="$eval_dir/outputs"
export IN="${in}"
export OUT="${out}"

INDEX="$out/global-index.txt"
QUERY_SH="$scripts_dir/query.sh"

# Index keys are already stemmed, and stemming is not idempotent, so they
# cannot be passed back to query.sh as query text. Instead, query with the
# original (unstemmed) words of the last indexed page, which query.sh
# processes and stems exactly as index.sh did.
TERMS=$(
  "$scripts_dir/c/process.sh" < "$out/content.txt" |
    awk 'length($0) > 2' |
    awk '!seen[$0]++' |
    shuf |
    head -n 5
)

status=0
for term in $TERMS; do
  if ! "$QUERY_SH" "$term" >/dev/null; then
    status=1
    break
  fi
done

echo "web-search $status"
exit $status