import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "settingsScreen"
    padding: 12

    property var settings: ({})
    property var defaults: ({})
    property string savedTheme: "auto"
    property int currentSection: 0

    function handleBack() {
        settingsBackend.apply_theme(savedTheme)
        stackView.pop()
    }

    Component.onCompleted: {
        settings = settingsBackend.get_settings()
        defaults = settingsBackend.get_defaults()
        savedTheme = settings.theme || "auto"
        mpvPathField.text = settings.mpv_path || ""
        vlcPathField.text = settings.vlc_path || ""
        mpcPathField.text = settings.mpc_path || ""
        aria2cPathField.text = settings.aria2c_path || ""
        ffmpegPathField.text = settings.ffmpeg_path || ""
        mpvArgsField.text = settings.mpv_args || ""
        vlcArgsField.text = settings.vlc_args || ""
        mpcArgsField.text = settings.mpc_args || ""
        mpcPortField.text = (settings.mpc_port || 13579).toString()
        aria2cArgsField.text = settings.aria2c_args || ""
        discordRpcSwitch.checked = settings.discord_rpc !== false
        checkUpdatesSwitch.checked = settings.check_updates !== false
        autoAdvanceSwitch.checked = settings.auto_advance === true
        downloadThreadsSpin.value = settings.download_threads || 4
        anime365TokenField.text = settings.anime365_token || defaults.anime365_token
        proxyField.text = settings.proxy || ""
        var themeIdx = ["auto", "light", "dark"].indexOf(savedTheme)
        themeDropdown.changeSelection(themeIdx < 0 ? 0 : themeIdx)
    }

    Connections {
        target: settingsBackend
        function onToken_checked(result) { anime365TokenField.isValidToken = result }
        function onProxy_checked(result) { proxyField.isValidProxy = result }
    }

    // ── Reusable row types ─────────────────────────────────────────────────

    // A row with label+description on left, a small control on right
    component ToggleRow: Rectangle {
        property alias label: rowLabel.text
        property alias description: rowDesc.text
        default property alias control: controlSlot.data

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + 20
        radius: 6
        color: palette.alternateBase

        RowLayout {
            id: rowLayout
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            anchors.leftMargin: 14; anchors.rightMargin: 14
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    id: rowLabel
                    font.pixelSize: 13
                    font.bold: true
                    color: palette.windowText
                }
                Label {
                    id: rowDesc
                    font.pixelSize: 11
                    opacity: 0.55
                    color: palette.windowText
                    visible: text !== ""
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Item {
                id: controlSlot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }
    }

    // A block with label at top, then an arbitrary input widget below
    component FieldBlock: Rectangle {
        property alias label: fieldLabel.text
        property alias labelExtra: fieldLabelExtra.data
        default property alias field: fieldSlot.data

        Layout.fillWidth: true
        implicitHeight: fieldBlockCol.implicitHeight + 24
        radius: 6
        color: palette.alternateBase

        ColumnLayout {
            id: fieldBlockCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label {
                    id: fieldLabel
                    font.pixelSize: 13
                    font.bold: true
                    color: palette.windowText
                }
                Item { id: fieldLabelExtra; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
                Item { Layout.fillWidth: true }
            }

            Item {
                id: fieldSlot
                Layout.fillWidth: true
                implicitHeight: childrenRect.height
            }
        }
    }

    // Thin section separator label
    component SectionHeading: Label {
        Layout.fillWidth: true
        font.pixelSize: 11
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.0
        font.bold: true
        opacity: 0.45
        topPadding: 8
    }

    // ── Layout ─────────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Label {
                text: "Settings"
                font.pixelSize: 18
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            StyledButton {
                id: saveButton
                text: "Save"
                palette.button: "#4CAF50"
                palette.buttonText: "#FFFFFF"
                enabled: (mpvPathField.text || defaults.mpv_path) !== (settings.mpv_path || defaults.mpv_path)
                    || (vlcPathField.text || defaults.vlc_path) !== (settings.vlc_path || defaults.vlc_path)
                    || (mpcPathField.text || defaults.mpc_path) !== (settings.mpc_path || defaults.mpc_path)
                    || (aria2cPathField.text || defaults.aria2c_path) !== (settings.aria2c_path || defaults.aria2c_path)
                    || (ffmpegPathField.text || defaults.ffmpeg_path) !== (settings.ffmpeg_path || defaults.ffmpeg_path)
                    || mpvArgsField.text !== (settings.mpv_args ?? "")
                    || vlcArgsField.text !== (settings.vlc_args ?? "")
                    || mpcArgsField.text !== (settings.mpc_args ?? "")
                    || parseInt(mpcPortField.text) !== (settings.mpc_port || 13579)
                    || aria2cArgsField.text !== (settings.aria2c_args ?? "")
                    || discordRpcSwitch.checked !== (settings.discord_rpc !== false)
                    || checkUpdatesSwitch.checked !== (settings.check_updates !== false)
                    || autoAdvanceSwitch.checked !== (settings.auto_advance === true)
                    || downloadThreadsSpin.value !== (settings.download_threads || 4)
                    || anime365TokenField.text !== (settings.anime365_token ?? "")
                    || proxyField.text !== (settings.proxy ?? "")
                    || themeDropdown.selectedValue !== (settings.theme || "auto")
                onClicked: {
                    settingsBackend.save_settings({
                        "mpv_path": mpvPathField.text,
                        "vlc_path": vlcPathField.text,
                        "mpc_path": mpcPathField.text,
                        "aria2c_path": aria2cPathField.text,
                        "ffmpeg_path": ffmpegPathField.text,
                        "mpv_args": mpvArgsField.text,
                        "vlc_args": vlcArgsField.text,
                        "mpc_args": mpcArgsField.text,
                        "mpc_port": parseInt(mpcPortField.text) || 13579,
                        "aria2c_args": aria2cArgsField.text,
                        "discord_rpc": discordRpcSwitch.checked,
                        "check_updates": checkUpdatesSwitch.checked,
                        "auto_advance": autoAdvanceSwitch.checked,
                        "download_threads": downloadThreadsSpin.value,
                        "anime365_token": anime365TokenField.text,
                        "proxy": proxyField.text,
                        "theme": themeDropdown.selectedValue,
                    })
                    stackView.pop()
                }
            }
        }

        // Body: sidebar + content
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ── Sidebar ───────────────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                radius: 6
                color: palette.alternateBase

                ColumnLayout {
                    anchors { fill: parent; margins: 6 }
                    spacing: 2

                    Repeater {
                        model: ["Appearance", "API \u0026 Network", "Players", "Downloaders", "Behavior"]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 5
                            color: currentSection === index ? palette.highlight
                                 : navMouseArea.containsMouse ? palette.midlight
                                 : "transparent"

                            Behavior on color { ColorAnimation { duration: 80 } }

                            Label {
                                anchors { left: parent.left; right: parent.right
                                          verticalCenter: parent.verticalCenter
                                          leftMargin: 12; rightMargin: 8 }
                                text: modelData
                                font.pixelSize: 13
                                font.bold: currentSection === index
                                color: currentSection === index ? palette.highlightedText : palette.windowText
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: navMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: currentSection = index
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ── Section content ───────────────────────────────────────────
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: currentSection

                // ── 0: Appearance ─────────────────────────────────────────
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.parent.width
                        spacing: 8

                        SectionHeading { text: "Appearance" }

                        FieldBlock {
                            label: "Theme"
                            CustomDropdown {
                                id: themeDropdown
                                width: parent.width
                                model: ["auto", "light", "dark"]
                                onSelectionChanged: function(value) { settingsBackend.apply_theme(value) }
                            }
                        }

                        Item { height: 1 }
                    }
                }

                // ── 1: API & Network ──────────────────────────────────────
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.parent.width
                        spacing: 8

                        SectionHeading { text: "API \u0026 Network" }

                        FieldBlock {
                            labelExtra: Label {
                                textFormat: Text.RichText
                                text: `(<a href='${settingsBackend.get("anime365_site")}/api/accessToken?app=pvb'>Get token</a>)`
                                font.pixelSize: 12
                                onLinkActivated: (url) => Qt.openUrlExternally(url)
                                HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            }
                            label: "Anime365 Token"
                            StyledTextField {
                                id: anime365TokenField
                                width: parent.width
                                echoMode: TextInput.Password
                                placeholderText: "Paste your API token here"
                                property bool isValidToken: false
                                onTextChanged: {
                                    if (text === settings.anime365_token) {
                                        isValidToken = true
                                    } else if (text !== "") {
                                        validateTokenTimer.restart()
                                    } else {
                                        isValidToken = false
                                    }
                                }
                                background: Rectangle {
                                    color: palette.base
                                    border.color: anime365TokenField.isValidToken
                                        ? "#4CAF50"
                                        : (anime365TokenField.text ? "#EF5350" : palette.mid)
                                    border.width: anime365TokenField.isValidToken || anime365TokenField.text ? 2 : 1
                                    radius: 4
                                }
                            }
                        }

                        FieldBlock {
                            label: "SOCKS Proxy"
                            StyledTextField {
                                id: proxyField
                                width: parent.width
                                placeholderText: "socks5://host:port  (optional)"
                                property bool isValidProxy: text === ""
                                onTextChanged: {
                                    if (text === "") {
                                        isValidProxy = true
                                    } else if (text === settings.proxy && settings.proxy !== "") {
                                        isValidProxy = true
                                    } else {
                                        isValidProxy = false
                                        validateProxyTimer.restart()
                                    }
                                }
                                background: Rectangle {
                                    color: palette.base
                                    border.color: proxyField.isValidProxy
                                        ? "#4CAF50"
                                        : (proxyField.text ? "#EF5350" : palette.mid)
                                    border.width: proxyField.isValidProxy || proxyField.text ? 2 : 1
                                    radius: 4
                                }
                            }
                        }

                        Item { height: 1 }
                    }
                }

                // ── 2: Players ────────────────────────────────────────────
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.parent.width
                        spacing: 8

                        SectionHeading { text: "Players" }

                        FieldBlock {
                            label: "MPV"
                            ColumnLayout {
                                width: parent.width
                                spacing: 6
                                ValidatedPathField {
                                    id: mpvPathField
                                    Layout.fillWidth: true
                                    placeholderText: defaults.mpv_path || "Path to binary"
                                }
                                StyledTextField {
                                    id: mpvArgsField
                                    Layout.fillWidth: true
                                    placeholderText: "Extra command line arguments"
                                }
                            }
                        }

                        FieldBlock {
                            label: "VLC"
                            ColumnLayout {
                                width: parent.width
                                spacing: 6
                                ValidatedPathField {
                                    id: vlcPathField
                                    Layout.fillWidth: true
                                    placeholderText: defaults.vlc_path || "Path to binary"
                                }
                                StyledTextField {
                                    id: vlcArgsField
                                    Layout.fillWidth: true
                                    placeholderText: "Extra command line arguments"
                                }
                            }
                        }

                        FieldBlock {
                            label: "MPC-HC"
                            visible: isWindows
                            ColumnLayout {
                                width: parent.width
                                spacing: 6
                                Label {
                                    Layout.fillWidth: true
                                    text: "\u26A0 Use an updated fork for stable playback. Disable Options \u2192 Advanced \u2192 UseYDL to prevent subtitle issues."
                                    font.pixelSize: 11
                                    color: "#FF9800"
                                    wrapMode: Text.Wrap
                                }
                                ValidatedPathField {
                                    id: mpcPathField
                                    Layout.fillWidth: true
                                    placeholderText: defaults.mpc_path || "Path to binary"
                                }
                                StyledTextField {
                                    id: mpcArgsField
                                    Layout.fillWidth: true
                                    placeholderText: "Extra command line arguments"
                                }
                                StyledTextField {
                                    id: mpcPortField
                                    Layout.fillWidth: true
                                    placeholderText: "Web interface port (default: 13579)"
                                    validator: IntValidator { bottom: 1; top: 65535 }
                                }
                            }
                        }

                        Item { height: 1 }
                    }
                }

                // ── 3: Downloaders ────────────────────────────────────────
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.parent.width
                        spacing: 8

                        SectionHeading { text: "Downloaders" }

                        FieldBlock {
                            label: "aria2c"
                            ColumnLayout {
                                width: parent.width
                                spacing: 6
                                ValidatedPathField {
                                    id: aria2cPathField
                                    Layout.fillWidth: true
                                    placeholderText: defaults.aria2c_path || "Path to binary"
                                }
                                StyledTextField {
                                    id: aria2cArgsField
                                    Layout.fillWidth: true
                                    placeholderText: "Extra command line arguments"
                                }
                            }
                        }

                        FieldBlock {
                            label: "ffmpeg"
                            ColumnLayout {
                                width: parent.width
                                spacing: 6
                                ValidatedPathField {
                                    id: ffmpegPathField
                                    Layout.fillWidth: true
                                    placeholderText: defaults.ffmpeg_path || "Path to binary"
                                }
                            }
                        }

                        ToggleRow {
                            label: "Download threads per file"
                            description: "Parallel connections aria2c uses per file"
                            CustomSpinBox {
                                id: downloadThreadsSpin
                                from: 1; to: 16; value: 4
                                implicitWidth: 120
                            }
                        }

                        Item { height: 1 }
                    }
                }

                // ── 4: Behavior ───────────────────────────────────────────
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.parent.width
                        spacing: 8

                        SectionHeading { text: "Behavior" }

                        ToggleRow {
                            label: "Check for updates"
                            description: "Notify when a new version is available"
                            Switch { id: checkUpdatesSwitch; checked: true }
                        }

                        ToggleRow {
                            label: "Auto-advance to next episode"
                            description: "Automatically load the next episode after playback ends"
                            Switch { id: autoAdvanceSwitch; checked: false }
                        }

                        ToggleRow {
                            label: "Discord Rich Presence"
                            description: "Show currently watched anime in Discord status"
                            Switch { id: discordRpcSwitch; checked: true }
                        }

                        Item { height: 1 }
                    }
                }
            }
        }
    }

    // ── Validation timers ──────────────────────────────────────────────────

    Timer {
        id: validateProxyTimer; interval: 1000; repeat: false
        onTriggered: { if (proxyField.text) settingsBackend.is_valid_proxy(proxyField.text); else proxyField.isValidProxy = true }
    }
    Timer {
        id: validateTokenTimer; interval: 1000; repeat: false
        onTriggered: { if (anime365TokenField.text) settingsBackend.is_valid_token(anime365TokenField.text); else anime365TokenField.isValidToken = false }
    }
}
