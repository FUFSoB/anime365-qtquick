import sys
from PySide6.QtWidgets import QApplication
from PySide6.QtQuick import QQuickView, QQuickItem
from PySide6.QtCore import QUrl

if __name__ == "__main__":
    app = QApplication(sys.argv)

    view = QQuickView()
    view.setSource(QUrl("style/Top.ui.qml"))
    view.show()

    root = view.rootObject()
    removeButton = root.findChild(QQuickItem, "searchButton")
    removeButton.setProperty("text", "Test text")

    sys.exit(app.exec())
