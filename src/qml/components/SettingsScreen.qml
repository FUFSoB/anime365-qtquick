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
        mpvPathField.text = settings.mpv_path || defaults.mpv_path
        vlcPathField.text = settings.vlc_path || defaults.vlc_path
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
                enabled: mpvPathField.text !== (settings.mpv_path ?? "")
                    || vlcPathField.text !== (settings.vlc_path ?? "")
                    || anime365TokenField.text !== (settings.anime365_token ?? "")
                    || proxyField.text !== (settings.proxy ?? "")
                    || themeDropdown.selectedValue !== (settings.theme || "auto")
                onClicked: {
                    settingsBackend.save_settings({
                        "mpv_path": mpvPathField.text,
                        "vlc_path": vlcPathField.text,
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

                // --- Player Paths (desktop only) ---

                Label {
                    text: "Player Paths"
                    font.pixelSize: 16
                    font.bold: true
                    visible: !isAndroid
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !isAndroid

                    Label { text: "Path to MPV binary" }

                    StyledTextField {
                        id: mpvPathField
                        Layout.fillWidth: true
                        placeholderText: "Enter MPV binary path"
                        property bool isValidPath: true
                        onTextChanged: {
                            isValidPath = text ? settingsBackend.is_valid_binary(text) : false
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
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !isAndroid

                    Label { text: "Path to VLC binary" }

                    StyledTextField {
                        id: vlcPathField
                        Layout.fillWidth: true
                        placeholderText: "Enter VLC binary path"
                        property bool isValidPath: true
                        onTextChanged: {
                            isValidPath = text ? settingsBackend.is_valid_binary(text) : false
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
                }

                // --- Network ---

                Rectangle { Layout.fillWidth: true; height: 1; color: palette.mid }

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
}
