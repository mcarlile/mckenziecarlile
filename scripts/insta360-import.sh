#!/bin/bash
#
# insta360-import.sh — move Insta360 footage onto a RAID (or any external drive)
# and free up space on the camera and the Mac.
#
# Every file is copied, then compared byte-for-byte against the original.
# Originals are deleted only after that check passes, and only after you
# confirm. Anything that fails to copy or verify is left where it was.
#
# Footage is filed by the date in the Insta360 filename:
#   <RAID>/Insta360/2026/2026-09-24/VID_20260924_101523_00_012.insv
#
# Usage:
#   ./insta360-import.sh [options] /Volumes/<YourRAID>
#
# Options:
#   -s DIR   Also move Insta360 files out of this folder on the Mac
#            (e.g. ~/Movies/Insta360). Can be given more than once.
#   -f NAME  Folder on the RAID to import into (default: Insta360)
#   -n       Dry run: show what would happen, touch nothing
#   -k       Keep originals (copy + verify only, delete nothing)
#   -y       Don't ask before deleting originals
#   -e       Eject the camera / SD card when finished
#   -h       Show this help
#
# The camera is found automatically: plug it in over USB (choose "USB drive"
# mode on the camera if it asks) or put its microSD card in a card reader.
#
# Written for the stock macOS bash (3.2) — no Homebrew needed.

set -o pipefail

SUBFOLDER="Insta360"
DRY_RUN=0
KEEP=0
ASSUME_YES=0
EJECT=0
LOCAL_DIRS=()

usage() { sed -n '2,/^# Written/p' "$0" | sed -e 's/^# \{0,1\}//' -e '$d'; exit "${1:-0}"; }

while getopts "s:f:nkyeh" opt; do
  case "$opt" in
    s) LOCAL_DIRS+=("${OPTARG%/}") ;;
    f) SUBFOLDER="$OPTARG" ;;
    n) DRY_RUN=1 ;;
    k) KEEP=1 ;;
    y) ASSUME_YES=1 ;;
    e) EJECT=1 ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done
shift $((OPTIND - 1))

[ $# -eq 1 ] || usage 1
RAID="${1%/}"

# ── helpers ───────────────────────────────────────────────────────────────────

die()  { echo "Error: $*" >&2; exit 1; }
say()  { echo "$*" | tee -a "$LOG"; }

human() {  # bytes -> "12.3 GB"
  awk -v b="$1" 'BEGIN { split("B KB MB GB TB", u, " "); i = 1;
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf (i == 1 ? "%d %s" : "%.1f %s"), b, u[i] }'
}

fsize() { stat -f %z "$1"; }

# YYYYMMDD from an Insta360 name (VID_20260924_101523_00_012.insv),
# falling back to the file's modification date.
file_date() {
  local d
  d=$(basename "$1" | sed -nE 's/^.*_([12][0-9]{7})_[0-9]{6}.*$/\1/p')
  [ -n "$d" ] || d=$(stat -f %Sm -t %Y%m%d "$1")
  echo "$d"
}

# Insta360 files in a Mac folder: .insv/.insp/.lrv, plus .mp4/.jpg/.dng that
# carry the camera's naming (VID_/IMG_/LRV_/PRO_…). Other files are ignored.
is_insta_name() {
  local n; n=$(basename "$1" | tr '[:upper:]' '[:lower:]')
  case "$n" in
    ._*) return 1 ;;
    *.insv|*.insp|*.lrv) return 0 ;;
  esac
  echo "$n" | grep -Eq '^(vid|img|lrv|pro_vid|pro_lrv)_[0-9]{8}_[0-9]{6}.*\.(mp4|jpg|dng)$'
}

# ── checks ────────────────────────────────────────────────────────────────────

