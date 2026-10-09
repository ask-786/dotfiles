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
                drawers: [quick, calendar, notifications, devices, media]
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

            DevicesPanel {
                id: devices
                bar: bar
                lift: Math.max(quick.stackHeight, calendar.stackHeight, notifications.stackHeight)
            }

            MediaPanel {
                id: media
                bar: bar
                lift: Math.max(quick.stackHeight, calendar.stackHeight, notifications.stackHeight) + devices.stackHeight
            }

            Popups {
                bar: bar
            }
        }
    }

    LockScreen {}

    // For keybinds:
    //   qs ipc call drawer toggle quick        (or calendar, notifications, devices, media)
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

    //   qs ipc call lock lock                    (hypridle's lock_cmd; there's no unlock)
    // Prints "locked" so the caller can tell it worked: a config that failed
    // to load has no lock target, and `qs ipc call` still exits 0 then.
    IpcHandler {
        target: "lock"

        function lock(): string {
            Lock.lock();
            return Lock.locked ? "locked" : "";
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

    //   qs ipc call prayer toggle                (or on, off)
    //   qs ipc call prayer toggleSound           (the adhan, or just the popup)
    //   qs ipc call prayer times                 (today's, one per line)
    //   qs ipc call prayer test                  (the next one's alert and adhan, now)
    IpcHandler {
        target: "prayer"

        function toggle(): void {
            Prayer.setEnabled(!Prayer.enabled);
        }

        function on(): void {
            Prayer.setEnabled(true);
        }

        function off(): void {
            Prayer.setEnabled(false);
        }

        function toggleSound(): void {
            Prayer.setPlayAdhan(!Prayer.playAdhan);
        }

        function times(): string {
            if (!Prayer.enabled)
                return "off";
            return Prayer.timesOn(Prayer.dayKey(new Date())).map(t => `${t.name}\t${Qt.formatTime(new Date(t.at), "hh:mm AP")}`).join("\n");
        }

        function test(): void {
            Prayer.test();
        }
    }
}
