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

            NotificationPanel {
                id: notifications
                bar: bar
            }

            MediaPanel {
                bar: bar
                lift: Math.max(quick.stackHeight, calendar.stackHeight, notifications.stackHeight)
            }

            Popups {
                bar: bar
            }
        }
    }

    // For keybinds:
    //   qs ipc call drawer toggle quick        (or calendar, notifications, media)
    //   qs ipc call drawer page quick wifi     (wifi | bluetooth | audio)
    //   qs ipc call drawer page calendar reminders   (new reminder form)
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

    //   qs ipc call reminders add "tomorrow 9am, call dentist"
    //   qs ipc call reminders list               (id, when, text per line)
    //   qs ipc call reminders remove <id>
    IpcHandler {
        target: "reminders"

        function add(input: string): void {
            Reminders.addFromText(input);
        }

        function list(): string {
            return Reminders.items.map(r => `${r.id}\t${Reminders.describe(r)}\t${r.text}`).join("\n");
        }

        function remove(id: string): void {
            Reminders.remove(id);
        }
    }
}
