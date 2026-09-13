# 🐴 OmaPony

> **The high-octane media downloader & offline Whisper AI transcriber for Omarchy Linux.**

A sleek, lightweight, and modern status bar widget and background download daemon for [Omarchy Linux](https://omarchy.org/) running Hyprland and Quickshell.

Featuring automatic platform link detection, high-bitrate video/audio extraction, synchronized subtitle generation, and 100% offline speech recognition powered by local Whisper AI.

<p align="center">
  <img src="assets/screenshot.png" alt="OmaPony Interface Preview" width="680" />
</p>

---

## ✨ Features

- **🐴 Sleek Horse Head Bar Widget**: Sits cleanly on the top-right status bar with perfect optical alignment and theme integration. Smoothly transitions into an animated spinner (`󰑋`) with active colors and progress tooltips during live downloads.
- **⚡ Superkey Instant Link Capture**: Highlight or copy any video/audio URL anywhere on your screen and hit `SUPER + ALT + V` to grab and enqueue the download instantly in the background with desktop notifications.
- **🚦 Concurrency-Limited Queue**: Intelligent background queue manager with configurable concurrency cap (`max_concurrent: 2`). Never saturates your CPU or bandwidth when batch-grabbing multiple links—active jobs download smoothly while remaining jobs queue safely in line.
- **⚡ Real-Time Push IPC (Unix Socket)**: Replaced 1-second file polling with a direct Unix domain socket push (`$XDG_RUNTIME_DIR/omapony.sock`). Delivers instantaneous 150ms progress bar animations, live transfer speeds, and ETA ticks without continuous disk polling.
- **📑 Automatic Playlist Support & Fan-Out**: Automatically detects multi-video playlists (YouTube, SoundCloud sets, etc.) and fans them out into individual queued jobs with real video titles. Paste one playlist link and watch all videos populate the queue.
- **🎙️ Async / Detached Offline Whisper AI**:
  - Local speech-to-text running directly on your hardware via `whisper.cpp` (`whisper-cli`).
  - **Detached execution**: Downloads finish and pop into history immediately so you can play or access them right away, while Whisper continues transcribing in the background.
  - Zero cloud reliance, zero subscriptions, zero API keys, and 100% private.
  - Generates synchronized SubRip (`.srt`) and WebVTT (`.vtt`) subtitles (automatically recognized by MPV, VLC, and other players) along with full plaintext transcripts (`.txt`).
  - Model selection: `tiny` (fastest), `base` (recommended default), and `small`.
- **🎯 Multi-Platform Auto-Detection**: Real-time link inspection with platform-colored badges and icons:
  - **YouTube & Playlists** (`󰗃 YouTube` / `󰑋 YouTube Playlist` — Red accent)
  - **X / Twitter** (`󰕄 X / Twitter` — Blue accent)
  - **Instagram** (`󰋙 Instagram` — Magenta accent)
  - **Facebook** (`󰈦 Facebook` — Blue accent)
  - **TikTok** (`󰎁 TikTok` — Cyan accent)
  - **Reddit** (`󰑍 Reddit` — Orange accent)
  - **Web Video** (`󰈫 Generic Stream` — Theme accent)
- **🎵 Video & Audio Extraction Modes**:
  - **Video (MP4)**: Merges the highest quality video and audio streams seamlessly via `yt-dlp` and `ffmpeg`.
  - **Audio Only (MP3)**: Extracts clean, high-fidelity 320kbps MP3 audio.
- **📋 Themed Quickshell Modal**:
  - One-click clipboard link insertion.
  - Live progress bar, download speed, ETA tracking, and Queued badges.
  - Active downloads list with instant cancellation controls.
  - History list with active "󰍬 Transcribing..." badges, subtitle indicators, one-click media play (`󰐊`), and show-in-folder (`󰉋`) actions.
- **💻 CLI & Shell IPC**: Complete terminal and script control via `omapony` CLI and `omarchy-shell omapony <action>`.

---

## 📥 Installation

### One-Command Install (Omarchy Plugin Manager)

```bash
omarchy plugin add https://github.com/tonythesuperpony/omapony.git --enable
ln -sf ~/.config/omarchy/plugins/omapony/bin/omapony ~/.local/bin/omapony
```

### Manual Installation

Clone directly into your Omarchy shell plugins directory:

```bash
git clone https://github.com/tonythesuperpony/omapony.git ~/.config/omarchy/plugins/omapony
ln -sf ~/.config/omarchy/plugins/omapony/bin/omapony ~/.local/bin/omapony
omarchy plugin enable omapony --section right
```

---

## ⌨️ Superkey Shortcuts

Add to your `~/.config/hypr/bindings.lua`:

```lua
-- OmaPony Media Downloader:
o.bind("SUPER + ALT + V", "Download selected video/audio (OmaPony)", "omapony grab")
o.bind("SUPER + SHIFT + V", "Toggle OmaPony downloader", "omarchy-shell omapony toggle")
```

| Keybinding | Action | Command |
|---|---|---|
| `SUPER + ALT + V` | Grab highlighted link & start download | `omapony grab` |
| `SUPER + SHIFT + V` | Toggle OmaPony popup panel | `omarchy-shell omapony toggle` |

---

## 🖱️ Status Bar Mouse Actions

| Mouse Button | Action |
|---|---|
| **Left-click** | Open / toggle OmaPony popup panel |
| **Right-click** | Instant grab & download from current selection or clipboard |
| **Middle-click** | Open destination download directory in your file manager |

---

## 🧠 Offline Whisper Setup

OmaPony uses `whisper.cpp` for lightning-fast, offline speech-to-text.

To install the offline engine:

```bash
omarchy pkg add whisper-cpp
```

OmaPony automatically manages GGML models in `~/.local/share/omarchy/omapony/models/`.

---

## 💻 CLI Usage

```bash
# Grab selected text or clipboard and download in background
omapony grab

# Grab as MP3 audio with offline Whisper transcription & subtitles
omapony grab --format audio --transcribe --subtitles

# Manually queue a URL
omapony add "https://www.youtube.com/watch?v=..." --format video

# Queue a playlist (auto-detects and fans out into queued jobs)
omapony add "https://www.youtube.com/playlist?list=..."

# Force single item even if playlist URL:
omapony add "https://www.youtube.com/watch?v=...&list=..." --no-playlist

# Toggle the status bar popup panel
omapony toggle

# Check active queue and history status in JSON
omapony status

# Cancel an active or queued download
omapony cancel dl_1789265324_5e94b6

# Clear download history
omapony clear-history
```

---

## ⚙️ Configuration

OmaPony stores user configuration in `~/.config/omarchy/omapony/config.json`:

```json
{
  "download_dir": "/home/sierra/Videos/OmaPony",
  "audio_dir": "/home/sierra/Music/OmaPony",
  "default_format": "video",
  "auto_transcribe": false,
  "make_subtitles": true,
  "whisper_model": "base",
  "whisper_engine": "auto",
  "max_concurrent": 2,
  "notify": true
}
```

| Setting | Default | Description |
|---|---|---|
| `max_concurrent` | `2` | Maximum concurrent yt-dlp & ffmpeg workers before queuing |
| `default_format` | `"video"` | Default format: `"video"` (MP4) or `"audio"` (MP3) |
| `auto_transcribe` | `false` | Automatically transcribe all downloads with Whisper AI |
| `make_subtitles` | `true` | Generate `.srt` and `.vtt` alongside plaintext transcripts |
| `whisper_model` | `"base"` | Model size: `"tiny"` (fastest), `"base"`, or `"small"` |
| `download_dir` | `~/Videos/OmaPony` | Default video destination directory |
| `audio_dir` | `~/Music/OmaPony` | Default audio destination directory |
| `notify` | `true` | Desktop notifications via `notify-send` |

---

## 🗑️ Uninstallation

To cleanly and completely remove OmaPony from your system:

### 1. Remove the Plugin

Using the Omarchy plugin manager:

```bash
omarchy plugin remove omapony --yes
```

Or manually:

```bash
omarchy plugin disable omapony
rm -rf ~/.config/omarchy/plugins/omapony
omarchy-shell shell rescanPlugins
```

### 2. Remove the CLI Symlink

Remove the command binary symlink from your user PATH:

```bash
rm -f ~/.local/bin/omapony
```

### 3. Remove Keybindings

Remove or comment out the OmaPony keybindings in `~/.config/hypr/bindings.lua`:

```lua
-- Remove or comment out these lines:
-- o.bind("SUPER + ALT + V", "Download selected video/audio (OmaPony)", "omapony grab")
-- o.bind("SUPER + SHIFT + V", "Toggle OmaPony downloader", "omarchy-shell omapony toggle")
```

Then reload your Hyprland configuration (or restart your session).

### 4. Remove Configuration & Cached Models (Optional)

To delete user preferences, download history, and cached Whisper AI GGML models:

```bash
rm -rf ~/.config/omarchy/omapony ~/.local/share/omarchy/omapony
```

> **Note**: Your downloaded video and audio files in `~/Videos/OmaPony` and `~/Music/OmaPony` will remain untouched.

### 5. Remove Whisper Dependencies (Optional)

If you installed `whisper-cpp` solely for OmaPony and no longer need it:

```bash
omarchy pkg remove whisper-cpp
```

---

### ⚡ Quick Complete Uninstall (One-Liner)

To remove the plugin, CLI binary, configuration, and cached models in one shot:

```bash
omarchy plugin remove omapony --yes && rm -f ~/.local/bin/omapony && rm -rf ~/.config/omarchy/omapony ~/.local/share/omarchy/omapony
```
*(Remember to also remove the keybindings from `~/.config/hypr/bindings.lua`)*

---

## 📄 License

MIT © [tonythesuperpony](https://github.com/tonythesuperpony)