[ "$(uname)" = "Darwin" ] || echo "Warning: this script is written for macOS." >&2
case "$RAID" in
  /Volumes/*) ;;
  *) die "'$RAID' isn't under /Volumes — pass the RAID's mount point, e.g. /Volumes/MyRAID" ;;
esac
[ -d "$RAID" ] || die "'$RAID' isn't mounted. Check Finder / Disk Utility."
[ -w "$RAID" ] || die "Can't write to '$RAID'."

DEST="$RAID/$SUBFOLDER"
LOGDIR="$DEST/_import-logs"
if [ $DRY_RUN -eq 1 ]; then
  LOG=/dev/null
else
  mkdir -p "$LOGDIR" || die "Can't create $LOGDIR"
  LOG="$LOGDIR/import-$(date +%Y%m%d-%H%M%S).log"
fi

for d in ${LOCAL_DIRS[@]+"${LOCAL_DIRS[@]}"}; do
  [ -d "$d" ] || die "Folder not found: $d"
  case "$d/" in "$RAID"/*) die "$d is on the RAID itself" ;; esac
done

# Keep the Mac awake while this runs.
command -v caffeinate >/dev/null && caffeinate -i -w $$ &

# ── find footage ──────────────────────────────────────────────────────────────

LIST=$(mktemp "${TMPDIR:-/tmp}/insta360-import.XXXXXX") || die "mktemp failed"
trap 'rm -f "$LIST" "$LIST.ok"' EXIT
: > "$LIST.ok"

CAMERAS=()
for vol in /Volumes/*; do
  [ "$vol" = "$RAID" ] && continue
  [ -d "$vol/DCIM" ] || continue
  found=0
  for cam in "$vol"/DCIM/Camera*; do
    [ -d "$cam" ] || continue
    if find "$cam" -type f \( -iname '*.insv' -o -iname '*.insp' -o -iname '*.lrv' \) | grep -q .; then
      found=1
      # On the camera, take everything in the Camera folders except macOS junk.
      find "$cam" -type f ! -name '._*' ! -name '.DS_Store' -print0 >> "$LIST"
    fi
  done
  [ $found -eq 1 ] && CAMERAS+=("$vol")
done

for d in ${LOCAL_DIRS[@]+"${LOCAL_DIRS[@]}"}; do
  find "$d" -type f ! -name '._*' -print0 | while IFS= read -r -d '' f; do
    is_insta_name "$f" && printf '%s\0' "$f"
  done >> "$LIST"
done

COUNT=0; TOTAL=0
while IFS= read -r -d '' f; do
  COUNT=$((COUNT + 1)); TOTAL=$((TOTAL + $(fsize "$f")))
done < "$LIST"

say "Insta360 import — $(date)"
say "Destination: $DEST"
if [ ${#CAMERAS[@]} -gt 0 ]; then
  for c in "${CAMERAS[@]}"; do say "Camera/card: $c"; done
else
  say "Camera/card: none found (plug the camera in as a USB drive, or use a card reader)"
fi
for d in ${LOCAL_DIRS[@]+"${LOCAL_DIRS[@]}"}; do say "Mac folder:  $d"; done
say "Found $COUNT files, $(human $TOTAL)"
[ $COUNT -gt 0 ] || { say "Nothing to import."; exit 0; }

AVAIL=$(( $(df -k "$RAID" | awk 'NR==2 {print $4}') * 1024 ))
say "Free on RAID: $(human $AVAIL)"
[ $AVAIL -gt $TOTAL ] || die "Not enough free space on $RAID."

# ── copy + verify ─────────────────────────────────────────────────────────────

say ""
i=0; COPIED=0; SKIPPED=0; FAILED=0; FREEABLE=0
while IFS= read -r -d '' src; do
  i=$((i + 1))
  name=$(basename "$src")
  day=$(file_date "$src")
  dir="$DEST/${day:0:4}/${day:0:4}-${day:4:2}-${day:6:2}"
  dst="$dir/$name"
  size=$(fsize "$src")
  tag="[$i/$COUNT] $name ($(human $size))"

  if [ $DRY_RUN -eq 1 ]; then
    echo "$tag -> ${dst#$RAID/}"
    continue
  fi

  # Already on the RAID? If it's identical, the original is safe to remove.
  # If a different file has the same name, save this one alongside it.
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      say "$tag  already on RAID, identical"
      printf '%s\0' "$src" >> "$LIST.ok"
      SKIPPED=$((SKIPPED + 1)); FREEABLE=$((FREEABLE + size))
      continue
    fi
    base="${name%.*}"; ext="${name##*.}"; n=2
    while [ -e "$dir/$base-$n.$ext" ]; do n=$((n + 1)); done
    dst="$dir/$base-$n.$ext"
    say "$tag  name clash, saving as $(basename "$dst")"
  fi

  mkdir -p "$dir" || { say "$tag  FAILED: can't create $dir"; FAILED=$((FAILED + 1)); continue; }
  printf '%s  copying… ' "$tag"
  if cp -p "$src" "$dst.part" && cmp -s "$src" "$dst.part" && mv "$dst.part" "$dst"; then
    echo "verified"
    echo "$tag -> ${dst#$RAID/}  verified" >> "$LOG"
    printf '%s\0' "$src" >> "$LIST.ok"
    COPIED=$((COPIED + 1)); FREEABLE=$((FREEABLE + size))
  else
    echo "FAILED"
    echo "$tag  FAILED — original kept" >> "$LOG"
    rm -f "$dst.part"
    FAILED=$((FAILED + 1))
  fi
done < "$LIST"

if [ $DRY_RUN -eq 1 ]; then
  echo ""
  echo "Dry run — nothing was copied or deleted."
  exit 0
fi

sync  # make sure everything has actually hit the RAID before deleting
say ""
say "Copied + verified: $COPIED   Already on RAID: $SKIPPED   Failed: $FAILED"
[ $FAILED -eq 0 ] || say "Failed files were NOT deleted — re-run the script to retry them."

# ── free up space ─────────────────────────────────────────────────────────────

VERIFIED=$((COPIED + SKIPPED))
if [ $KEEP -eq 1 ] || [ $VERIFIED -eq 0 ]; then
  say "Originals kept. Log: $LOG"
  exit $([ $FAILED -eq 0 ] && echo 0 || echo 2)
fi

if [ $ASSUME_YES -eq 0 ]; then
  echo ""
  printf 'Delete %d verified originals from the camera/Mac to free %s? [y/N] ' "$VERIFIED" "$(human $FREEABLE)"
  read -r answer < /dev/tty
  case "$answer" in
    [yY]*) ;;
    *) say "Originals kept. Log: $LOG"; exit 0 ;;
  esac
fi

DELETED=0
while IFS= read -r -d '' src; do
  rm -f "$src" && DELETED=$((DELETED + 1)) && echo "deleted $src" >> "$LOG"
done < "$LIST.ok"
say "Deleted $DELETED originals, freed $(human $FREEABLE)."

# Tidy up folders emptied on the Mac (the folder you passed is kept).
for d in ${LOCAL_DIRS[@]+"${LOCAL_DIRS[@]}"}; do
  find "$d" -mindepth 1 -name .DS_Store -delete 2>/dev/null
  find "$d" -mindepth 1 -type d -empty -delete 2>/dev/null
done

if [ $EJECT -eq 1 ]; then
  for c in ${CAMERAS[@]+"${CAMERAS[@]}"}; do
    diskutil eject "$c" >/dev/null && say "Ejected $c"
  done
fi

say "Done. Log: $LOG"
exit $([ $FAILED -eq 0 ] && echo 0 || echo 2)
