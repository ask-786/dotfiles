import QtQuick
import qs
import qs.components
import qs.services

// Opens the quick settings menu (sliders, toggles, stats, power).
BarModule {
    required property string screenName

    text: "\u{F062E}"
    active: Panels.isOpen("quick", screenName)

    onClicked: Panels.toggle("quick", screenName, "")
}
