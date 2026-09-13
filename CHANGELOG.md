# Changelog

All notable changes to **OmaPony** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.2] - 2026-09-13

### 🐛 Fixed
- **Process Group Termination on Cancel**: Updated `cmd_cancel` to terminate the entire process group using `os.killpg()`, ensuring child processes (`yt-dlp` and `ffmpeg`) are reliably killed rather than orphaned in the background.
- **Bar Icon Spinner Reset**: Added `onRunningChanged` and `onHasActiveDownloadsChanged` handlers in `BarWidget.qml` to snap the icon rotation back to `0` when downloads finish, preventing the horse head icon from freezing upside down.
- **Active Download Error Visibility**: Added an `ERROR` badge, urgent styling, and inline display of `error_message` on active download cards so failed downloads are clearly visible and dismissible.
- **Whisper False-Positive Success Notification**: Fixed `cmd_transcribe` notification logic to verify that transcripts or subtitles were actually generated before announcing success, and notify properly on failure.
- **Multi-Language Whisper Transcription**: Added `-l auto` to `whisper-cli` arguments to allow automatic spoken language detection rather than defaulting to English-only (`-l en`).
- **Safe Directory Opening**: Fixed `cmd_open_dir` to check for file extensions on non-existent paths, preventing the accidental creation of directories named after deleted files.
- **Audio Extraction Path Resolution**: Added `after_video` print hook to `yt-dlp` arguments so post-processed audio files (`.mp3`) are correctly tracked rather than lost or misattributed.

### ⚡ Performance & Optimization
- **Non-Blocking Progress State Writes**: Added an optional `sync` flag to `save_state()`, using asynchronous flushes without synchronous `os.fsync()` disk barriers during routine progress updates.
- **Batch Playlist Queueing**: Added `add_jobs()` helper to enqueue playlist entries in a single advisory file lock and disk write cycle instead of up to 100 sequential write/fsync cycles.
- **History Delegate Memoization**: Memoized `displayedHistory` in `BarWidget.qml` to prevent `Repeater` from needlessly re-instantiating all history delegate cards on every progress tick.
- **Eliminated Redundant Polling Timer**: Replaced 100ms timer with reactive inotify and Unix socket events, idling the refresh timer when the panel is closed.

### ⌨️ UX & Keyboard Navigation
- **Playlist & Mix Detection with Single-Video Differentiation**: Added `parseMediaUrl` (in both JavaScript and Python) to accurately identify whether a URL is a pure playlist or a single video containing playlist context (e.g. `youtu.be/...?...list=...` or `watch?v=...&list=...`).
- **Live Playlist Warning Banner**: Added a styled warning banner below the URL input alerting users when a link contains playlist parameters.
- **Single Video vs. Playlist Choice**: Provided distinct primary and secondary action buttons (`Download Single Video` and `Download Entire Playlist`) when a video with playlist context is entered, cleanly stripping playlist parameters and passing `--no-playlist` to avoid accidental mass downloads.
- **Playlist Download Confirmation Modal**: Integrated `ConfirmDialog` modal in `BarWidget.qml` to verify user intent before queuing an entire playlist.
- **Accidental Queue Flood Prevention**: Updated `omapony add` and `omapony grab` CLI commands to default safely to downloading only the single video when video IDs are present, requiring explicit `--playlist` to fan out.
- **Escape Key Dismissal**: Added `Keys.onEscapePressed` to `urlInput` in `BarWidget.qml` so the popup panel can be dismissed with `Escape` even while the text field has active focus.

---

## [1.1.1] - 2026-09-13

### ⚡ Performance & Optimization
- **Operational Unix Domain Socket Server**: Fully wired Quickshell `SocketServer` with `Component { Socket { parser: SplitParser ... } }` listening on `$XDG_RUNTIME_DIR/omapony.sock`, fulfilling real-time event-driven UI updates with zero polling lag.
- **Whisper Detection Caching**: Added in-memory caching to `detect_whisper_engine()` to eliminate redundant `$PATH` directory searches (saving 30+ filesystem traversals per second during active downloads).
- **GPU-Composited Spinner Animation**: Replaced 100ms JavaScript polling timer for the bar icon spinner with a native declarative `RotationAnimation` running on the render thread.
- **Optimized Theme Palette Lookups**: Replaced 27 repeated `Color.accent.r/g/b` component decompositions with shared `readonly property color accentAlphaXX` bindings.
- **Lazy Directory Creation**: Deferred directory initialization from module load time to runtime `ensure_dirs()`.
- **Lightweight Visibility Checks**: Replaced regex string trim check on URL textfield with direct `.length > 0` check on input change.

### 🐛 Fixed
- **Atomic State Writes**: Rewrote `save_state()` to write to `.tmp`, invoke `os.fsync()`, and atomically replace `state.json`, eliminating JSON corruption race conditions with QML's file watcher.
- **Undefined `handleIpcMessage` Error**: Fixed `IpcHandler`'s `progress` method to invoke `stateFile.reload()`, eliminating runtime `TypeError`.
- **Undefined `stream_count` in Fallback Parser**: Replaced missing `stream_count` variable in the fallback `[download]` progress parser with `saw_video_stream`.
- **Redundant State Reloads**: Removed duplicate `stateFile.reload()` in `onOpenedChanged` to prevent triple-fire reloads on panel expansion.
- **Non-Destructive State Lock**: Switched lock file open mode in `state_lock()` from `"w"` to `"a"` to avoid truncating `.state.lock`.
- **Cleaned Up Debug Output**: Removed left-over `[omapony-debug]` console logging statements.

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

- **Calibrated Bar Icon Optical Alignment**:
  - Calibrated the standard Font Awesome horse head icon (`\uf7ab`) optical offsets to align sub-pixel perfectly with neighboring system indicators (network, audio, and display).

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
