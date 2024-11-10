import QtQuick
import QtQuick.Controls
import Themes

Rectangle {
    color: Themes.currentTheme.background

    property var settings: {}
    property var defaults: {}

    Component.onCompleted: {
        // Load settings when component is created
        settings = settingsBackend.get_settings()
        defaults = settingsBackend.get_defaults()
        mpvPathField.text = settings.mpv_path || defaults.mpv_path
        ugetPathField.text = settings.uget_path || defaults.uget_path
        anime365TokenField.text = settings.anime365_token || defaults.anime365_token
    }

    Connections {
        target: settingsBackend

        function onToken_checked(result) {
            if (result) {
                anime365TokenField.isValidToken = true
            } else {
                anime365TokenField.isValidToken = false
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 12

            // Header with back button
            Rectangle {
                width: parent.width
                height: 36
                color: "transparent"

                Row {
                    anchors.fill: parent
                    spacing: 12

                    CustomButton {
                        id: backButton
                        width: 100
                        height: 36
                        text: "← Back"
                        textColor: Themes.currentTheme.colorfulText
                        baseColor: Themes.currentTheme.cancelBase
                        hoverColor: Themes.currentTheme.cancelHover
                        pressColor: Themes.currentTheme.cancelPress
                        onClicked: stackView.pop()
                    }

                    Item {
                        width: parent.width - backButton.width - saveButton.width - parent.spacing * 2
                        height: parent.height

                        Text {
                            id: titleText
                            anchors.centerIn: parent
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: "Settings"
                            color: Themes.currentTheme.text
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    CustomButton {
                        id: saveButton
                        width: 100
                        height: 36
                        text: "Save"
                        textColor: Themes.currentTheme.colorfulText
                        baseColor: Themes.currentTheme.applyBase
                        hoverColor: Themes.currentTheme.applyHover
                        pressColor: Themes.currentTheme.applyPress

                        enabled: {
                            var settingsChanged = mpvPathField.text !== settings.mpv_path
                                || ugetPathField.text !== settings.uget_path
                                || anime365TokenField.text !== settings.anime365_token

                            return settingsChanged && mpvPathField.isValidPath && ugetPathField.isValidPath && anime365TokenField.isValidToken
                        }

                        onClicked: {
                            settingsBackend.save_settings({
                                "mpv_path": mpvPathField.text,
                                "uget_path": ugetPathField.text,
                                "anime365_token": anime365TokenField.text
                            })
                            stackView.pop()
                        }
                    }
                }
            }

            // MPV path setting
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "Path to MPV binary"
                    color: Themes.currentTheme.text
                    font.pixelSize: 14
                }

                Row {
                    width: parent.width
                    spacing: 12
                    height: 36

                    TextField {
                        id: mpvPathField
                        width: parent.width
                        height: parent.height
                        placeholderText: "Enter MPV binary path"
                        color: Themes.currentTheme.text
                        placeholderTextColor: Themes.currentTheme.placeholderText

                        property bool isValidPath: true

                        onTextChanged: {
                            if (mpvPathField.text) {
                                mpvPathField.isValidPath = settingsBackend.is_valid_binary(mpvPathField.text)
                            } else {
                                mpvPathField.isValidPath = false
                            }
                        }

                        background: Rectangle {
                            color: Themes.currentTheme.inputBackground
                            border.color: mpvPathField.isValidPath
                                ? Themes.currentTheme.success
                                : (mpvPathField.text ? Themes.currentTheme.fail : "transparent")
                            border.width: 2
                            radius: 4
                        }
                    }
                }
            }

            // UGet path setting
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "Path to UGet binary"
                    color: Themes.currentTheme.text
                    font.pixelSize: 14
                }

                Row {
                    width: parent.width
                    spacing: 12
                    height: 36

                    TextField {
                        id: ugetPathField
                        width: parent.width
                        height: parent.height
                        placeholderText: "Enter UGet binary path"
                        color: Themes.currentTheme.text
                        placeholderTextColor: Themes.currentTheme.placeholderText

                        property bool isValidPath: true

                        onTextChanged: {
                            if (ugetPathField.text) {
                                ugetPathField.isValidPath = settingsBackend.is_valid_binary(ugetPathField.text)
                            } else {
                                ugetPathField.isValidPath = false
                            }
                        }

                        background: Rectangle {
                            color: Themes.currentTheme.inputBackground
                            border.color: ugetPathField.isValidPath
                                ? Themes.currentTheme.success
                                : (ugetPathField.text ? Themes.currentTheme.fail : "transparent")
                            border.width: 2
                            radius: 4
                        }
                    }
                }
            }

            // Anime365 Token setting
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "Anime365 token (<a href='https://anime365.ru/api/accessToken?app=pvb'>Get token</a>)"
                    color: Themes.currentTheme.text
                    font.pixelSize: 14
                    textFormat: Text.RichText
                    linkColor: Themes.currentTheme.link
                    onLinkActivated: (url) => {
                        Qt.openUrlExternally(url)
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12
                    height: 36

                    TextField {
                        id: anime365TokenField
                        width: parent.width
                        height: parent.height
                        color: Themes.currentTheme.text
                        font.pixelSize: 14

                        property bool isValidToken: false

                        onTextChanged: {
                            if (anime365TokenField.text === settings.anime365_token) {
                                anime365TokenField.isValidToken = true
                            } else if (anime365TokenField.text !== "") {
                                validateTokenTimer.restart()
                            } else {
                                anime365TokenField.isValidToken = false
                            }
                        }

                        background: Rectangle {
                            color: Themes.currentTheme.inputBackground
                            border.color: anime365TokenField.isValidToken
                                ? Themes.currentTheme.success
                                : (anime365TokenField.text ? Themes.currentTheme.fail : "transparent")
                            border.width: 2
                            radius: 4
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
            }
        }
    }
}
