import QtQuick
import qs
import qs.components
import qs.services

// Totem split keyboard as "⌨ L/R%": a bolt marks a charging half, "–" a
// disconnected one. Orange below 20%, red and blinking below 10%. Only shown
// while at least one half is connected; hover for details.
BarModule {
    id: root

    readonly property var halves: [Totem.left, Totem.right].filter(h => h.present)
    readonly property int lowest: halves.length ? Math.min(...halves.map(h => h.capacity)) : 100

    function halfText(half) {
        if (!half.present)
            return "–";
        return `${half.capacity}${half.status === "Charging" ? "" : ""}`;
    }

    function describe(half, name) {
        if (!half.present)
            return `${name}: disconnected`;
        const suffix = half.status === "Charging" ? " (charging)" : half.status === "Full" ? " (full)" : "";
        return `${name}: ${half.capacity}%${suffix}`;
    }

    visible: Totem.present
    text: `${Icons.keyboard} ${halfText(Totem.left)}/${halfText(Totem.right)}%`
    textColor: lowest < 10 ? Theme.red : lowest < 20 ? Theme.orange : Theme.fg
    blink: lowest < 10
    tooltip: `Totem — ${describe(Totem.left, "Left")} | ${describe(Totem.right, "Right")}`
}
