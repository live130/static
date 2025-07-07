#!/bin/bash

set -e

INPUT="$1"
OUTDIR="$2"
if [[ -z "$INPUT" || ! -f "$INPUT" ]]; then
  echo "Usage: $0 input.mp4 output_directory"
  exit 1
fi

if [[ -z "$OUTDIR" || ! -d "$OUTDIR" ]]; then
  echo "Usage: $0 input.mp4 output_directory"
  exit 1
fi

BASENAME=$(basename "$INPUT" | sed 's/\.[^.]*$//')
TMPDIR="$OUTDIR/tmp"
FMP4DIR="$OUTDIR/fmp4"
TSDIR="$OUTDIR/ts"
PREFIX="https://raw.githubusercontent.com/live130/static/refs/heads/main"

mkdir -p "$TMPDIR" "$FMP4DIR" "$TSDIR"

PACKAGER_BIN="packager"  # Must be in PATH
SEGMENT_DURATION=6

RESOLUTIONS=("1080" "720" "480")
BITRATES=("5000k" "2500k" "1000k")

echo "🎬 Step 1: Transcoding to 1080p, 720p, 480p MP4s..."
for i in "${!RESOLUTIONS[@]}"; do
  RES=${RESOLUTIONS[$i]}
  BR=${BITRATES[$i]}
  echo "➡️  Transcoding to ${RES}p..."

  ffmpeg -y -i "$INPUT" \
    -vf "scale=-2:$RES" \
    -c:v libx264 -b:v "$BR" -preset veryfast \
    -c:a aac -b:a 128k \
    "$TMPDIR/${BASENAME}_${RES}.mp4"
done

echo "✅ Transcoding complete."
echo "📦 Step 3: Packaging with Shaka Packager - fMP4 HLS..."
$PACKAGER_BIN \
  in="$TMPDIR/${BASENAME}_1080.mp4",stream=video,init_segment="$FMP4DIR/1080/video_init.mp4",segment_template="$FMP4DIR/1080/video_\$Number\$.m4s",playlist_name="1080/video.m3u8" \
  in="$TMPDIR/${BASENAME}_1080.mp4",stream=audio,init_segment="$FMP4DIR/audio/audio_init.mp4",segment_template="$FMP4DIR/audio/audio_\$Number\$.m4s",playlist_name="audio/audio.m3u8" \
  in="$TMPDIR/${BASENAME}_720.mp4",stream=video,init_segment="$FMP4DIR/720/video_init.mp4",segment_template="$FMP4DIR/720/video_\$Number\$.m4s",playlist_name="720/video.m3u8" \
  in="$TMPDIR/${BASENAME}_480.mp4",stream=video,init_segment="$FMP4DIR/480/video_init.mp4",segment_template="$FMP4DIR/480/video_\$Number\$.m4s",playlist_name="480/video.m3u8" \
  --hls_master_playlist_output "$FMP4DIR/master.m3u8" \
  --segment_duration $SEGMENT_DURATION --hls_base_url "$PREFIX/$FMP4DIR/"

echo "📦 Step 4: Packaging with Shaka Packager - MPEG-TS HLS..."
$PACKAGER_BIN \
  in="$TMPDIR/${BASENAME}_1080.mp4",stream=video,segment_template="$TSDIR/1080/video_\$Number\$.ts",playlist_name="1080/video.m3u8" \
  in="$TMPDIR/${BASENAME}_1080.mp4",stream=audio,segment_template="$TSDIR/audio/audio_\$Number\$.ts",playlist_name="audio/audio.m3u8" \
  in="$TMPDIR/${BASENAME}_720.mp4",stream=video,segment_template="$TSDIR/720/video_\$Number\$.ts",playlist_name="720/video.m3u8" \
  in="$TMPDIR/${BASENAME}_480.mp4",stream=video,segment_template="$TSDIR/480/video_\$Number\$.ts",playlist_name="480/video.m3u8" \
  --hls_master_playlist_output "$TSDIR/master.m3u8" \
  --segment_duration $SEGMENT_DURATION --hls_base_url "$PREFIX/$TSDIR/"

echo "🧹 Cleaning up temp files..."
rm -rf "$TMPDIR"

echo "✅ All done."
echo "📁 fMP4 HLS: $FMP4DIR"
echo "📁 MPEG-TS HLS: $TSDIR"
