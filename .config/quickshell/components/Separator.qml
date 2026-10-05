import QtQuick
import qs

Text {
    height: Theme.barHeight
    text: "|"
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.barFontSize
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
}
