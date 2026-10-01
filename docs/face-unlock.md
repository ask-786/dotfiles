# IR face unlock (Dell laptop)

Windows Hello-style face unlock for hyprlock and sudo, using the laptop's IR camera.
Built from [howdy-next](https://codeberg.org/nathawat/howdy-next) and
[linux-enable-ir-emitter](https://github.com/EmixamPP/linux-enable-ir-emitter) v7.

Keep a root shell open (`sudo -i` in another terminal) whenever you edit `/etc/pam.d/`.
A broken PAM file can lock you out.

## 1. Install

```sh
yay -S linux-enable-ir-emitter-git howdy-next
```

Use the **`-git`** emitter package (v7, a Rust rewrite). The 6.x and `-bin` packages
need OpenCV 4, but Arch ships OpenCV 5, so they fail to build or to run.
If `cargo` comes from rustup instead of pacman, build with `makepkg -d`.

## 2. Find the IR camera

```sh
for d in /sys/class/video4linux/video*; do echo "$d: $(cat $d/name)"; done
v4l2-ctl -d /dev/video2 --list-formats-ext   # the IR sensor shows 'GREY'
ls -l /dev/v4l/by-path/                      # use the stable path, not /dev/videoN
```

On this laptop: `/dev/v4l/by-path/pci-0000:00:14.0-usb-0:6:1.2-video-index0`.

## 3. Turn on the IR emitter

Linux doesn't switch the emitter on by itself. Teach it once, as your normal user:

```sh
linux-enable-ir-emitter configure
```

Point a phone camera at the sensor: phone cameras show IR as a purple/white flash.
Answer each question from that. The result is saved to
`~/.config/linux-enable-ir-emitter.toml`, which is tracked in this repo but only applies to this camera.
There's no service. PAM switches the emitter on during each login check (see step 6).

## 4. Configure howdy

```sh
sudo howdy download-models
sudo howdy set device_path /dev/v4l/by-path/<your-ir-device>
sudo howdy set timeout 8          # default 4s is too short
sudo howdy set dark_threshold 90  # the emitter strobes, so many frames are dark
```

## 5. Enroll your face

```sh
linux-enable-ir-emitter run
sudo howdy add -U "$USER" <label>
sudo howdy list
sudo howdy remove <id>
```

- Add several models: one at your desk, one in daylight, one with glasses.
- Matching uses cosine score; the threshold is `sface_threshold` (0.6942). Scores barely
  above it mean you should add another model. Don't lower the threshold.
- Remove models that never win.

## 6. PAM

Copies of the PAM files live in `etc/pam.d/`. stow skips them, so install by hand:

```sh
sudo install -m 644 etc/pam.d/hyprlock /etc/pam.d/hyprlock
sudo install -m 644 etc/pam.d/sudo     /etc/pam.d/sudo
```

**hyprlock:** the lock screen stays up until you press Enter.
- Empty field + Enter: the emitter switches on and howdy checks your face.
- Your password + Enter: unlocks right away.
- A wrong password falls through to the face check.

**sudo:** switch face unlock on or off with the fish function `faceid-sudo [on|off|status]`.
It comments the two face lines in `/etc/pam.d/sudo` in or out. hyprlock isn't affected.

These are copies: after editing `/etc/pam.d/`, copy the files back into the repo.

## Troubleshooting

- **Debug report:** `sudo howdy set end_report true`, then `sudo -k; sudo true`.
  The report shows frames searched, dark frames ignored, and the best score with its model.
  - `Face verification timed out` with no match usually means a bad model; add a new one.
  - Many dark frames ignored: raise `dark_threshold`.
- **`setPreferableTarget ... new graph engine` warnings:** harmless messages from OpenCV 5.
  You can't silence them, because howdy's helper runs as setuid and ignores your shell's environment.
- **Emitter not lighting:** run `linux-enable-ir-emitter run`, then check the
  output of `linux-enable-ir-emitter --log`. After a big upgrade, reboot and run `configure` again.
- **App data appearing in this repo:** stow folded `~/.config` into one symlink. Fix this by making
  `~/.config` a real directory before running `stow .` (or use `stow --no-folding`).
