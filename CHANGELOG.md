# Changelog

All notable changes to **OmaPony** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-09-13

### 🚀 Added

- **Concurrency-Limited Download Queue**:
  - Implemented configurable worker concurrency limits (`max_concurrent`, defaulting to `2`).
  - Added atomic queue scheduler (`process_queue`) with advisory file locking via `fcntl.flock` to guarantee race-free job dispatching across concurrent CLI and background worker invocations.
  - Added queue status states (`queued`, `downloading`, `processing`, `error`).
  - Added visual `QUEUED` indicator badge and dimmed progress state in the active download list for waiting jobs.
  - Automatically checks worker PID health and advances queued jobs immediately as active slots free up or jobs are cancelled.

- **Async & Detached Whisper AI Transcription**:
  - Split offline Whisper speech-to-text into a detached background worker (`_transcribe`).
  - Completed downloads now finalize and appear in **Recent Downloads** history immediately, allowing instant playback (`󰐊`) and file browsing (`󰉋`) without waiting for transcription to finish.
  - Added real-time `"󰍬 Transcribing..."` accent badge in history items while speech recognition runs in the background.
  - Transitions to `"CC / Subs"` badge automatically once `.srt` and `.vtt` subtitles are saved.
  - Sends asynchronous completion desktop notifications when subtitles and transcripts are ready.

- **Push-Based IPC via Unix Domain Socket**:
  - Replaced 1000ms disk file polling in `BarWidget.qml` with a high-performance Unix domain socket (`$XDG_RUNTIME_DIR/omapony.sock`).
  - Worker processes push progress packets every 150ms directly into Quickshell via `SocketServer` and `SplitParser`.
  - Delivers fluid, near-instant progress bar animations, live transfer speeds, and ETA ticks with zero polling lag and minimal CPU/disk I/O.
  - Preserves low-overhead fallback timer for background state resilience.

- **Full Playlist Detection & Queue Fan-Out**:
  - Added automatic playlist detection for YouTube, SoundCloud sets, and supported streaming platforms using `yt-dlp --flat-playlist`.
  - Automatically fans out playlist items into individual queued download jobs, pre-populating accurate video titles.
  - Added `󰑋 YouTube Playlist` platform badge in link input live detection.
  - Added `--playlist` (force playlist extraction) and `--no-playlist` (download single video only) CLI flags to `omapony add` and `omapony grab`.
  - Desktop notifications announce the playlist title and total number of enqueued items.

### ⚡ Changed
- Reduced `BarWidget.qml` progress animation duration to 150ms for snappier visual tracking.
- Throttled `state.json` disk writes during active downloads from continuous polling down to 1.5s intervals, significantly reducing SSD wear while push IPC maintains 150ms UI fluidity.
- Added `max_concurrent: 2` to `~/.config/omarchy/omapony/config.json`.

---

## [1.0.0] - 2026-09-12

### 🎉 Initial Release
- Themed Quickshell top-bar widget with horse head icon (`\uf7ab`) and animated spinner (`󰑋`).
- Instant superkey link capture via `SUPER + ALT + V` (`omapony grab`) and Wayland primary selection/clipboard inspection.
- 100% offline Whisper AI transcription powered by `whisper.cpp` (`whisper-cli`) generating `.srt`, `.vtt`, and `.txt` files.
- Multi-platform auto-detection (YouTube, X/Twitter, Instagram, Facebook, TikTok, Reddit, Web Video).
- Dual extraction modes: Video (MP4) and Audio Only (MP3 320kbps).
- Themed Quickshell modal panel with live progress, active downloads, and history viewer.
- Full CLI control: `grab`, `add`, `detect`, `status`, `cancel`, `clear-history`, `open`, `open-dir`, `install-whisper`.
