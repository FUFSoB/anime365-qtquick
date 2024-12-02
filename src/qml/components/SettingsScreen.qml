import QtQuick
import QtQuick.Controls
import Themes

Rectangle {
    color: Themes.currentTheme.background

    property var settings: {}
    property var defaults: {}

    Component.onCompleted: {
        settings = settingsBackend.get_settings()
        defaults = settingsBackend.get_defaults()
        mpvPathField.text = settings.mpv_path || defaults.mpv_path
        ugetPathField.text = settings.uget_path || defaults.uget_path
        anime365TokenField.text = settings.anime365_token || defaults.anime365_token
    }

    Connections {
        target: settingsBackend
        function onToken_checked(result) {
            anime365TokenField.isValidToken = result
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 12

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

            ScrollView {
                width: parent.width
                height: parent.height - 48
                clip: true

                Column {
                    width: parent.width
                    spacing: 16

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Path to MPV binary"
                            color: Themes.currentTheme.text
                            font.pixelSize: 14
                        }

                        TextField {
                            id: mpvPathField
                            width: parent.width
                            height: 36
                            placeholderText: "Enter MPV binary path"
                            color: Themes.currentTheme.text
                            placeholderTextColor: Themes.currentTheme.placeholderText
                            property bool isValidPath: true
                            onTextChanged: {
                                isValidPath = text ? settingsBackend.is_valid_binary(text) : false
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

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Path to uGet binary"
                            color: Themes.currentTheme.text
                            font.pixelSize: 14
                        }

                        TextField {
                            id: ugetPathField
                            width: parent.width
                            height: 36
                            placeholderText: "Enter uGet binary path"
                            color: Themes.currentTheme.text
                            placeholderTextColor: Themes.currentTheme.placeholderText
                            property bool isValidPath: true
                            onTextChanged: {
                                isValidPath = text ? settingsBackend.is_valid_binary(text) : false
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

                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: `Anime365 token (<a href='${settingsBackend.get("anime365_site")}/api/accessToken?app=pvb'>Get token</a>)`
                            color: Themes.currentTheme.text
                            font.pixelSize: 14
                            textFormat: Text.RichText
                            linkColor: Themes.currentTheme.link
                            onLinkActivated: (url) => Qt.openUrlExternally(url)
                        }

                        TextField {
                            id: anime365TokenField
                            width: parent.width
                            height: 36
                            color: Themes.currentTheme.text
                            font.pixelSize: 14
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
                                color: Themes.currentTheme.inputBackground
                                border.color: anime365TokenField.isValidToken
                                    ? Themes.currentTheme.success
                                    : (anime365TokenField.text ? Themes.currentTheme.fail : "transparent")
                                border.width: 2
                                radius: 4
                            }
                        }
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
