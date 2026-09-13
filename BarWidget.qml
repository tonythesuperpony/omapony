import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omapony"
  ipcTarget: ""
  manageIpc: false

  IpcHandler {
    target: "omapony"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function reload(): void {
      console.log("[omapony-debug] IPC reload invoked!")
      stateFile.reload()
    }
    function progress(payload: string): void {
      console.log("[omapony-debug] IPC progress invoked: " + payload)
      root.handleIpcMessage(payload)
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight



  // State
  readonly property string statePath: Quickshell.env("HOME") + "/.local/share/omarchy/omapony/state.json"
  readonly property string socketPath: {
    var rt = Quickshell.env("XDG_RUNTIME_DIR")
    if (rt && rt !== "") return rt + "/omapony.sock"
    return Quickshell.env("HOME") + "/.local/share/omarchy/omapony/omapony.sock"
  }
  property var stateData: ({ "active": [], "history": [], "whisper_available": false, "whisper_engine": "none" })
  readonly property var activeJobs: stateData && stateData.active ? stateData.active : []
  readonly property var historyJobs: stateData && stateData.history ? stateData.history : []
  readonly property int activeDownloadsCount: activeJobsModel.count
  readonly property bool hasActiveDownloads: activeDownloadsCount > 0
  readonly property bool whisperAvailable: stateData && stateData.whisper_available === true
  readonly property string whisperEngine: stateData && stateData.whisper_engine ? stateData.whisper_engine : "none"

  ListModel {
    id: activeJobsModel
  }

  function syncActiveModel(jobs) {
    if (!jobs) jobs = []
    var existingMap = {}
    for (var i = 0; i < activeJobsModel.count; i++) {
      var it = activeJobsModel.get(i)
      existingMap[it.jobId] = i
    }

    var incomingIds = {}
    for (var j = 0; j < jobs.length; j++) {
      var job = jobs[j]
      var jid = String(job.id || "")
      if (!jid) continue
      incomingIds[jid] = true
      var p = (job.progress !== undefined && job.progress !== null) ? Number(job.progress) : 0
      var s = String(job.speed || "--")
      var e = String(job.eta || "--")
      var t = String(job.title || job.url || "")
      var st = String(job.status || "downloading")
      var fmt = String(job.format || "video")
      var p_icon = String(job.platform_icon || "")
      var p_col = String(job.platform_color || "")

      if (existingMap[jid] !== undefined) {
        var idx = existingMap[jid]
        activeJobsModel.setProperty(idx, "jobProgress", p)
        activeJobsModel.setProperty(idx, "jobSpeed", s)
        activeJobsModel.setProperty(idx, "jobEta", e)
        activeJobsModel.setProperty(idx, "jobTitle", t)
        activeJobsModel.setProperty(idx, "jobStatus", st)
        activeJobsModel.setProperty(idx, "jobFormat", fmt)
        activeJobsModel.setProperty(idx, "jobPlatformIcon", p_icon)
        activeJobsModel.setProperty(idx, "jobPlatformColor", p_col)
      } else {
        activeJobsModel.append({
          "jobId": jid,
          "jobProgress": p,
          "jobSpeed": s,
          "jobEta": e,
          "jobTitle": t,
          "jobStatus": st,
          "jobFormat": fmt,
          "jobPlatformIcon": p_icon,
          "jobPlatformColor": p_col
        })
      }
    }

    for (var k = activeJobsModel.count - 1; k >= 0; k--) {
      if (!incomingIds[activeJobsModel.get(k).jobId]) {
        activeJobsModel.remove(k)
      }
    }
  }

  // User input & options
  property string selectedFormat: "video" // "video" or "audio"
  property bool transcribeEnabled: false
  property bool subtitlesEnabled: true
  property string whisperModel: "base" // "tiny", "base", "small"
  property bool showHelpDrawer: false

  // Live platform detection for typed/pasted URL
  property var detectedPlatform: detectPlatform(urlInput.text)

  // Rotating animation icon when downloads are active
  property int spinnerAngle: 0
  Timer {
    interval: 100
    running: root.hasActiveDownloads
    repeat: true
    onTriggered: root.spinnerAngle = (root.spinnerAngle + 30) % 360
  }

  // Fast and smooth refresh timer:
  // When panel is opened: ticks every 100ms for ultra-responsive 10 FPS progress bar & pony gallop
  // When closed with active downloads: ticks every 500ms to keep bar icon spinner rotating
  // When idle & closed: stopped (0% CPU)
  Timer {
    interval: root.opened ? 100 : (root.hasActiveDownloads ? 500 : 2000)
    running: root.opened || root.hasActiveDownloads
    repeat: true
    onTriggered: stateFile.reload()
  }

  onOpenedChanged: {
    if (root.opened) {
      Quickshell.execDetached(["omapony", "status"])
      stateFile.reload()
      Qt.callLater(function() {
        if (root.opened) urlInput.forceActiveFocus()
      })
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.loadState("{}")
    onFileChanged: reload()
  }

  function loadState(raw) {
    try {
      if (raw && raw.trim() !== "") {
        var parsed = JSON.parse(raw)
        root.stateData = parsed
        root.syncActiveModel(parsed.active || [])
      }
    } catch (e) {
      console.warn("omapony: failed to parse state JSON", e)
    }
  }


  function detectPlatform(url) {
    if (!url) return null
    var trimmed = String(url).trim()
    if (trimmed === "") return null
    var lower = trimmed.toLowerCase()

    if (lower.indexOf("youtube.com") !== -1 || lower.indexOf("youtu.be") !== -1) {
      if (lower.indexOf("list=") !== -1 || lower.indexOf("/playlist") !== -1) {
        return { id: "youtube-playlist", name: "YouTube Playlist", icon: "󰑋", color: "#FF0000" }
      }
      return { id: "youtube", name: "YouTube", icon: "󰗃", color: "#FF0000" }
    }
    if (lower.indexOf("x.com") !== -1 || lower.indexOf("twitter.com") !== -1) {
      return { id: "x", name: "X / Twitter", icon: "󰕄", color: "#1DA1F2" }
    }
    if (lower.indexOf("instagram.com") !== -1) {
      return { id: "instagram", name: "Instagram", icon: "󰋙", color: "#E1306C" }
    }
    if (lower.indexOf("facebook.com") !== -1 || lower.indexOf("fb.watch") !== -1) {
      return { id: "facebook", name: "Facebook", icon: "󰈦", color: "#1877F2" }
    }
    if (lower.indexOf("tiktok.com") !== -1) {
      return { id: "tiktok", name: "TikTok", icon: "󰎁", color: "#00F2FE" }
    }
    if (lower.indexOf("reddit.com") !== -1) {
      return { id: "reddit", name: "Reddit", icon: "󰑍", color: "#FF4500" }
    }
    if (lower.indexOf("http://") === 0 || lower.indexOf("https://") === 0) {
      if (lower.indexOf("list=") !== -1 || lower.indexOf("/playlist") !== -1) {
        return { id: "playlist", name: "Media Playlist", icon: "󰑋", color: Color.accent }
      }
      return { id: "web", name: "Web Video", icon: "󰈫", color: Color.accent }
    }
    return null
  }

  function startDownload() {
    var url = urlInput.text.trim()
    if (!url) return

    var cmd = ["omapony", "add", url, "--format", root.selectedFormat]
    if (root.transcribeEnabled) {
      cmd.push("--transcribe")
      if (root.subtitlesEnabled) cmd.push("--subtitles")
      cmd.push("--model", root.whisperModel)
    }
    Quickshell.execDetached(cmd)

    urlInput.text = ""
    stateFile.reload()
  }

  function quickGrab() {
    Quickshell.execDetached(["omapony", "grab"])
    stateFile.reload()
  }

  function cancelJob(jobId) {
    Quickshell.execDetached(["omapony", "cancel", jobId])
    stateFile.reload()
  }

  function clearHistory() {
    Quickshell.execDetached(["omapony", "clear-history"])
    stateFile.reload()
  }

  function openFile(path) {
    if (path) Quickshell.execDetached(["xdg-open", path])
  }

  function openFolder(path) {
    Quickshell.execDetached(["omapony", "open-dir", path || ""])
  }

  function installWhisper() {
    Quickshell.execDetached(["omapony", "install-whisper"])
  }

  // Paste from clipboard helper
  Process {
    id: clipPasteProcess
    command: ["wl-paste", "--no-newline"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        var raw = text.trim()
        if (raw.indexOf("http") !== -1) {
          var match = raw.match(/https?:\/\/[^\s<>"']+/)
          if (match) {
            urlInput.text = match[0]
          }
        }
      }
    }
  }

  Component {
    id: horseHeadIconComponent
    Text {
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: root.hasActiveDownloads ? 0 : 3.17
      anchors.verticalCenterOffset: root.hasActiveDownloads ? 0 : 3.1
      text: root.hasActiveDownloads ? "󰑋" : "\uf7ab"
      font.family: root.hasActiveDownloads ? (root.bar ? root.bar.fontFamily : Style.font.family) : "Font Awesome 7 Free Solid"
      font.styleName: root.hasActiveDownloads ? "" : "Solid"
      font.pixelSize: root.hasActiveDownloads ? Style.bar.iconFont : 9.7
      color: button.active && button.useActiveColor ? button.activeColor : button.foreground
      renderType: Text.NativeRendering
      rotation: root.hasActiveDownloads ? root.spinnerAngle : 0
    }
  }

  // Bar icon
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: horseHeadIconComponent
    active: root.hasActiveDownloads
    useActiveColor: true
    activeColor: Color.accent
    tooltipText: root.hasActiveDownloads
      ? ("Downloading " + root.activeDownloadsCount + " item" + (root.activeDownloadsCount > 1 ? "s" : "") + "...")
      : "OmaPony (Right-click: Grab selection)"

    onPressed: function(btn) {
      if (btn === Qt.RightButton) {
        root.quickGrab()
      } else if (btn === Qt.MiddleButton) {
        root.openFolder("")
      } else {
        root.toggle()
      }
    }
  }

  // Themed Popup Panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: urlInput
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: urlInput.activeFocus
      onCloseRequested: root.close()

      Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: mainColumn
          width: parent.width
          spacing: Style.space(12)

          // ------------------------------------------------------------- Header
          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(38)
              height: Style.space(32)
              radius: Style.cornerRadius
              color: Style.selectedFillFor(Color.foreground, Color.accent)

              Text {
                visible: !root.hasActiveDownloads
                anchors.centerIn: parent
                text: "\uf7ab"
                font.family: "Font Awesome 7 Free Solid"
                font.styleName: "Solid"
                font.pixelSize: Style.font.title
                color: Color.accent
                renderType: Text.NativeRendering
              }

              AnimatedSprite {
                visible: root.hasActiveDownloads
                anchors.centerIn: parent
                width: Style.space(34)
                height: Style.space(25)
                source: Qt.resolvedUrl("assets/caballoNormal.png")
                frameWidth: 111
                frameHeight: 81
                frameCount: 7
                frameX: 0
                frameY: 0
                frameRate: 12
                interpolate: false
                running: root.opened && root.hasActiveDownloads
                loops: AnimatedSprite.Infinite
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                text: "OmaPony"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                color: Color.foreground
              }

              Text {
                text: root.hasActiveDownloads
                  ? ("Downloading " + root.activeDownloadsCount + " item" + (root.activeDownloadsCount > 1 ? "s" : "") + "...")
                  : "YouTube • X • Instagram • Facebook"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.darker(Color.foreground, 1.4)
              }
            }

            // Header Action Buttons
            Button {
              iconText: "󰉋"
              tooltipText: "Open Downloads Folder"
              onClicked: root.openFolder("")
            }

            Button {
              iconText: "󰌌"
              tooltipText: "Keybinding & AI Info"
              selected: root.showHelpDrawer
              onClicked: root.showHelpDrawer = !root.showHelpDrawer
            }

            Button {
              iconText: "󰅖"
              tooltipText: "Close"
              onClicked: root.close()
            }
          }

          // ------------------------------------------------ Keybinding / Info Drawer
          Rectangle {
            width: parent.width
            visible: root.showHelpDrawer
            height: visible ? (helpCol.implicitHeight + Style.space(16)) : 0
            implicitHeight: helpCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
            border.width: 1

            Column {
              id: helpCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(6)

              Text {
                text: "󰌌 Superkey Fast Download"
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                color: Color.accent
              }

              Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Highlight any link on screen and press SUPER+ALT+V to download instantly! Press SUPER+SHIFT+V to toggle this panel."
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.foreground
              }

              Text {
                text: "󰍬 Offline Whisper Transcription"
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                color: Color.accent
              }

              Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: root.whisperAvailable
                  ? ("Engine detected: " + root.whisperEngine + " (100% Offline AI)")
                  : "Whisper is not installed. Click 'Install Whisper' or run 'omarchy pkg add whisper-cpp' to enable offline speech-to-text and subtitle generation."
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: root.whisperAvailable ? Color.foreground : Color.urgent
              }
            }
          }

          // ------------------------------------------------------------- URL Input & Platform Detection
          Column {
            width: parent.width
            spacing: Style.space(6)

            RowLayout {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: urlInput
                Layout.fillWidth: true
                placeholderText: "Paste YouTube, X, Instagram, Facebook link..."
                onAccepted: root.startDownload()
              }

              Button {
                iconText: "󰅍"
                tooltipText: "Paste Link from Clipboard"
                onClicked: clipPasteProcess.running = true
              }

              Button {
                iconText: "󰅖"
                tooltipText: "Clear"
                visible: urlInput.text !== ""
                onClicked: urlInput.text = ""
              }
            }

            // Detected Platform Badge
            Row {
              spacing: Style.space(8)
              visible: root.detectedPlatform !== null

              Rectangle {
                implicitWidth: badgeRow.implicitWidth + Style.space(12)
                implicitHeight: Style.space(22)
                radius: Style.cornerRadius
                color: root.detectedPlatform ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : "transparent"
                border.color: root.detectedPlatform ? root.detectedPlatform.color : "transparent"
                border.width: 1

                Row {
                  id: badgeRow
                  anchors.centerIn: parent
                  spacing: Style.space(5)

                  Text {
                    text: root.detectedPlatform ? root.detectedPlatform.icon : ""
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: root.detectedPlatform ? root.detectedPlatform.color : Color.foreground
                  }

                  Text {
                    text: root.detectedPlatform ? (root.detectedPlatform.name + " Detected") : ""
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Color.foreground
                  }
                }
              }
            }
          }

          // ------------------------------------------------------------- Download Format Selector
          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Button {
              Layout.fillWidth: true
              text: "Video (MP4)"
              iconText: "󰕧"
              selected: root.selectedFormat === "video"
              onClicked: root.selectedFormat = "video"
            }

            Button {
              Layout.fillWidth: true
              text: "Audio Only (MP3)"
              iconText: "󰎆"
              selected: root.selectedFormat === "audio"
              onClicked: root.selectedFormat = "audio"
            }
          }

          // ------------------------------------------------------------- Offline Whisper AI & Subtitles
          Rectangle {
            id: whisperSection
            width: parent.width
            visible: urlInput.text.trim() !== ""
            height: visible ? (whisperCol.implicitHeight + Style.space(16)) : 0
            implicitHeight: whisperCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: Style.selectedFillFor(Color.foreground, Color.accent)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
            border.width: 1

            Column {
              id: whisperCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              // When Whisper IS installed: show transcription toggle & subtitle controls
              Column {
                width: parent.width
                visible: root.whisperAvailable
                spacing: Style.space(10)

                // Toggle row: Offline Whisper
                RowLayout {
                  width: parent.width

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Row {
                      spacing: Style.space(6)
                      Text {
                        text: "󰍬"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        color: Color.accent
                      }
                      Text {
                        text: "Offline Whisper Transcription"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                        color: Color.foreground
                      }
                    }

                    Text {
                      text: "100% offline speech-to-text without cloud or internet"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: Qt.darker(Color.foreground, 1.4)
                    }
                  }

                  ToggleSwitch {
                    checked: root.transcribeEnabled
                    onToggled: root.transcribeEnabled = !root.transcribeEnabled
                  }
                }

                // Subtitles & Model settings (revealed when transcribe is active)
                Column {
                  width: parent.width
                  visible: root.transcribeEnabled
                  spacing: Style.space(8)

                  RowLayout {
                    width: parent.width

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 0

                      Row {
                        spacing: Style.space(6)
                        Text {
                          text: "󰨖"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.body
                          color: Color.accent
                        }
                        Text {
                          text: "Generate Subtitles (.srt & .vtt)"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.body
                          color: Color.foreground
                        }
                      }

                      Text {
                        text: "Auto-loaded by media players (MPV, VLC)"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Qt.darker(Color.foreground, 1.4)
                      }
                    }

                    ToggleSwitch {
                      checked: root.subtitlesEnabled
                      onToggled: root.subtitlesEnabled = !root.subtitlesEnabled
                    }
                  }

                  // Whisper model selector pills
                  RowLayout {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      text: "Model:"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: Qt.darker(Color.foreground, 1.3)
                    }

                    Button {
                      Layout.fillWidth: true
                      text: "Tiny"
                      tooltipText: "Fastest transcription, low resource usage"
                      selected: root.whisperModel === "tiny"
                      onClicked: root.whisperModel = "tiny"
                    }

                    Button {
                      Layout.fillWidth: true
                      text: "Base"
                      tooltipText: "Recommended balance of accuracy and speed"
                      selected: root.whisperModel === "base"
                      onClicked: root.whisperModel = "base"
                    }

                    Button {
                      Layout.fillWidth: true
                      text: "Small"
                      tooltipText: "Higher accuracy for multi-speaker content"
                      selected: root.whisperModel === "small"
                      onClicked: root.whisperModel = "small"
                    }
                  }
                }
              }

              // When Whisper IS NOT installed: show status, info, and install button
              Column {
                width: parent.width
                visible: !root.whisperAvailable
                spacing: Style.space(8)

                RowLayout {
                  width: parent.width

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(2)

                    Row {
                      spacing: Style.space(6)
                      Text {
                        text: "󰍬"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        color: Color.urgent
                      }
                      Text {
                        text: "Offline Whisper AI"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                        color: Color.foreground
                      }
                    }

                    Text {
                      text: "Speech-to-text & subtitles require whisper-cpp"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: Qt.darker(Color.foreground, 1.4)
                    }
                  }

                  Rectangle {
                    implicitWidth: notInstTxt.implicitWidth + Style.space(8)
                    implicitHeight: Style.space(18)
                    radius: Style.cornerRadius
                    color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
                    border.color: Color.urgent
                    border.width: 1

                    Text {
                      id: notInstTxt
                      anchors.centerIn: parent
                      text: "Not Installed"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: Color.urgent
                    }
                  }
                }

                Button {
                  width: parent.width
                  text: "Install Whisper (whisper-cpp)"
                  iconText: "󰇚"
                  selected: true
                  accent: Color.accent
                  tooltipText: "Launch terminal to run: omarchy pkg add whisper-cpp"
                  onClicked: root.installWhisper()
                }

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: "Or run in terminal: omarchy pkg add whisper-cpp"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Qt.darker(Color.foreground, 1.4)
                }
              }
            }
          }

          // ------------------------------------------------------------- Download Action Button
          Button {
            width: parent.width
            text: "Start Download"
            iconText: "󰇚"
            fontSize: Style.font.subtitle
            selected: true
            accent: Color.accent
            onClicked: root.startDownload()
          }

          // ------------------------------------------------------------- Active Downloads
          Column {
            width: parent.width
            visible: activeJobsModel.count > 0
            height: visible ? implicitHeight : 0
            spacing: Style.space(8)

            Text {
              text: "Active Downloads (" + activeJobsModel.count + ")"
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              color: Color.accent
            }

            Repeater {
              model: activeJobsModel

              delegate: Rectangle {
                required property string jobId
                required property real jobProgress
                required property string jobSpeed
                required property string jobEta
                required property string jobTitle
                required property string jobStatus
                required property string jobFormat
                required property string jobPlatformIcon
                required property string jobPlatformColor

                width: mainColumn.width
                implicitHeight: activeCol.implicitHeight + Style.space(16)
                radius: Style.cornerRadius
                color: Style.selectedFillFor(Color.foreground, Color.accent)
                border.color: jobStatus === "completed" ? Qt.rgba(0.3, 0.8, 0.4, 0.5) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
                border.width: 1

                Column {
                  id: activeCol
                  anchors.fill: parent
                  anchors.margins: Style.space(10)
                  spacing: Style.space(6)

                  RowLayout {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      text: jobPlatformIcon || "\uf7ab"
                      font.family: jobPlatformIcon ? Style.font.family : "Font Awesome 7 Free Solid"
                      font.styleName: jobPlatformIcon ? "" : "Solid"
                      font.pixelSize: Style.font.subtitle
                      color: jobPlatformColor || Color.accent
                    }

                    Text {
                      Layout.fillWidth: true
                      text: jobTitle
                      elide: Text.ElideRight
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: Color.foreground
                    }

                    // Completed badge
                    Rectangle {
                      visible: jobStatus === "completed"
                      implicitWidth: compTxt.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(18)
                      radius: Style.cornerRadius
                      color: Qt.rgba(0.3, 0.8, 0.4, 0.2)
                      border.color: "#4EBF71"
                      border.width: 1
                      Text {
                        id: compTxt
                        anchors.centerIn: parent
                        text: "DONE"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: "#4EBF71"
                      }
                    }

                    // Queued badge
                    Rectangle {
                      visible: jobStatus === "queued"
                      implicitWidth: queueTxt.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(18)
                      radius: Style.cornerRadius
                      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                      border.color: Color.accent
                      border.width: 1
                      Text {
                        id: queueTxt
                        anchors.centerIn: parent
                        text: "QUEUED"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: Color.accent
                      }
                    }

                    // Format badge
                    Rectangle {
                      implicitWidth: fmtTxt.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(18)
                      radius: Style.cornerRadius
                      color: Style.hoverFillFor(Color.foreground, Color.accent)
                      Text {
                        id: fmtTxt
                        anchors.centerIn: parent
                        text: (jobFormat || "video").toUpperCase()
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Color.foreground
                      }
                    }

                    Button {
                      visible: jobStatus !== "completed"
                      iconText: "󰅖"
                      tooltipText: "Cancel Download"
                      onClicked: root.cancelJob(jobId)
                    }
                  }

                  // Galloping Pony tracking download progress
                  Item {
                    width: parent.width
                    height: Style.space(28)
                    visible: jobStatus === "downloading" || jobStatus === "processing" || jobStatus === "completed"

                    Item {
                      width: Style.space(38)
                      height: Style.space(28)
                      x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * (Math.max(0, Math.min(100, jobProgress)) / 100.0)))

                      Behavior on x {
                        NumberAnimation { duration: 100; easing.type: Easing.Linear }
                      }

                      AnimatedSprite {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("assets/caballoNormal.png")
                        frameWidth: 111
                        frameHeight: 81
                        frameCount: 7
                        frameX: 0
                        frameY: 0
                        frameRate: 14
                        interpolate: false
                        running: root.opened && (jobStatus === "downloading" || jobStatus === "processing")
                        loops: AnimatedSprite.Infinite
                      }
                    }
                  }

                  // Progress Bar
                  Rectangle {
                    width: parent.width
                    height: Style.space(6)
                    radius: Style.space(3)
                    color: Qt.darker(Color.popups.background, 1.2)

                    Rectangle {
                      height: parent.height
                      width: jobStatus === "queued" ? 0 : Math.max(0, Math.min(parent.width, parent.width * (Math.max(0, Math.min(100, jobProgress)) / 100.0)))
                      radius: Style.space(3)
                      color: jobStatus === "completed" ? "#4EBF71" : Color.accent

                      Behavior on width {
                        NumberAnimation { duration: 100; easing.type: Easing.Linear }
                      }
                    }
                  }

                  // Status line
                  RowLayout {
                    width: parent.width

                    Text {
                      Layout.fillWidth: true
                      text: jobStatus === "queued"
                        ? "󰄱 Queued (waiting for worker slot)..."
                        : (jobStatus === "completed"
                          ? "✓ Download Complete (100%)"
                          : (jobStatus === "transcribing"
                            ? "󰍬 Transcribing offline with Whisper..."
                            : (jobStatus === "processing"
                              ? ("󰑋 Processing media (" + jobProgress.toFixed(1) + "%)" + (jobSpeed !== "--" ? (" • " + jobSpeed) : ""))
                              : ((jobProgress > 0 ? (jobProgress.toFixed(1) + "%") : "0%") +
                                 (jobSpeed && jobSpeed !== "--" ? (" • " + jobSpeed) : "") +
                                 (jobEta && jobEta !== "--" ? (" • ETA " + jobEta) : "")))))
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: jobStatus === "completed" ? "#4EBF71" : (jobStatus === "queued" ? Color.accent : Qt.darker(Color.foreground, 1.3))
                    }
                  }
                }
              }
            }
          }

          // ------------------------------------------------------------- Recent Downloads (History)
          Column {
            width: parent.width
            visible: root.historyJobs.length > 0
            height: visible ? implicitHeight : 0
            spacing: Style.space(8)

            RowLayout {
              width: parent.width

              Text {
                Layout.fillWidth: true
                text: "Recent Downloads"
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                color: Color.accent
              }

              Button {
                iconText: "󰆴"
                tooltipText: "Clear History"
                onClicked: root.clearHistory()
              }
            }

            Repeater {
              model: root.historyJobs.slice(0, 6)

              delegate: Rectangle {
                required property var modelData
                width: mainColumn.width
                implicitHeight: historyCol.implicitHeight + Style.space(12)
                radius: Style.cornerRadius
                color: Style.selectedFillFor(Color.foreground, Color.accent)

                RowLayout {
                  id: historyCol
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text {
                    text: modelData.platform_icon || "\uf7ab"
                    font.family: modelData.platform_icon ? Style.font.family : "Font Awesome 7 Free Solid"
                    font.styleName: modelData.platform_icon ? "" : "Solid"
                    font.pixelSize: Style.font.subtitle
                    color: modelData.platform_color || Color.accent
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                      Layout.fillWidth: true
                      text: modelData.title || "Untitled"
                      elide: Text.ElideRight
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      color: Color.foreground
                    }

                    Row {
                      spacing: Style.space(6)

                      Text {
                        text: (modelData.format || "video").toUpperCase() +
                              (modelData.file_size ? (" • " + modelData.file_size) : "")
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: Qt.darker(Color.foreground, 1.4)
                      }

                      Rectangle {
                        visible: !!modelData.transcribing
                        implicitWidth: transcribingBadge.implicitWidth + Style.space(8)
                        implicitHeight: Style.space(16)
                        radius: Style.cornerRadius
                        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
                        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
                        border.width: 1

                        Row {
                          id: transcribingBadge
                          anchors.centerIn: parent
                          spacing: Style.space(4)

                          Text {
                            text: "󰍬"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            color: Color.accent
                          }

                          Text {
                            text: "Transcribing..."
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: Color.accent
                          }
                        }
                      }

                      Rectangle {
                        visible: !!modelData.has_subtitles && !modelData.transcribing
                        implicitWidth: subBadge.implicitWidth + Style.space(6)
                        implicitHeight: Style.space(16)
                        radius: Style.cornerRadius
                        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)

                        Text {
                          id: subBadge
                          anchors.centerIn: parent
                          text: "CC / Subs"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: Color.accent
                        }
                      }
                    }
                  }

                  Button {
                    iconText: "󰐊"
                    tooltipText: "Play / Open"
                    onClicked: root.openFile(modelData.output_file)
                  }

                  Button {
                    iconText: "󰉋"
                    tooltipText: "Open Folder"
                    onClicked: root.openFolder(modelData.output_file)
                  }
                }
              }
            }
          }

        }
      }
    }
  }
}
