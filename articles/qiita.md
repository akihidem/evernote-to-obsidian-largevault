# Evernote 11,000ノートを Obsidian へ無損失移行する — 大容量 × iCloud で踏んだ6つの罠

## TL;DR

- **11,238ノート + 34,017添付（ENEX 約16GB）→ 11,168 Markdown** を Obsidian へ移行し、**総ファイル数一致で無損失を検証**した。
- 変換自体は既存の名作 [`evernote-backup`](https://github.com/vzhd1701/evernote-backup) と [`yarle`](https://github.com/akosbalazs/yarle) がやる。本記事は**大容量 × iCloud(Windows) × 日本語**で初めて出てくる罠の記録。
- スクリプト一式: **https://github.com/akihidem/evernote-to-obsidian-largevault**

## 対象読者

公式の [Obsidian Importer](https://help.obsidian.md/import/evernote) で十分な人は読まなくていい。次が**全部**当てはまる人だけ刺さる。

- ノートが**数千〜万**・添付が**数GB**（1ノートブックの ENEX が巨大になる）
- Obsidian の Vault を **iCloud Drive (Windows)** に置く
- ノート名に**日本語**など非ASCIIを含む

## パイプライン全体

```
evernote-backup            yarle（ノートブック単位）     iCloud
┌──────────────┐  単ノート  ┌──────────────┐  Markdown  ┌──────────────┐
│ アカウント全DL │ ─ENEX──▶ │ ENEX → .md   │ ─────────▶ │ Vault        │
│ （レート制限再開）│         │ ＋添付保持    │            │ （要・検証）   │
└──────────────┘           └──────────────┘            └──────────────┘
```

```bash
export WORK=~/evernote-migration
./scripts/00_setup.sh
# 一度だけ対話ログイン（OAuth は TTY 必須なので「本物の端末」で）:
( cd $WORK && . .venv/bin/activate && evernote-backup init-db )
./scripts/10_backup_export.sh   # sync（レート制限リトライ）+ --single-notes
./scripts/20_convert.sh         # ノートブック単位 yarle ループ → vault
# vault を iCloud にコピーしてから:
python3 scripts/31_recover_icloud_temp.py "/path/to/iCloud/YourVault"
python3 scripts/30_verify_parity.py "$WORK/vault" "/path/to/iCloud/YourVault"
```

---

## 罠1: 1ノートブックが 9.8GB の ENEX になり、yarle が読めない

`evernote-backup export`（既定）はノートブック単位で1 ENEX を吐く。添付が多いと **1ファイルが 9.8GB** になった。yarle は ENEX を**まるごと1つの文字列**としてメモリに読むため、Node の文字列上限（約 512M 文字）を超えて、1ノートも書く前に落ちる。

```
FATAL ERROR: ... Cannot create a string longer than 0x1fffffe8 characters
```

**対策**: `--single-notes` で「1ノート=1 ENEX」に分割し、**ノートブック単位で yarle を回す**。各ファイルが小さくなりメモリが有界になる。

```bash
evernote-backup export --single-notes ./enex_single   # 11,201個の小さな .enex
```

```bash
# ノートブックごとに outputDir を分けて回す（抜粋）
while IFS= read -r nb; do
  # nb 配下の単ノート ENEX を、その名前のサブフォルダへ変換
  node --max-old-space-size=6144 node_modules/.bin/yarle --configFile /tmp/yarle_nb.json
done < <(find ./enex_single -mindepth 1 -maxdepth 1 -type d | sort)
```

## 罠2: iCloud(Windows) がアップロード中のファイルを `.名前.乱数6` に化けさせる

コピー直後、Vault の md が `11,168` 入っているはずが **`11,102`** しか見えない。総ファイル数は一致しているのに、だ。

正体は iCloud のアップロード・ステージング。送信中のファイルを **`.元名.AbC123`（先頭ドット＋6文字ランダム接尾辞）** という隠し名に一時改名する。`*.md` にマッチしなくなるので「消えた」ように見えるが、**中身は完全なコピー**（サイズ一致で確認済み）。

```
.『サスペリア』…1-6‐ニコニコ動画(秋).md.7vh2KO   ← これが正体
```

**対策**: 先頭ドットと末尾 `.乱数` を剥がして元名に戻すだけ。冪等・非破壊。

```python
import os, re
TEMP = re.compile(r"\.[A-Za-z0-9]{6}$")
for dp, _, fs in os.walk(VAULT):
    for f in fs:
        if f.startswith(".") and TEMP.search(f):
            final = TEMP.sub("", f[1:])
            dst = os.path.join(dp, final)
            if not os.path.exists(dst):
                os.rename(os.path.join(dp, f), dst)
```

iCloud は大容量アップロードの間ずっと新しいステージングを作り続けるので、**何度か再実行**する。

## 罠3: ノート名に `.app` が含まれるとフォルダが改名される

iCloud は `.app` を macOS アプリ束（bundle）とみなす。`Mac写真.appの重複一括削除/` というノートフォルダが **`Mac写真の重複一括削除(1).app/`** に再編され、ときに空の `.app` スタブまで生まれる。データは無事、**フォルダ名だけ**の問題。

**対策**: 親フォルダ名から `.app` を消す（`.app` → `_app`）。ドットが無くなれば iCloud は触らない。中の md・添付の相対リンクは不変なので壊れない。

## 罠4: yarle は `--config` ではなく `--configFile`、かつ `./sampleTemplate.tmpl` を要求

`--config` は**黙って無視**され、yarle は既定設定を読んで `./test-template.enex` を探して落ちる。正しくは `--configFile`。さらに既定テンプレを **CWD 基準**で `./sampleTemplate.tmpl` から開くので、実行場所にコピーしておく。

```bash
cp node_modules/yarle-evernote-to-md/sampleTemplate.tmpl ./sampleTemplate.tmpl
node node_modules/.bin/yarle --configFile ./config.json   # ← --configFile
```

## 罠5: 大規模アカウントは sync 途中で API レート制限に当たる

```
Rate limit reached. Restart program in 02:59.
```

`evernote-backup sync` は**再開可能**。待ち時間をパースして完了まで回す。

```bash
while true; do
  out=$(evernote-backup sync 2>&1)
  if echo "$out" | grep -q "Rate limit reached"; then
    w=$(echo "$out" | grep -oE '[0-9]+:[0-9]+' | head -1)
    sleep $(( 10#${w%%:*}*60 + 10#${w##*:} + 20 )); continue
  fi
  break
done
```

## 罠6: 「無損失」を目視でなく数で証明する

ここまで改名だらけなので、最後は**総ファイル数の一致**と差分で証明する。日本語名は **NFC/NFD**（macOS/Evernote は NFD が多い）でバイト不一致が起きるため、`unicodedata.normalize` で揃えてから比較する。

```python
import os, unicodedata
def files(root):
    s=set()
    for dp,_,fs in os.walk(root):
        for f in fs:
            s.add(unicodedata.normalize("NFC", os.path.relpath(os.path.join(dp,f),root)))
    return s
src, dst = files(MASTER), files(ICLOUD)
print(len(src), len(dst), "MATCH" if src==dst else (src^dst))
```

最終結果:

```
SOURCE  all=45,221
DEST    all=45,221   MATCH ✅
```

---

## おまけ: 1万ノートをどう整理するか

手で振り分けない。Obsidian コミュニティの定石は「**取り込みは丸ごと Archive に隔離 → 上に薄い PARA 構造を載せ、MOC（Map of Content）と全文検索で surface する**」。`04_Archive/Imported/` に全部入れ、よく使う十数ノートブックだけ `02_Areas/` `03_Resources/` に昇格、テーマが見えたら `07_MOC/MOC-◯◯.md` を育てる。

## まとめ

- 変換は `evernote-backup` + `yarle` で十分。**詰まるのは大容量と iCloud の周辺**。
- `--single-notes` + ノートブック単位ループで巨大 ENEX を回避。
- iCloud の `.名前.乱数` は完全コピーなので**改名で復旧**。`.app` はフォルダ改名で回避。
- 最後は**総数一致**で無損失を証明する。

スクリプト一式（MIT）: **https://github.com/akihidem/evernote-to-obsidian-largevault**
