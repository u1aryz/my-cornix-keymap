# my-cornix-keymap

Cornix LP(PandaKB 製・分割型キーボード、標準ファームウェアは RMK / Vial 対応)のキーマップ管理リポジトリ。

## 構成

- `keymaps/main.vil` — 作業用キーマップ(apply/save のデフォルト対象)。Vial のキーマップエクスポート(JSON)
- `keymaps/default.vil` — 工場出荷時キーマップのバックアップ。**変更・上書きしないこと**
- `mise.toml` — ツール([vitaly](https://github.com/bskaplou/vitaly) を cargo バックエンドでバージョン固定、jq、lefthook)とタスクの定義
- `lefthook.yml` — pre-commit フック。ステージされた `*.vil` を `scripts/format-vil.sh` で整形する(`mise install` 時に自動でインストールされる)
- `scripts/format-vil.sh` — 引数の `.vil` を jq で整形して上書きする(pre-commit フックと format タスクの実体)
- `scripts/apply.sh` — キーマップの差分適用スクリプト。キーボードの現在状態を読み出し、ファイルとの差分(キー・エンコーダ・コンボ・タップダンス・settings)だけを vitaly の個別サブコマンドで書き込み、適用後に再読み出しして検証する。`vitaly load`(一括書き込み)は使わない — RMK では HID I/O Timeout が頻発し、QMK settings で成功コードを返さないため。マクロは未対応(vial.rocks で編集)

## コマンド

- `mise install` — vitaly をインストール(プロジェクトローカル)
- `mise run devices` — 接続中デバイスの一覧
- `mise run apply [file]` — キーマップをキーボードに適用(デフォルト: `keymaps/main.vil`)
- `mise run save [file]` — キーボードの現在のキーマップを保存(デフォルト: `keymaps/main.vil`)
- `mise run format` — `keymaps/*.vil` を jq で整形

## 注意

- キーボード操作(apply/save/devices)は実機の有線接続が必要。未接続環境では実行しても失敗するだけなので、ファイル編集のみ行うこと
- `.vil` は Vial が出力する JSON。手編集する場合は JSON として妥当な状態を保つこと
- `keymaps/main.vil` を変更したら、README.md の「キーマップ(main.vil)」セクション(レイヤー図・エンコーダ表)も合わせて更新すること
- キーコードは `vitaly save` が出力する正規名で書くこと(例: `KC_ESC` ではなく `KC_ESCAPE`)。エイリアスは apply の検証で表記差分として警告される
- vitaly はエラー時も exit 0 を返すため、出力の `Error` 行で失敗を判定すること(apply.sh の `run` 関数参照)
