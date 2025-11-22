import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects 

// --- TU SLIDER PERSONALIZADO ---
Slider {
    id: iosSlider

    property real minValue: 0
    property real maxValue: 100
    property real step: 1
    property real sliderValue: 0

    property color accentColor: "#3b82f6"
    property color trackColor: "#e5e7eb"
    property color handleColor: "white"
    property color handleBorderColor: "#d1d5db"


    from: minValue
    to: maxValue
    stepSize: step
    value: sliderValue

    Layout.fillWidth: true
    
    // Padding para evitar que la sombra se corte
    leftPadding: 15 
    rightPadding: 15

    // 1. Fondo (Barra)
    background: Rectangle {
        x: iosSlider.leftPadding
        y: iosSlider.topPadding + iosSlider.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 4
        width: iosSlider.availableWidth
        height: implicitHeight
        radius: 2
        color: trackColor

        Rectangle {
            width: iosSlider.visualPosition * parent.width
            height: parent.height
            color: accentColor
            radius: 2
        }
    }

    // 2. Manija (Botón)
    handle: Rectangle {
        id: handleRect
        x: iosSlider.leftPadding + iosSlider.visualPosition * (iosSlider.availableWidth - width)
        y: iosSlider.topPadding + iosSlider.availableHeight / 2 - height / 2
        implicitWidth: 20
        implicitHeight: 20
        radius: 10
        color: accentColor
        
    }
}

