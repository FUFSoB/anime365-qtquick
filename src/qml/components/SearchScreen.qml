import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    objectName: "searchScreen"
    property string searchQuery: ""
    padding: 12

    function focusSearch() { searchField.forceActiveFocus() }

    property var allResults: []
    property string currentSort: "year"
    property bool filterHideHentai: false
    property var filterTypes: []
    property real filterMinScore: 0

    property bool hasActiveFilters: filterHideHentai || filterTypes.length > 0 || filterMinScore > 0

    Component.onCompleted: {
        busyIndicator.running = true
    }

    function applyFilterSort() {
        var results = allResults.slice()

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
            switch (currentSort) {
                case "year": return (b.year || 0) - (a.year || 0)
                case "score":
                    var sa = parseFloat(a.score) || 0
                    var sb = parseFloat(b.score) || 0
                    return sb - sa
                case "title": return (a.title || "").localeCompare(b.title || "")
                case "episodes": return (b.total_episodes || 0) - (a.total_episodes || 0)
                default: return 0
            }
        })

        searchResultsModel.clear()
        for (var i = 0; i < results.length; i++) {
            searchResultsModel.append(results[i])
        }
    }

    // Pill chip: used for sort (radio) and type/hentai (toggle)
    component Chip: Rectangle {
        id: chipRoot
        property string label: ""
        property bool active: false
        signal activated()

        implicitWidth: chipLabel.implicitWidth + 22
        implicitHeight: 28
        radius: 14

        property bool _hovered: false

        color: active ? palette.highlight
                      : _hovered ? palette.midlight
                                 : palette.button
        border.color: active ? "transparent" : (_hovered ? palette.highlight : palette.mid)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }

        Label {
            id: chipLabel
            anchors.centerIn: parent
            text: chipRoot.label
            color: chipRoot.active ? palette.highlightedText : palette.buttonText
            font.pixelSize: 12
            font.weight: chipRoot.active ? Font.Medium : Font.Normal
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
        implicitHeight: 20
        color: palette.mid
        opacity: 0.5
    }

    Connections {
        target: searchBackend

        function onSearch_completed(results) {
            allResults = results
            applyFilterSort()
            busyIndicator.running = false
        }

        function onSearch_error(errorMessage) {
            console.error("Search error:", errorMessage)
            busyIndicator.running = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── Row 1: search bar ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledButton {
                text: "\u2190 Back"
                onClicked: stackView.pop()
            }

            StyledTextField {
                id: searchField
                Layout.fillWidth: true
                text: searchQuery
                placeholderText: "Search anime\u2026"
                onAccepted: {
                    if (text.trim() !== "") {
                        searchBackend.perform_search(text.trim())
                        searchQuery = text
                        busyIndicator.running = true
                    }
                }
            }

            StyledButton {
                text: "Search"
                onClicked: {
                    if (searchField.text.trim() !== "") {
                        searchBackend.perform_search(searchField.text.trim())
                        searchQuery = searchField.text
                        busyIndicator.running = true
                    }
                }
            }
        }

        // ── Row 2: control strip (sort + type filter + score + hentai) ───
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: controlRow.implicitHeight + 14
            color: palette.alternateBase
            radius: 6

            RowLayout {
                id: controlRow
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10; rightMargin: 10
                }
                spacing: 5

                // — Sort ——————————————————————
                Label {
                    text: "Sort"
                    color: palette.windowText
                    opacity: 0.5
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
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

                VDivider { Layout.leftMargin: 2; Layout.rightMargin: 2 }

                // — Type ———————————————————————
                Label {
                    text: "Type"
                    color: palette.windowText
                    opacity: 0.5
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
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

                VDivider { Layout.leftMargin: 2; Layout.rightMargin: 2 }

                // — Score ——————————————————————
                Label {
                    text: "Score \u2265"
                    color: palette.windowText
                    opacity: 0.5
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
                }

                Label {
                    id: scoreValueLabel
                    text: filterMinScore > 0 ? filterMinScore.toFixed(1) : "Any"
                    color: filterMinScore > 0 ? palette.highlight : palette.windowText
                    font.pixelSize: 12
                    font.bold: filterMinScore > 0
                    Layout.minimumWidth: 28
                    horizontalAlignment: Text.AlignHCenter
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

                // — Hentai toggle ——————————————
                Chip {
                    label: filterHideHentai ? "Hide hentai" : "Hentai"
                    active: filterHideHentai
                    onActivated: {
                        filterHideHentai = !filterHideHentai
                        applyFilterSort()
                    }
                }

                Item { Layout.fillWidth: true }

                // — Reset (only when filters active) ——
                Chip {
                    visible: hasActiveFilters
                    label: "Reset filters"
                    active: false
                    onActivated: {
                        filterHideHentai = false
                        filterTypes = []
                        filterMinScore = 0
                        scoreSlider.value = 0
                        applyFilterSort()
                    }
                }

                BusyIndicator {
                    id: busyIndicator
                    running: false
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.leftMargin: 4
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
                text: {
                    if (busyIndicator.running) return ""
                    if (searchResultsModel.count === 0 && allResults.length === 0) return ""
                    if (hasActiveFilters && allResults.length > 0)
                        return searchResultsModel.count + " of " + allResults.length + " results"
                    if (searchResultsModel.count > 0)
                        return searchResultsModel.count + " result" + (searchResultsModel.count !== 1 ? "s" : "")
                    return ""
                }
                color: palette.windowText
                opacity: 0.45
                font.pixelSize: 11
            }

            Item { Layout.fillWidth: true }
        }
    }
}
