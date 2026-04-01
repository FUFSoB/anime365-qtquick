import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "settingsScreen"
    padding: 12

    property var settings: ({})
    property var defaults: ({})
    property string savedTheme: "auto"

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
        function onToken_checked(result) {
            anime365TokenField.isValidToken = result
        }
        function onProxy_checked(result) {
            proxyField.isValidProxy = result
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledButton {
                text: "\u2190 Back"
                palette.button: "#EF5350"
                palette.buttonText: "#FFFFFF"
                onClicked: {
                    settingsBackend.apply_theme(savedTheme)
                    stackView.pop()
                }
            }

            Item { Layout.fillWidth: true }

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

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.parent.width
                spacing: 16

                // --- Appearance ---

                Label {
                    text: "Appearance"
                    font.pixelSize: 16
                    font.bold: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "Theme" }

                    CustomDropdown {
                        id: themeDropdown
                        Layout.fillWidth: true
                        model: ["auto", "light", "dark"]
                        onSelectionChanged: function(value) {
                            settingsBackend.apply_theme(value)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: palette.mid }

                // --- Network ---

                Label {
                    text: "Network"
                    font.pixelSize: 16
                    font.bold: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "SOCKS proxy (optional)" }

                    StyledTextField {
                        id: proxyField
                        Layout.fillWidth: true
                        placeholderText: "socks5://host:port"
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

                // --- Anime365 ---

                Rectangle { Layout.fillWidth: true; height: 1; color: palette.mid }

                Label {
                    text: "Anime365"
                    font.pixelSize: 16
                    font.bold: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        text: `Token (<a href='${settingsBackend.get("anime365_site")}/api/accessToken?app=pvb'>Get token</a>)`
                        textFormat: Text.RichText
                        onLinkActivated: (url) => Qt.openUrlExternally(url)
                        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    }

                    StyledTextField {
                        id: anime365TokenField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
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

                // --- Behavior ---

                Rectangle { Layout.fillWidth: true; height: 1; color: palette.mid }

                Label {
                    text: "Behavior"
                    font.pixelSize: 16
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "Check for updates" }
                    Item { Layout.fillWidth: true }
                    Switch {
                        id: checkUpdatesSwitch
                        checked: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "Auto-advance to next episode" }
                    Item { Layout.fillWidth: true }
                    Switch {
                        id: autoAdvanceSwitch
                        checked: false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "Discord Rich Presence" }
                    Item { Layout.fillWidth: true }
                    Switch {
                        id: discordRpcSwitch
                        checked: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "Download threads per file" }

                    CustomSpinBox {
                        id: downloadThreadsSpin
                        Layout.fillWidth: true
                        from: 1
                        to: 16
                        value: 4
                    }
                }

                // --- Programs (desktop only) ---

                Rectangle { Layout.fillWidth: true; height: 1; color: palette.mid }

                Label {
                    text: "Programs"
                    font.pixelSize: 16
                    font.bold: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "MPV" }

                    StyledTextField {
                        id: mpvPathField
                        Layout.fillWidth: true
                        placeholderText: defaults.mpv_path || "Path to binary"
                        property bool isValidPath: true
                        onTextChanged: {
                            if (text) {
                                isValidPath = false
                                validateMpvTimer.restart()
                            } else {
                                isValidPath = true
                            }
                        }
                        background: Rectangle {
                            color: palette.base
                            border.color: mpvPathField.isValidPath
                                ? "#4CAF50"
                                : (mpvPathField.text ? "#EF5350" : palette.mid)
                            border.width: mpvPathField.isValidPath || mpvPathField.text ? 2 : 1
                            radius: 4
                        }
                    }

                    StyledTextField {
                        id: mpvArgsField
                        Layout.fillWidth: true
                        placeholderText: "Extra command line arguments"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "VLC" }

                    StyledTextField {
                        id: vlcPathField
                        Layout.fillWidth: true
                        placeholderText: defaults.vlc_path || "Path to binary"
                        property bool isValidPath: true
                        onTextChanged: {
                            if (text) {
                                isValidPath = false
                                validateVlcTimer.restart()
                            } else {
                                isValidPath = true
                            }
                        }
                        background: Rectangle {
                            color: palette.base
                            border.color: vlcPathField.isValidPath
                                ? "#4CAF50"
                                : (vlcPathField.text ? "#EF5350" : palette.mid)
                            border.width: vlcPathField.isValidPath || vlcPathField.text ? 2 : 1
                            radius: 4
                        }
                    }

                    StyledTextField {
                        id: vlcArgsField
                        Layout.fillWidth: true
                        placeholderText: "Extra command line arguments"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: isWindows

                    Label { text: "MPC-HC" }

                    Label {
                        Layout.fillWidth: true
                        text: "⚠ Please use an updated fork for stable playback. Disable 'Options → Advanced → UseYDL' to prevent subtitle loading issues"
                        font.pixelSize: 12
                        color: "#FF9800"
                        wrapMode: Text.Wrap
                    }

                    StyledTextField {
                        id: mpcPathField
                        Layout.fillWidth: true
                        placeholderText: defaults.mpc_path || "Path to binary"
                        property bool isValidPath: true
                        onTextChanged: {
                            if (text) {
                                isValidPath = false
                                validateMpcTimer.restart()
                            } else {
                                isValidPath = true
                            }
                        }
                        background: Rectangle {
                            color: palette.base
                            border.color: mpcPathField.isValidPath
                                ? "#4CAF50"
                                : (mpcPathField.text ? "#EF5350" : palette.mid)
                            border.width: mpcPathField.isValidPath || mpcPathField.text ? 2 : 1
                            radius: 4
                        }
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "aria2c" }

                    StyledTextField {
                        id: aria2cPathField
                        Layout.fillWidth: true
                        placeholderText: defaults.aria2c_path || "Path to binary"
                        property bool isValidPath: true
                        onTextChanged: {
                            if (text) {
                                isValidPath = false
                                validateAria2cTimer.restart()
                            } else {
                                isValidPath = true
                            }
                        }
                        background: Rectangle {
                            color: palette.base
                            border.color: aria2cPathField.isValidPath
                                ? "#4CAF50"
                                : (aria2cPathField.text ? "#EF5350" : palette.mid)
                            border.width: aria2cPathField.isValidPath || aria2cPathField.text ? 2 : 1
                            radius: 4
                        }
                    }

                    StyledTextField {
                        id: aria2cArgsField
                        Layout.fillWidth: true
                        placeholderText: "Extra command line arguments"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "ffmpeg" }

                    StyledTextField {
                        id: ffmpegPathField
                        Layout.fillWidth: true
                        placeholderText: defaults.ffmpeg_path || "Path to binary"
                        property bool isValidPath: true
                        onTextChanged: {
                            if (text) {
                                isValidPath = false
                                validateFfmpegTimer.restart()
                            } else {
                                isValidPath = true
                            }
                        }
                        background: Rectangle {
                            color: palette.base
                            border.color: ffmpegPathField.isValidPath
                                ? "#4CAF50"
                                : (ffmpegPathField.text ? "#EF5350" : palette.mid)
                            border.width: ffmpegPathField.isValidPath || ffmpegPathField.text ? 2 : 1
                            radius: 4
                        }
                    }
                }

            }
        }
    }

    Timer {
        id: validateProxyTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            if (proxyField.text) {
                settingsBackend.is_valid_proxy(proxyField.text)
            } else {
                proxyField.isValidProxy = true
            }
        }
    }

    Timer {
        id: validateTokenTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            if (anime365TokenField.text) {
                settingsBackend.is_valid_token(anime365TokenField.text)
            } else {
                anime365TokenField.isValidToken = false
            }
        }
    }

    Timer {
        id: validateMpvTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (mpvPathField.text) {
                mpvPathField.isValidPath = settingsBackend.is_valid_binary(mpvPathField.text)
            }
        }
    }

    Timer {
        id: validateVlcTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (vlcPathField.text) {
                vlcPathField.isValidPath = settingsBackend.is_valid_binary(vlcPathField.text)
            }
        }
    }

    Timer {
        id: validateMpcTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (mpcPathField.text) {
                mpcPathField.isValidPath = settingsBackend.is_valid_binary(mpcPathField.text)
            }
        }
    }

    Timer {
        id: validateAria2cTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (aria2cPathField.text) {
                aria2cPathField.isValidPath = settingsBackend.is_valid_binary(aria2cPathField.text)
            }
        }
    }

    Timer {
        id: validateFfmpegTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (ffmpegPathField.text) {
                ffmpegPathField.isValidPath = settingsBackend.is_valid_binary(ffmpegPathField.text)
            }
        }
    }
}
