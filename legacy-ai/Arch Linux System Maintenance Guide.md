# Arch Linux System Maintenance Guide

Keep Arch stable, update safely, and recover without panic.

_Last updated: October 2026_

**Contents**

1. [Golden rules](#1-golden-rules)
2. [What can actually break during an Arch update](#2-what-can-actually-break-during-an-arch-update)
3. [The safety stack](#3-the-safety-stack)
4. [Setup, step by step](#4-setup-step-by-step)
5. [All-in-one setup command](#5-all-in-one-setup-command)
6. [Update routine](#6-update-routine)
7. [Recovery playbook (by symptom)](#7-recovery-playbook-by-symptom)
8. [Health checks and useful commands](#8-health-checks-and-useful-commands)
9. [Don'ts](#9-donts)
10. [Quick reference card](#10-quick-reference-card)

---

## 1. Golden rules

- Update about **once a week**. Not daily, not every few months.
- Always update the **whole** system: `pacman -Syu` (or yay / Arch-Update).
- Read the **Arch news** before updating (Arch-Update shows them for you).
- **Never interrupt** a running update. Never hard-reset during an update.
- After kernel or GPU driver updates: **reboot right away**.
- Only update when you have time to fix things (not right before you need the PC).
- Prefer **official packages** over AUR packages.
- Keep a **snapshot before every update**, an **emergency kernel**, and a **USB stick**.
- Keep a copy of your configs and personal files **off this drive**.

---

## 2. What can actually break during an Arch update

Arch is a rolling release: every program updates as soon as upstream releases a new
version. That brings new software fast, but also more change.

### 2.1 Arch-specific risks

| # | Risk | What happens | Protection |
|---|---|---|---|
| 1 | **Changes that need manual intervention** | Packages get split, renamed or change format. pacman stops with an error or the system behaves oddly until you do a manual step. Always announced on [archlinux.org/news](https://archlinux.org/news). | Arch-Update shows the news, arch-manwarn blocks the update |
| 2 | **Drivers dropping old hardware** | Example (Dec 2025): NVIDIA 590 dropped Pascal (GTX 10xx) and older. Users who ignored the news booted into a black screen. | Same as above |
| 3 | **Partial upgrades** | `pacman -Sy <package>` refreshes the lists but updates only one package. Its libraries no longer match the rest of the system. | Always `-Syu`, never `-Sy` alone |
| 4 | **Kernel / initramfs not rebuilt** | An aborted update leaves the new kernel without a matching boot image: kernel panic or emergency mode. | Never interrupt updates; emergency kernel ([4.7](#47-emergency-kernel-boot-without-a-usb-stick)) |
| 5 | **GPU driver / kernel mismatch** (mostly NVIDIA) | Black screen instead of the login screen. TTY still works. | Reboot right after such updates; snapshot; emergency kernel |
| 6 | **Fast-moving software changes its config format** | Example: Hyprland switched from `hyprland.conf` to Lua (`hyprland.lua`). The session fails to start or shows a config error. | Read release notes, keep a second desktop (e.g. KDE Plasma) as fallback, back up configs |
| 7 | **AUR packages** | After library updates some AUR apps must be rebuilt (`yay -S <pkg>`). **Malware:** in June 2026 more than 1,500 AUR packages were compromised. Attackers took over orphaned packages and added an info-stealer (browser cookies, Discord sessions, SSH keys, passwords). A snapshot repairs the system, but **stolen data stays stolen**. | Official repos first; check AUR pages (votes, maintainer, comments); be suspicious of maintainer changes; install few AUR packages |
| 8 | **Testing repositories enabled by accident** | `[core-testing]`, `[extra-testing]`, `[multilib-testing]` contain untested packages. `[multilib-testing]` sits right above `[multilib]` in `/etc/pacman.conf`, so it gets enabled by mistake. Result: mismatched versions (e.g. `lib32-nvidia-utils` vs `nvidia-utils`). | Check enabled repos ([section 8](#8-health-checks-and-useful-commands)) |
| 9 | **Ignored `.pacnew` files** | New default configs are saved as `*.pacnew` when you changed the old one. Ignored for long, configs go stale. | Arch-Update offers to merge them (`pacdiff`) |
| 10 | **Outdated keyring after a long break** | "invalid or corrupted package (PGP signature)" | `sudo pacman -Sy archlinux-keyring && sudo pacman -Su` |

### 2.2 Risks that are NOT Arch-specific (every OS has them)

- **Power loss or hard reset during an update:** half-installed packages.
- **Power loss or hard reset in general:** files can end up empty (0 bytes), especially
  right after updates. Check with `sudo pacman -Qkk` ([section 8](#8-health-checks-and-useful-commands)).
- **SSD/HDD failure:** everything on that drive is gone, including snapshots stored on the same drive.
- **Interrupted BIOS/firmware update:** the only realistic way to "brick" a PC.
- **Accidentally deleting your own files.**

> An Arch update **cannot damage hardware**. `linux-firmware` is only loaded into devices
> at runtime, it is not flashed permanently. BIOS/SSD firmware only changes if *you* start
> a firmware update on purpose.

### 2.3 How likely is it?

Between Oct 2024 and Oct 2026 the Arch news had about **10 "manual intervention" posts**.
Most were about server software (mail servers, DHCP, monitoring). Only a few affected
typical desktops.

Realistic outlook with the setup in this guide:

- "Some app/config acts up after an update": a few times per year.
- "System does not boot": rare, and fixable in minutes.
- "Hardware destroyed by an update": does not happen.

---

## 3. The safety stack

| Tool | What it does |
|---|---|
| **Arch-Update** | Update notifier + guided updater with tray icon. Shows Arch news before updating, then cleans up: orphans, old package cache, `.pacnew` files, services to restart, pending reboot. |
| **arch-manwarn** | pacman hook. Blocks an update if an unread Arch news post says "manual intervention". |
| **Timeshift (RSYNC)** | System snapshots of `/` (your home folder is excluded by default). |
| **timeshift-autosnap** | pacman hook. Creates a Timeshift snapshot before every update automatically. |
| **linux-lts** | Second "emergency" kernel. If the main kernel breaks, boot this one from the boot menu. |
| **Arch USB stick** | Last resort if nothing boots at all. |
| **Git / external copy** | Backup of configs and personal files off this drive. |
| **smartmontools** | Check SSD/HDD health. |
| **Octopi** (optional) | GUI to browse / remove packages. Not for updates. |

**How they work together during an update:**
Arch-Update shows news → you confirm → arch-manwarn checks the news → timeshift-autosnap
takes a snapshot → `pacman -Syu` runs → AUR + Flatpak → Arch-Update cleans up and offers a reboot.

---

## 4. Setup, step by step

### 4.1 Base tools + yay (AUR helper)

```bash
sudo pacman -Syu --needed base-devel git pacman-contrib
```

Install yay only if it is missing (check with `command -v yay`):

```bash
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin && makepkg -si
cd .. && rm -rf yay-bin
```

### 4.2 Timeshift

```bash
yay -S --needed timeshift
```

First-time setup (once): open the Timeshift app.

- **Snapshot type:** RSYNC (or BTRFS if your root is btrfs)
- **Location:** ideally a *different physical drive* than your system. A different
  partition on the same drive protects against broken updates, but not against drive failure.
- Keep enough free space on the target.

Check where snapshots go:

```bash
sudo timeshift --list    # see "Device"
lsblk -f                 # see which drive/partition that is
```

### 4.3 timeshift-autosnap (snapshot before every update)

```bash
yay -S --needed timeshift-autosnap
```

Config: `/etc/timeshift-autosnap.conf`

- `maxSnapshots=3`: how many auto snapshots to keep
- `updateGrub=false`: only needed for btrfs + grub-btrfs

One snapshot per update instead of one per AUR package:

```bash
yay --save --batchinstall
```

(paru: enable `BatchInstall` in `/etc/paru.conf`)

Test:

```bash
sudo timeshift-autosnap
sudo timeshift --list
```

Skip once (emergency only):

```bash
sudo SKIP_AUTOSNAP= pacman -Syu
```

### 4.4 Arch-Update

```bash
yay -S --needed arch-update
sudo pacman -S --needed libnotify xdg-terminal-exec
arch-update --check --enable    # check at boot, then every 6 hours
```

**Tray icon**

KDE / GNOME / most desktops:

```bash
arch-update --tray --enable
```

Hyprland (Lua config, `hyprland.lua`), inside your start block:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("sleep 3 && arch-update --tray")
end)
```

Hyprland (old `hyprland.conf`):

```
exec-once = sleep 3 && arch-update --tray
```

Waybar: the `"tray"` module must be in your bar.

**Use a specific terminal** (example: kitty):

```bash
echo "kitty.desktop" > ~/.config/xdg-terminals.list
```

**Check less often** (e.g. once a day):

```bash
systemctl --user edit --full arch-update.timer
```

Change `OnUnitActiveSec=6h` to `OnUnitActiveSec=1d`.

### 4.5 arch-manwarn

```bash
yay -S --needed arch-manwarn
arch-manwarn           # prints a confirmation = installed
arch-manwarn status    # warnings it has seen
```

Config: `/etc/arch-manwarn/config.toml` (defaults are fine).
When it blocks an update: read the news, do what it says, run the update again.
The warning is marked as read after it was shown once.

### 4.6 makepkg tweaks (faster AUR builds, no -debug packages)

```bash
sudo sed -i -E '/^OPTIONS=/s/([( ])debug([ )])/\1!debug\2/' /etc/makepkg.conf
sudo sed -i -E 's/^#?MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
grep -E '^(OPTIONS|MAKEFLAGS)' /etc/makepkg.conf
```

### 4.7 Emergency kernel (boot without a USB stick)

Install the LTS kernel:

```bash
sudo pacman -Syu linux-lts
```

GPU driver for it:

| GPU setup | Command |
|---|---|
| NVIDIA with `nvidia-open` | `sudo pacman -S --needed nvidia-open-lts` |
| NVIDIA with `nvidia-open-dkms` | `sudo pacman -S --needed linux-lts-headers` |
| AMD / Intel | nothing extra needed |

Check free space on the boot partition first: `df -h /boot`

**Add it to the boot menu**

**a) systemd-boot** (folder `/boot/loader` exists)

If your main kernel is a UKI (`.efi` in `/boot/EFI/Linux`), the LTS kernel is built the
classic way and needs its own entry. Run this while booted with your normal kernel
(the `options` line copies your current boot options):

```bash
sudo tee /boot/loader/entries/arch-lts.conf > /dev/null << EOF
title   Arch Linux (LTS emergency kernel)
linux   /vmlinuz-linux-lts
initrd  /initramfs-linux-lts.img
options $(sed -E 's/(^| )(initrd|BOOT_IMAGE)=[^ ]*//g' /proc/cmdline)
EOF
```

Paths assume the boot partition is mounted at `/boot`. The microcode is included if
`microcode` is in the `HOOKS` line of `/etc/mkinitcpio.conf`; otherwise add
`initrd /intel-ucode.img` (or `/amd-ucode.img`) above the initramfs line.

Show the menu for 3 seconds at every boot (or keep it hidden and press **SPACE** right
after the BIOS logo):

```bash
sudo bootctl set-timeout 3
```

Check (your normal kernel must still be marked **(default)**):

```bash
sudo bootctl list --no-pager
```

**b) GRUB** (folder `/boot/grub` exists)

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

GRUB finds the LTS kernel by itself; it appears under "Advanced options".

**Test it once:** reboot, pick the LTS entry, then:

```bash
uname -r    # should end with "-lts"
```

### 4.8 Root password (needed for "emergency mode")

If the system drops into emergency mode, systemd asks for the root password.
With a locked root account you cannot use it.

```bash
sudo passwd -S root    # second column: L = locked, P = has password
sudo passwd root       # set one if it is locked
```

### 4.9 Disk health

```bash
sudo pacman -S --needed smartmontools gsmartcontrol
sudo smartctl -a /dev/nvme0n1    # or /dev/sda etc., see lsblk
```

| Value | Good |
|---|---|
| SMART overall-health | PASSED |
| Critical Warning | 0x00 |
| Available Spare | close to 100% |
| Percentage Used | wear level (100% = rated lifetime) |
| **Media and Data Integrity Errors** | **0** (the important one) |

"Error Information Log Entries" with "Invalid Field in Command" are harmless
(unsupported commands, not data errors).

### 4.10 Optional: package GUI

```bash
yay -S --needed octopi
```

In Octopi: Tools → Options → AUR → choose yay. Use it to browse/remove packages.
Keep doing updates with Arch-Update. Do not autostart the Octopi Notifier
(Arch-Update already notifies you).

### 4.11 Backups off this drive

**Configs:** keep them in a private Git repository (e.g. on GitHub) and push after changes.
Never commit passwords, tokens or SSH keys.

**Package lists** (to reinstall everything on a new system):

```bash
pacman -Qqen > pkglist.txt    # official, explicitly installed
pacman -Qqem > aurlist.txt    # AUR
```

Restore:

```bash
sudo pacman -S --needed - < pkglist.txt
yay -S --needed - < aurlist.txt
```

**Personal files:** external drive or cloud storage (Timeshift does NOT back up your
home folder by default).

### 4.12 Arch USB stick (last resort)

Download the ISO from [archlinux.org/download](https://archlinux.org/download) and write it
to a USB stick. With `dd` (**double-check the device with `lsblk`, dd overwrites it**):

```bash
sudo dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Put the stick in a drawer.

---

## 5. All-in-one setup command

Does sections 4.1 – 4.7 in one go: base tools, yay, Timeshift, autosnap, Arch-Update,
arch-manwarn, makepkg tweaks, LTS emergency kernel incl. NVIDIA module and boot entry.
Safe to run again (it skips what exists) and it stops at the first error.

**Not included** (do these manually):

- Timeshift first-time setup ([4.2](#42-timeshift))
- Tray icon for Hyprland and similar ([4.4](#44-arch-update))
- Root password check ([4.8](#48-root-password-needed-for-emergency-mode))
- Test boot of the LTS kernel ([4.7](#47-emergency-kernel-boot-without-a-usb-stick))

Run it while booted with your normal kernel:

```bash
sudo pacman -Syu --needed base-devel git pacman-contrib libnotify xdg-terminal-exec smartmontools linux-lts && \
{ command -v yay >/dev/null || { git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && (cd /tmp/yay-bin && makepkg -si) && rm -rf /tmp/yay-bin; }; } && \
yay -S --needed timeshift timeshift-autosnap arch-update arch-manwarn && \
{ if pacman -Qq nvidia-open >/dev/null 2>&1; then sudo pacman -S --needed nvidia-open-lts; elif pacman -Qq nvidia-open-dkms >/dev/null 2>&1; then sudo pacman -S --needed linux-lts-headers; fi; } && \
yay --save --batchinstall && \
sudo sed -i -E '/^OPTIONS=/s/([( ])debug([ )])/\1!debug\2/' /etc/makepkg.conf && \
sudo sed -i -E 's/^#?MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf && \
arch-update --check --enable && \
arch-update --tray --enable && \
{ if sudo test -d /boot/loader/entries && sudo test -f /boot/initramfs-linux-lts.img && ! sudo test -f /boot/loader/entries/arch-lts.conf; then printf 'title   Arch Linux (LTS emergency kernel)\nlinux   /vmlinuz-linux-lts\ninitrd  /initramfs-linux-lts.img\noptions %s\n' "$(sed -E 's/(^| )(initrd|BOOT_IMAGE)=[^ ]*//g' /proc/cmdline)" | sudo tee /boot/loader/entries/arch-lts.conf >/dev/null && sudo bootctl set-timeout 3; elif sudo test -d /boot/grub; then sudo grub-mkconfig -o /boot/grub/grub.cfg; fi; } && \
arch-manwarn && \
echo "Done. Now: Timeshift first-time setup, tray icon, test boot of the LTS kernel."
```

---

## 6. Update routine

### 6.1 Weekly update

1. Close games and big programs.
2. Click the Arch-Update tray icon (or run `arch-update`).
3. Read any news it shows. If something applies to you, do it first.
4. Confirm. arch-manwarn checks, timeshift-autosnap takes a snapshot, then the update runs
   (repo packages, AUR, Flatpak).
5. yay asks "Packages to exclude": just press **ENTER** (excluding packages can cause
   partial upgrades).
6. Afterwards Arch-Update offers:
   - **Orphan packages:** review the list, usually fine to remove.
   - **Old cached packages:** fine to remove.
   - **.pacnew files:** merge or review them.
   - **Reboot:** say yes if the kernel or GPU driver was updated.
7. After the reboot, quick check:

```bash
journalctl -b -p 3     # new errors?
systemctl --failed     # failed services?
```

Without Arch-Update, the manual equivalent is:

```bash
yay              # = pacman -Syu + AUR updates
flatpak update   # if you use Flatpak
```

### 6.2 Monthly

| Check | Command |
|---|---|
| Disk health | `sudo smartctl -a /dev/nvme0n1` |
| Free space | `df -h` |
| Snapshots exist | `sudo timeshift --list` |
| Repos are sane | `grep -n '^\[' /etc/pacman.conf` |
| Config backup | push to Git |

### 6.3 Installing new software

Update first, then install:

```bash
sudo pacman -Syu <package>    # official repo (-Syu is NOT a partial upgrade)
yay -S <package>              # AUR, check its AUR page first
pacman -Si <package>          # does it exist officially?
```

---

## 7. Recovery playbook (by symptom)

Where it stops tells you what broke. The boot chain:

**BIOS → boot loader → kernel + initramfs → systemd → login → desktop**

| What you see | What broke | Fix |
|---|---|---|
| Login works, desktop crashes / config error | Desktop config | [7.4](#74-desktop-session-wont-start) |
| Boot works, black screen instead of login | GPU driver | [7.3](#73-roll-back-to-the-snapshot-universal-fix), [7.6](#76-downgrade-a-single-package-from-the-cache) |
| Kernel panic / emergency mode / hangs | Kernel / initramfs | [7.5](#75-main-kernel-broken-kernel-panic-emergency-mode) |
| No boot menu / "no bootable device" | Boot loader | [7.7](#77-nothing-boots-at-all-usb-stick--chroot) |

### 7.1 Getting to a TTY (text console)

Works even when graphics are broken.

- `Ctrl+Alt+F3` (try F2–F6 if one stays black), log in with your user name and password
- `Ctrl+Alt+F1` / `F2`: back to the graphical session

See what's wrong:

```bash
journalctl -b -p 3       # errors of this boot
journalctl -b -1 -p 3    # errors of the previous boot
systemctl --failed
```

### 7.2 Update was aborted / half-installed

```bash
sudo rm /var/lib/pacman/db.lck    # ONLY if no pacman is running
sudo pacman -Syu                  # let it finish
sudo mkinitcpio -P                # rebuild all boot images
reboot
```

### 7.3 Roll back to the snapshot (universal fix)

```bash
sudo timeshift --list
sudo timeshift --restore
```

Pick the snapshot `{timeshift-autosnap} {created before upgrade}` from right before the
bad update and confirm. Timeshift reboots afterwards. Changes made after that snapshot are
lost (personal files in your home folder are not touched by default).

### 7.4 Desktop session won't start

- On the login screen choose another session (e.g. KDE Plasma) and fix things from there.
- Or in a TTY: fix the config with `nano`, or restore it from your Git backup.
- Or roll back the snapshot ([7.3](#73-roll-back-to-the-snapshot-universal-fix)).

### 7.5 Main kernel broken (kernel panic, emergency mode)

1. Reboot, choose **"Arch Linux (LTS emergency kernel)"** in the boot menu
   (press SPACE after the BIOS logo if the menu is hidden).
2. Log in normally, then either:

```bash
sudo pacman -Syu && sudo mkinitcpio -P    # unfinished update
sudo timeshift --restore                  # roll back
```

Or simply keep using the LTS kernel until Arch ships a fix:

```bash
sudo bootctl set-default arch-lts.conf     # temporary default
sudo bootctl set-default arch-linux.efi    # back to normal (use the id from: bootctl list)
```

The emergency kernel does **not** help if the problem is outside the kernel
(broken system library, damaged filesystem, broken boot loader).

### 7.6 Downgrade a single package from the cache

```bash
ls /var/cache/pacman/pkg/ | grep <package>
sudo pacman -U /var/cache/pacman/pkg/<package>-<old-version>.pkg.tar.zst
```

Packages that belong together must be downgraded together (e.g. all `nvidia-*` and
`lib32-nvidia-*` packages to the same version; a prebuilt kernel module must match its
kernel). When unsure, use the snapshot ([7.3](#73-roll-back-to-the-snapshot-universal-fix)).
The next `-Syu` upgrades it again.

### 7.7 Nothing boots at all: USB stick + chroot

Boot the Arch USB stick, then:

```bash
lsblk -f                                # find root and boot partitions
mount /dev/<root-partition> /mnt
mount /dev/<boot-partition> /mnt/boot
arch-chroot /mnt
```

Now you are "inside" your installed system:

```bash
pacman -Syu
mkinitcpio -P
timeshift --restore    # if needed
```

Then:

```bash
exit
umount -R /mnt
reboot
```

### 7.8 Common pacman errors

| Error | Fix |
|---|---|
| "invalid or corrupted package (PGP signature)" | `sudo pacman -Sy archlinux-keyring && sudo pacman -Su` |
| "unable to lock database" | See [7.2](#72-update-was-aborted--half-installed) (only if no pacman/yay/Arch-Update is running) |
| "conflicting files" / "exists in filesystem" | Check the Arch news first. Do **not** blindly use `--overwrite`. |
| "Packages to exclude" (yay) | Press ENTER |

---

## 8. Health checks and useful commands

**Errors / services**

```bash
journalctl -b -p 3            # errors since boot
journalctl -f                 # live log (q / Ctrl+C to quit)
systemctl --failed            # failed system services
systemctl --user --failed     # failed user services
```

**Packages**

```bash
pacman -Q | wc -l                     # installed packages (all)
pacman -Qe | wc -l                    # explicitly installed
pacman -Qm                            # AUR / foreign packages
pacman -Qdtq                          # orphans
pacman -Qdtq | sudo pacman -Rns -     # remove orphans (review first)
sudo pacman -Rns <package>            # remove a package + unneeded deps
pacman -Qo /path/to/file              # which package owns a file
pacman -Si <package>                  # is it in the official repos?
```

**Damaged / empty files** (e.g. after hard resets)

```bash
sudo pacman -Qkk 2>&1 | grep -i "size mismatch"
```

Then reinstall the listed packages: `sudo pacman -S <packages>` (AUR ones with `yay -S <packages>`).

**Config files**

```bash
sudo pacdiff    # merge .pacnew / .pacsave files
```

**Package cache**

```bash
paccache -d         # show what would be removed
sudo paccache -r    # keep only the last 3 versions
```

**Repositories**

```bash
grep -n '^\[' /etc/pacman.conf
```

Should show `[options]`, `[core]`, `[extra]` and optionally `[multilib]`.
Any `*-testing` entry: comment it out (`#` before the `[name]` line and its `Include` line), then:

```bash
sudo pacman -Syuu    # the double u allows downgrades back to the stable versions
```

**Boot**

```bash
sudo bootctl list --no-pager    # boot entries (systemd-boot)
uname -r                        # running kernel
df -h /boot                     # free space on the boot partition
```

**Disk**

```bash
df -h                              # free space
sudo smartctl -a /dev/nvme0n1      # SSD health
gdu ~                              # find what fills your disk (sudo pacman -S gdu)
```

**AUR safety**

Before installing: check the AUR page (votes, popularity, maintainer, last update, recent comments).

Check for the June 2026 malware campaign (no output = good; only works if your yay cache
from that time still exists):

```bash
grep -rlE "atomic-lockfile|js-digest" ~/.cache/yay 2>/dev/null
```

---

## 9. Don'ts

- Don't run `pacman -Sy <package>` (partial upgrade). Use `-Syu` or `-S`.
- Don't exclude packages from upgrades.
- Don't interrupt updates or hard-reset while pacman is running.
- Don't blindly use `--overwrite '*'`, `-Sdd` or `--nodeps` from forum posts.
- Don't enable `*-testing` repositories on a daily-use system.
- Don't ignore the Arch news or arch-manwarn warnings.
- Don't install random or orphaned AUR packages without checking them.
- Don't let months pass between updates.
- Don't keep your only backup on the same drive as your system.
- Don't install a second package manager that does its own updates (e.g. pamac on plain Arch). One updater is enough.

---

## 10. Quick reference card

| Task | Command |
|---|---|
| Update | `arch-update` (or `yay`) |
| Show Arch news | `arch-update --news` |
| Manual snapshot | `sudo timeshift --create --comments "before X"` |
| List snapshots | `sudo timeshift --list` |
| Roll back | `sudo timeshift --restore` |
| TTY | `Ctrl+Alt+F3` |
| Errors since boot | `journalctl -b -p 3` |
| Finish broken update | `sudo pacman -Syu && sudo mkinitcpio -P` |
| Keyring error | `sudo pacman -Sy archlinux-keyring && sudo pacman -Su` |
| Boot menu | SPACE after the BIOS logo (systemd-boot) |
| Emergency kernel as default | `sudo bootctl set-default arch-lts.conf` |
| Disk health | `sudo smartctl -a /dev/nvme0n1` |
| Check repos | `grep -n '^\[' /etc/pacman.conf` |
| Broken files | `sudo pacman -Qkk 2>&1 \| grep -i "size mismatch"` |
