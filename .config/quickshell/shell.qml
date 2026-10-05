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
                bar: bar
            }

            CalendarPanel {
                bar: bar
            }
        }
    }

    // For keybinds:
    //   qs ipc call drawer toggle quick        (or calendar)
    //   qs ipc call drawer page quick wifi     (wifi | bluetooth | audio)
    IpcHandler {
        target: "drawer"

        function toggle(name: string): void {
            Panels.toggle(name, Hyprland.focusedMonitor?.name ?? "");
        }

        function page(name: string, target: string): void {
            Panels.toggle(name, Hyprland.focusedMonitor?.name ?? "", target);
        }

        function dbgvol(v: real): void {
            Audio.setVolume(v);
        }

        function close(): void {
            Panels.close();
        }
    }
}
