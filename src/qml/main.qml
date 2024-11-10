import QtQuick
import QtQuick.Controls
import "components"

ApplicationWindow {
    id: mainWindow
    width: 1280
    height: 720
    visible: true
    title: "Anime365"

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: mainScreen
    }

    Component { id: mainScreen; MainScreen {} }
    Component { id: settingsScreen; SettingsScreen {} }
    Component { id: searchScreen; SearchScreen {} }
    Component { id: animeScreen; AnimeScreen {} }
}
