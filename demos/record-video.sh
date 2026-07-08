#!/usr/bin/env bash
# record-video.sh — Record PIHARNESS demo videos using ffmpeg
# Requires: ffmpeg, asciinema
#
# Usage:
#   ./demos/record-video.sh              # Record all 7 demos as MP4
#   ./demos/record-video.sh --list       # List available demos
#   ./demos/record-video.sh 1 3 5        # Record specific demos by number
#   ./demos/record-video.sh --clean      # Remove all video recordings
#
# For actual screen recording (ffmpeg desktop capture), run:
#   ./demos/record-video.sh --screen     # Captures your monitor instead

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RECORDINGS_DIR="$SCRIPT_DIR/demos/recordings"

# Demo definitions: number:label:script
DEMOS=(
  "1:spawn-auto:demo-01-spawn-auto.sh"
  "2:status:dashboard:demo-02-status.sh"
  "3:pipeline:demo-03-pipeline.sh"
  "4:self-evolve-nightly:demo-04-self-evolve.sh"
  "5:supervise:demo-05-supervise.sh"
  "6:usage-stats:demo-06-usage.sh"
  "7:skill-list:demo-07-skill-list.sh"
)

list_demos() {
  echo "Available demos:"
  for entry in "${DEMOS[@]}"; do
    num="${entry%%:*}"
    rest="${entry#*:}"
    label="${rest%%:*}"
    script="${rest#*:}"
    printf "  [%s] %s  (%s)\n" "$num" "$label" "$script"
  done
  echo ""
  echo "Recordings dir: $RECORDINGS_DIR"
  echo "Existing recordings:"
  ls -1 "$RECORDINGS_DIR"/*.mp4 2>/dev/null || echo "  (none)"
}

record_terminal() {
  local num="$1"
  local label="$2"
  local script="$3"
  local input_cast="$RECORDINGS_DIR/demo-0${num}-${label}.cast"
  local output_mp4="$RECORDINGS_DIR/demo-0${num}-${label}.mp4"

  if [[ ! -f "$input_cast" ]]; then
    echo "[SKIP] $input_cast not found. Run asciinema recording first."
    return
  fi

  echo "[RECORD] $label → $(basename "$output_mp4")"

  # Convert asciicast to TTY recording using agg, or fallback to ffmpeg
  if command -v agg &>/dev/null; then
    agg --font-size 14 --cols 100 --rows 30 "$input_cast" "$output_mp4" 2>&1
    echo "  -> Done (via agg)"
  else
    echo "  Note: Install 'agg' for better conversion: brew install agg"
    echo "  Fallback: playing cast to terminal and recording with ffmpeg..."
    # Fallback: open terminal, play cast, capture with ffmpeg
    # This requires a running terminal — see --screen mode
    echo "  (Use 'brew install agg' for automated conversion)"
  fi
}

record_screen() {
  echo "=== Screen Recording Mode ==="
  echo "Captures your desktop while running demo scripts."
  echo "Available displays:"
  ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -E "\\[|Capture" || true
  echo ""
  read -r -p "Enter display index (default: 1): " DISPLAY_IDX
  DISPLAY_IDX="${DISPLAY_IDX:-1}"

  read -r -p "Enter demo number to run (1-7, or 'all'): " DEMO_NUM

  OUTPUT="$RECORDINGS_DIR/screen-recording-$(date +%Y%m%d-%H%M%S).mp4"
  echo "Recording to: $OUTPUT"
  echo "Press Ctrl+C to stop recording."
  echo ""

  if [[ "$DEMO_NUM" == "all" ]]; then
    # Run setup then all demos sequentially
    bash "$SCRIPT_DIR/demos/setup.sh"
    for entry in "${DEMOS[@]}"; do
      num="${entry%%:*}"
      script="${entry##*:}"
      echo "=== Running demo $num ===" > /dev/tty
    done
  fi

  # Start ffmpeg screen capture and run the demo
  ffmpeg -f avfoundation -i "${DISPLAY_IDX}:none" \
    -pix_fmt yuv420p -r 15 \
    -t 00:05:00 \
    "$OUTPUT" &
  FFMPEG_PID=$!

  # Wait for ffmpeg to start
  sleep 2

  # Run the demo
  if [[ "$DEMO_NUM" != "all" ]]; then
    for entry in "${DEMOS[@]}"; do
      num="${entry%%:*}"
      if [[ "$num" == "$DEMO_NUM" ]]; then
        script="${entry##*:}"
        bash "$SCRIPT_DIR/demos/$script"
        break
      fi
    done
  fi

  # Stop recording
  kill "$FFMPEG_PID" 2>/dev/null || true
  echo ""
  echo "Screen recording saved to: $OUTPUT"
}

# --- Main ---
mkdir -p "$RECORDINGS_DIR"

case "${1:-}" in
  --list|-l)
    list_demos
    exit 0
    ;;
  --clean|-c)
    rm -f "$RECORDINGS_DIR"/*.mp4
    echo "Cleaned all MP4 recordings."
    exit 0
    ;;
  --screen|-s)
    record_screen
    exit 0
    ;;
  --help|-h)
    echo "Usage: $0 [--list|--clean|--screen|demo_numbers...]"
    echo ""
    echo "  (no args)    Convert all asciinema .cast files to .mp4"
    echo "  1 3 5        Convert specific demos by number"
    echo "  --list       List available demos"
    echo "  --screen     Interactive screen recording mode"
    echo "  --clean      Remove all video files"
    exit 0
    ;;
esac

if [[ $# -gt 0 ]]; then
  # Record specific demos
  for arg in "$@"; do
    for entry in "${DEMOS[@]}"; do
      num="${entry%%:*}"
      if [[ "$num" == "$arg" ]]; then
        rest="${entry#*:}"
        label="${rest%%:*}"
        script="${rest#*:}"
        record_terminal "$num" "$label" "$script"
      fi
    done
  done
else
  # Record all demos
  for entry in "${DEMOS[@]}"; do
    num="${entry%%:*}"
    rest="${entry#*:}"
    label="${rest%%:*}"
    script="${rest#*:}"
    record_terminal "$num" "$label" "$script"
  done
fi

echo ""
echo "Done. Recordings in: $RECORDINGS_DIR"
