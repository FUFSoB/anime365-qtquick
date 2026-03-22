import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    padding: 12

    property var settings: ({})
    property var defaults: ({})

    Component.onCompleted: {
        settings = settingsBackend.get_settings()
        defaults = settingsBackend.get_defaults()
        mpvPathField.text = settings.mpv_path || defaults.mpv_path
        vlcPathField.text = settings.vlc_path || defaults.vlc_path
        ugetPathField.text = settings.uget_path || defaults.uget_path
        anime365TokenField.text = settings.anime365_token || defaults.anime365_token
        shikiClientIdField.text = settings.shikimori_client_id || ""
        shikiClientSecretField.text = settings.shikimori_client_secret || ""
        proxyField.text = settings.proxy || ""
        var themeIdx = ["auto", "light", "dark"].indexOf(settings.theme || "auto")
        themeDropdown.changeSelection(themeIdx < 0 ? 0 : themeIdx)
    }

    Connections {
        target: settingsBackend
        function onToken_checked(result) {
            anime365TokenField.isValidToken = result
        }
        function onShiki_token_checked(result) {
            shikiStatus.text = result ? "Connected" : "Invalid token"
            shikiStatus.color = result ? "#4CAF50" : "#EF5350"
        }
    }

    Connections {
        target: shikimoriBackend
        function onAuth_completed(success, message) {
            shikiStatus.text = message
            shikiStatus.color = success ? "#4CAF50" : "#EF5350"
            if (success) {
                shikiAuthCodeField.text = ""
                settings = settingsBackend.get_settings()
            }
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
                onClicked: stackView.pop()
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
                    || ugetPathField.text !== (settings.uget_path ?? "")
                    || anime365TokenField.text !== (settings.anime365_token ?? "")
                    || shikiClientIdField.text !== (settings.shikimori_client_id ?? "")
                    || shikiClientSecretField.text !== (settings.shikimori_client_secret ?? "")
                    || proxyField.text !== (settings.proxy ?? "")
                    || themeDropdown.selectedValue !== (settings.theme || "auto")
                onClicked: {
                    settingsBackend.save_settings({
                        "mpv_path": mpvPathField.text,
                        "vlc_path": vlcPathField.text,
                        "uget_path": ugetPathField.text,
                        "anime365_token": anime365TokenField.text,
                        "shikimori_client_id": shikiClientIdField.text,
                        "shikimori_client_secret": shikiClientSecretField.text,
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !isAndroid

                    Label { text: "Path to uGet binary" }

                    StyledTextField {
                        id: ugetPathField
                        Layout.fillWidth: true
                        placeholderText: "Enter uGet binary path"
                        property bool isValidPath: true
                        onTextChanged: {
                            isValidPath = text ? settingsBackend.is_valid_binary(text) : false
                        }
                        background: Rectangle {
                            color: palette.base
                            border.color: ugetPathField.isValidPath
                                ? "#4CAF50"
                                : (ugetPathField.text ? "#EF5350" : palette.mid)
                            border.width: ugetPathField.isValidPath || ugetPathField.text ? 2 : 1
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

                // --- Shikimori ---

                Rectangle { Layout.fillWidth: true; height: 1; color: palette.mid }

                Label {
                    text: "Shikimori"
                    font.pixelSize: 16
                    font.bold: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label { text: "OAuth Client ID" }
                    StyledTextField {
                        id: shikiClientIdField
                        Layout.fillWidth: true
                        placeholderText: "Register app at shikimori.one/oauth/applications"
                    }

                    Label { text: "OAuth Client Secret" }
                    StyledTextField {
                        id: shikiClientSecretField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    StyledButton {
                        text: "Authorize"
                        enabled: shikiClientIdField.text !== "" && shikiClientSecretField.text !== ""
                        onClicked: {
                            var url = settingsBackend.get("shikimori_site")
                                + "/oauth/authorize"
                                + "?client_id=" + shikiClientIdField.text
                                + "&redirect_uri=urn:ietf:wg:oauth:2.0:oob"
                                + "&response_type=code"
                                + "&scope=user_rates"
                            Qt.openUrlExternally(url)
                        }
                    }

                    StyledTextField {
                        id: shikiAuthCodeField
                        Layout.fillWidth: true
                        placeholderText: "Paste authorization code here"
                    }

                    StyledButton {
                        text: "Submit Code"
                        enabled: shikiAuthCodeField.text !== "" && shikiClientIdField.text !== "" && shikiClientSecretField.text !== ""
                        onClicked: {
                            shikimoriBackend.authorize(
                                shikiAuthCodeField.text,
                                shikiClientIdField.text,
                                shikiClientSecretField.text
                            )
                        }
                    }

                    Label {
                        id: shikiStatus
                        text: settings.shikimori_access_token ? "Connected" : "Not connected"
                        color: settings.shikimori_access_token ? "#4CAF50" : palette.placeholderText
                    }
                }
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
