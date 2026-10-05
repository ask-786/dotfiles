//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components
import qs.panels
import qs.services

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property var modelData

            Bar {
                id: bar
                screen: perScreen.modelData
            }

            ClickCatcher {
                bar: bar
            }

            QuickSettings {
                id: quick
                bar: bar
            }

            CalendarPanel {
                id: calendar
                bar: bar
            }

            MediaPanel {
                bar: bar
                lift: Math.max(quick.stackHeight, calendar.stackHeight)
            }
        }
    }

    // For keybinds:
    //   qs ipc call drawer toggle quick        (or calendar, media)
    //   qs ipc call drawer page quick wifi     (wifi | bluetooth | audio)
    IpcHandler {
        target: "drawer"

        function toggle(name: string): void {
            Panels.toggle(name, Hyprland.focusedMonitor?.name ?? "");
        }

        function page(name: string, target: string): void {
            Panels.toggle(name, Hyprland.focusedMonitor?.name ?? "", target);
        }

        function close(): void {
            Panels.close();
        }
    }
}
