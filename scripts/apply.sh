#!/usr/bin/env bash
# キーマップ(.vil)を Cornix LP に差分適用する。
#
# vitaly load(一括書き込み)を使わない理由:
# - RMK は書き込み系コマンドの一部で成功コードを返さず、vitaly がエラー中断する
# - 全項目を毎回書き込むとフラッシュ保存が追いつかず HID I/O Timeout が頻発する
# そのため現在のキーボード状態を読み出し、ファイルとの差分だけを
# vitaly の個別サブコマンドで書き込む。
#
# 注意: vitaly はエラー時も exit 0 を返すため、出力の "Error" 行で失敗を検出する。
set -euo pipefail

file="${1:?usage: apply.sh <file.vil>}"

before="$(mktemp -t cornix-before)"
after="$(mktemp -t cornix-after)"
trap 'rm -f "$before" "$after"' EXIT

# 一時的な HID タイムアウトがあるためリトライする
run() {
  local attempt out
  for attempt in 1 2 3; do
    out="$(vitaly "$@" 2>&1)"
    if ! grep -q '^Error' <<<"$out"; then
      return 0
    fi
    sleep 1
  done
  echo "$out" >&2
  return 1
}

echo "Reading current state from keyboard..."
run save -f "$before"

changes=0

# キー: layout[layer][row][col] の差分(-1 はキーが存在しない位置)
while read -r layer pos value; do
  echo "key: layer=$layer pos=$pos -> $value"
  run keys -l "$layer" -p "$pos" -v "$value"
  changes=$((changes + 1))
done < <(jq -r --slurpfile cur "$before" '
  .layout as $new | $cur[0].layout as $old
  | range(0; $new | length) as $l
  | range(0; $new[$l] | length) as $r
  | range(0; $new[$l][$r] | length) as $c
  | select($new[$l][$r][$c] != $old[$l][$r][$c] and $new[$l][$r][$c] != -1)
  | "\($l) \($r),\($c) \($new[$l][$r][$c])"
' "$file")

# エンコーダ: encoder_layout[layer][index][direction](0=CCW, 1=CW)
while read -r layer pos value; do
  echo "encoder: layer=$layer pos=$pos -> $value"
  run encoders -l "$layer" -p "$pos" -v "$value"
  changes=$((changes + 1))
done < <(jq -r --slurpfile cur "$before" '
  .encoder_layout as $new | $cur[0].encoder_layout as $old
  | range(0; $new | length) as $l
  | range(0; $new[$l] | length) as $i
  | range(0; 2) as $d
  | select($new[$l][$i][$d] != $old[$l][$i][$d])
  | "\($l) \($i),\($d) \($new[$l][$i][$d])"
' "$file")

# コンボ: [key1, key2, key3, key4, output]
while read -r n expr; do
  echo "combo: #$n -> $expr"
  run combos -n "$n" -v "$expr"
  changes=$((changes + 1))
done < <(jq -r --slurpfile cur "$before" '
  .combo as $new | $cur[0].combo as $old
  | range(0; $new | length)
  | select($new[.] != $old[.])
  | "\(.) \($new[.][0]) + \($new[.][1]) + \($new[.][2]) + \($new[.][3]) = \($new[.][4])"
' "$file")

# タップダンス: [tap, hold, double_tap, tap_hold, tapping_term_ms]
while read -r n expr; do
  echo "tapdance: #$n -> $expr"
  run tapdances -n "$n" -v "$expr"
  changes=$((changes + 1))
done < <(jq -r --slurpfile cur "$before" '
  .tap_dance as $new | $cur[0].tap_dance as $old
  | range(0; $new | length)
  | select($new[.] != $old[.])
  | "\(.) \($new[.][0]) + \($new[.][1]) + \($new[.][2]) + \($new[.][3]) ~ \($new[.][4])"
' "$file")

# QMK settings: RMK は成功コードを返さないため vitaly のエラー判定は無視する
while read -r qsid value; do
  echo "setting: qsid=$qsid -> $value"
  vitaly settings -q "$qsid" -v "$value" > /dev/null 2>&1 || true
  changes=$((changes + 1))
done < <(jq -r --slurpfile cur "$before" '
  .settings as $new | $cur[0].settings as $old
  | $new | to_entries[]
  | select(.value != $old[.key])
  | "\(.key) \(.value)"
' "$file")

# マクロは .vil のバイナリ形式から個別コマンドへの変換が必要なため未対応
if ! jq -e --slurpfile cur "$before" '.macro == $cur[0].macro' "$file" > /dev/null; then
  echo "WARNING: macros differ but are not applied (edit them on https://vial.rocks/ or with 'vitaly macros')" >&2
fi

if [ "$changes" -eq 0 ]; then
  echo "Already up to date"
  exit 0
fi

echo "Applied $changes change(s). Verifying..."
run save -f "$after"
if diff <(jq -S 'del(.macro)' "$file") <(jq -S 'del(.macro)' "$after") > /dev/null; then
  echo "Verified: keyboard matches $file"
else
  echo "WARNING: keyboard state still differs from $file:" >&2
  diff <(jq -S 'del(.macro)' "$file") <(jq -S 'del(.macro)' "$after") >&2 || true
  echo "(差分がキーコードの表記だけの場合は、ファイル側を vitaly save の正規名に合わせる。例: KC_ESC -> KC_ESCAPE)" >&2
  exit 1
fi
