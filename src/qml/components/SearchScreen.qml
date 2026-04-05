import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "searchScreen"
    property string searchQuery: ""
    padding: 12

    function focusSearch() { searchField.forceActiveFocus() }
    function handleBack() { stackView.pop() }

    property var allResults: []
    property string searchError: ""
    property string currentSort: "year"
    property bool sortAscending: false
    property bool filterHideHentai: false
    property bool filterHideUnreleased: true
    property var filterTypes: []
    property real filterMinScore: 0

    property bool hasActiveFilters: filterHideHentai || !filterHideUnreleased || filterTypes.length > 0 || filterMinScore > 0
    property bool isBusy: false

    Component.onCompleted: {
        isBusy = true
    }

    function applyFilterSort() {
        var results = allResults.slice()

        if (filterHideUnreleased) {
            results = results.filter(r => r.year > 0 && r.total_episodes > 0)
        }
        if (filterHideHentai) {
            results = results.filter(r => !r.hentai)
        }
        if (filterTypes.length > 0) {
            results = results.filter(r => filterTypes.indexOf(r.type) !== -1)
        }
        if (filterMinScore > 0) {
            results = results.filter(r => {
                var s = parseFloat(r.score)
                return !isNaN(s) && s >= filterMinScore
            })
        }

        results.sort((a, b) => {
            var cmp
            switch (currentSort) {
                case "year":     cmp = (a.year || 0) - (b.year || 0); break
                case "score":
                    cmp = (parseFloat(a.score) || 0) - (parseFloat(b.score) || 0); break
                case "title":    cmp = (a.title || "").localeCompare(b.title || ""); break
                case "episodes": cmp = (a.total_episodes || 0) - (b.total_episodes || 0); break
                default: cmp = 0
            }
            return sortAscending ? cmp : -cmp
        })

        searchResultsModel.clear()
        for (var i = 0; i < results.length; i++) {
            var item = Object.assign({}, results[i])
            item.score = parseFloat(item.score) || 0
            searchResultsModel.append(item)
        }
    }

    // Pill chip: used for sort (radio) and type/hentai (toggle)
    component Chip: Rectangle {
        id: chipRoot
        property string label: ""
        property bool active: false
        signal activated()

        implicitWidth: chipLabel.implicitWidth + 22
        implicitHeight: 26
        radius: 13

        property bool _hovered: false

        color: active ? palette.highlight
                      : _hovered ? Qt.rgba(palette.highlight.r,
                                           palette.highlight.g,
                                           palette.highlight.b, 0.12)
                                 : "transparent"
        border.color: active  ? Qt.lighter(palette.highlight, 1.15)
                    : _hovered ? Qt.rgba(palette.highlight.r,
                                         palette.highlight.g,
                                         palette.highlight.b, 0.55)
                               : palette.mid
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 90 } }
        Behavior on border.color { ColorAnimation { duration: 90 } }

        Label {
            id: chipLabel
            anchors.centerIn: parent
            text: chipRoot.label
            color: chipRoot.active ? palette.highlightedText
                 : chipRoot._hovered ? palette.windowText
                 : palette.windowText
            font.pixelSize: 12
            font.weight: chipRoot.active ? Font.Medium : Font.Normal
            opacity: chipRoot.active ? 1.0 : (chipRoot._hovered ? 0.90 : 0.70)

            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: chipRoot._hovered = true
            onExited:  chipRoot._hovered = false
            onClicked: chipRoot.activated()
        }
    }

    // Thin vertical divider for the control strip
    component VDivider: Rectangle {
        implicitWidth: 1
        implicitHeight: 18
        color: palette.mid
        opacity: 0.4
    }

    Connections {
        target: searchBackend

        function onSearch_completed(results) {
            searchError = ""
            allResults = results
            applyFilterSort()
            isBusy = false
        }

        function onSearch_error(errorMessage) {
            searchError = errorMessage
            isBusy = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── Row 1: search bar ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledTextField {
                id: searchField
                Layout.fillWidth: true
                text: searchQuery
                placeholderText: "Search anime\u2026"
                onAccepted: {
                    if (text.trim() !== "") {
                        searchError = ""
                        searchBackend.perform_search(text.trim())
                        searchQuery = text
                        isBusy = true
                    }
                }
            }

            StyledButton {
                text: "Search"
                onClicked: {
                    if (searchField.text.trim() !== "") {
                        searchError = ""
                        searchBackend.perform_search(searchField.text.trim())
                        searchQuery = searchField.text
                        isBusy = true
                    }
                }
            }
        }

        // ── Row 2: control strip ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: controlColumn.implicitHeight + 14
            color: palette.alternateBase
            radius: 6
            border.color: palette.mid
            border.width: 1

            ColumnLayout {
                id: controlColumn
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10; rightMargin: 10
                }
                spacing: 6

                // — Row A: Sort + Type ————————————————————————————————
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Label {
                        text: "Sort"
                        color: palette.highlight
                        opacity: 0.75
                        font.pixelSize: 10
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.8
                        font.bold: true
                    }

                    Repeater {
                        model: [
                            {value: "year",     label: "Year"},
                            {value: "score",    label: "Score"},
                            {value: "title",    label: "Title"},
                            {value: "episodes", label: "Episodes"}
                        ]
                        Chip {
                            label: modelData.label
                            active: currentSort === modelData.value
                            onActivated: {
                                currentSort = modelData.value
                                applyFilterSort()
                            }
                        }
                    }

                    Chip {
                        label: sortAscending ? "\u2191" : "\u2193"
                        active: false
                        implicitWidth: 32
                        onActivated: {
                            sortAscending = !sortAscending
                            applyFilterSort()
                        }
                    }

                    VDivider { Layout.leftMargin: 2; Layout.rightMargin: 2 }

                    Label {
                        text: "Type"
                        color: palette.highlight
                        opacity: 0.75
                        font.pixelSize: 10
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.8
                        font.bold: true
                    }

                    Repeater {
                        model: [
                            {value: "tv",      label: "TV"},
                            {value: "ova",     label: "OVA"},
                            {value: "ona",     label: "ONA"},
                            {value: "movie",   label: "Movie"},
                            {value: "special", label: "Special"}
                        ]
                        Chip {
                            label: modelData.label
                            active: filterTypes.indexOf(modelData.value) !== -1
                            onActivated: {
                                var types = filterTypes.slice()
                                var idx = types.indexOf(modelData.value)
                                if (idx !== -1) types.splice(idx, 1)
                                else types.push(modelData.value)
                                filterTypes = types
                                applyFilterSort()
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // — Row B: Score + toggles + reset + busy ————————————
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Label {
                        text: "Score \u2265"
                        color: palette.highlight
                        opacity: 0.75
                        font.pixelSize: 10
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.8
                        font.bold: true
                    }

                    Rectangle {
                        radius: 4
                        implicitWidth: scoreValueLabel.implicitWidth + 12
                        implicitHeight: 20
                        color: filterMinScore > 0
                             ? Qt.rgba(palette.highlight.r, palette.highlight.g, palette.highlight.b, 0.15)
                             : Qt.rgba(0.5, 0.5, 0.5, 0.08)
                        border.color: filterMinScore > 0
                                    ? Qt.rgba(palette.highlight.r, palette.highlight.g, palette.highlight.b, 0.4)
                                    : palette.mid
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 90 } }

                        Label {
                            id: scoreValueLabel
                            anchors.centerIn: parent
                            text: filterMinScore > 0 ? filterMinScore.toFixed(1) : "Any"
                            color: filterMinScore > 0 ? palette.highlight : palette.windowText
                            font.pixelSize: 11
                            font.bold: filterMinScore > 0
                            opacity: filterMinScore > 0 ? 1.0 : 0.55
                        }
                    }

                    Slider {
                        id: scoreSlider
                        from: 0; to: 10
                        stepSize: 0.5
                        value: filterMinScore
                        Layout.preferredWidth: 96
                        onMoved: {
                            filterMinScore = value
                            applyFilterSort()
                        }
                    }

                    VDivider { Layout.leftMargin: 2; Layout.rightMargin: 2 }

                    Chip {
                        label: "Unreleased"
                        active: !filterHideUnreleased
                        onActivated: {
                            filterHideUnreleased = !filterHideUnreleased
                            applyFilterSort()
                        }
                    }

                    Chip {
                        label: filterHideHentai ? "Hide hentai" : "Hentai"
                        active: filterHideHentai
                        onActivated: {
                            filterHideHentai = !filterHideHentai
                            applyFilterSort()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Chip {
                        visible: hasActiveFilters
                        label: "Reset filters"
                        active: false
                        onActivated: {
                            filterHideHentai = false
                            filterHideUnreleased = true
                            filterTypes = []
                            filterMinScore = 0
                            scoreSlider.value = 0
                            applyFilterSort()
                        }
                    }

                }
            }
        }

        // ── Results list ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: palette.base
            radius: 4

            CustomListView {
                id: searchResultsList
                anchors.fill: parent
                model: ListModel {
                    id: searchResultsModel
                }
                onItemClicked: (item) => {
                    if (!databaseBackend.put(item.id, item)) {
                        var _item = item
                        item = Object.assign({}, databaseBackend.get(item.id))
                        item.episode_list = _item.episode_list
                        item.episode_ids = _item.episode_ids
                    }
                    stackView.push(animeScreen, { anime: item })
                }
                Component.onCompleted: {
                    searchResultsList.addContextMenuItem({
                        title: "Open Details",
                        action: "goto_details",
                        group: "main"
                    })
                }
                onContextMenuAction: function(action, item) {
                    switch (action) {
                        case "goto_details":
                            searchResultsList.onItemClicked(item)
                            break
                    }
                }
            }
        }

        // ── Status bar ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                visible: searchError !== ""
                text: "\u26A0 Search failed: " + searchError
                color: "#EF5350"
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Label {
                visible: searchError === ""
                text: {
                    if (isBusy) return ""
                    if (allResults.length === 0) return ""
                    return searchResultsModel.count + " of " + allResults.length + " results"
                }
                color: palette.windowText
                opacity: 0.45
                font.pixelSize: 11
            }

            Item { Layout.fillWidth: true }
        }
    }
}
