# Performance Optimization

System-level tweaks that remove performance and latency bottlenecks on Arch Linux, mainly for gaming. No in-game graphics settings — only things in the system itself.

For the display side (VRR/G-Sync, FPS caps, tearing) see **[Low Latency Gaming](Low%20Latency%20Gaming.md)**.

Every change in this guide is **permanent** (survives reboots) and comes with a way to **verify** and **undo** it.

> **Last updated:** November 2026
> **Tested on:** Intel Core i5 12th Gen · NVIDIA RTX 3060 Ti (`nvidia-open`) · 16 GB RAM · NVMe SSD · Arch kernel 7.2 · Hyprland / KDE Plasma (Wayland)

---

## Table of Contents

1. [NTSync (Proton games)](#1-ntsync-proton-games)
2. [sysctl tweaks: split lock penalty & NMI watchdog](#2-sysctl-tweaks-split-lock-penalty--nmi-watchdog)
3. [CPU performance profile](#3-cpu-performance-profile)
4. [GPU: max performance clocks](#4-gpu-max-performance-clocks)
5. [Bigger NVIDIA shader cache](#5-bigger-nvidia-shader-cache)
6. [Gaming CPU scheduler (optional)](#6-gaming-cpu-scheduler-optional)
7. [Already default on Arch — just verify](#7-already-default-on-arch--just-verify)
8. [Things to avoid](#8-things-to-avoid)
9. [Full status check](#9-full-status-check)
10. [Undo everything](#10-undo-everything)
11. [References](#11-references)

---

## 1. NTSync (Proton games)

**What it is:** Windows games rely heavily on Windows-style thread synchronization (waiting for events, mutexes, etc.). Wine/Proton used to emulate this in userspace (esync/fsync). **NTSync** implements these primitives directly in the Linux kernel, which lowers CPU overhead and can reduce stutter in CPU-bound Proton games.

**Who benefits:** Windows games running through Proton. Native Linux games (e.g. CS2) are not affected.

**Requirements:** the `ntsync` kernel module must be loaded, and the game must run on **Proton 11 or newer** (stable since July 2026), which uses NTSync automatically when `/dev/ntsync` exists.

### Apply

```bash
sudo pacman -S ntsync-autoload
sudo reboot
```

Then in Steam: **Settings → Compatibility** → set the default compatibility tool to **Proton 11** (or newer / Proton Experimental).

### Verify

```bash
ls -l /dev/ntsync
```

If the device exists, the module is loaded. To confirm a running Proton game actually uses it:

```bash
sudo lsof /dev/ntsync    # install with: sudo pacman -S lsof
```

Wine/game processes in the output = NTSync is in use.

---

## 2. sysctl tweaks: split lock penalty & NMI watchdog

### Split lock mitigation

**What it is:** A *split lock* is an atomic memory operation on data that crosses two 64-byte cache lines. The CPU has to lock the entire memory bus to perform it, which stalls **all** cores. Since kernel 6.2, Linux deliberately slows down programs that do this. That protects multi-user servers, but some games (often Windows games via Proton) and the Steam client trigger split locks and end up **stuttering** because of the penalty.

Setting `kernel.split_lock_mitigate=0` removes the penalty. The kernel still detects and logs split locks, it just no longer throttles the program. On a single-user gaming PC there's no real downside.

Check whether anything on your system triggers split locks:

```bash
journalctl -k -g split_lock
```

### NMI watchdog

**What it is:** A kernel feature that periodically checks whether a CPU has hung, using a hardware performance counter. Not needed on a desktop. The gain is small, but it's free.

### Apply

```bash
sudo tee /etc/sysctl.d/99-gaming.conf <<'EOF'
kernel.split_lock_mitigate=0
kernel.nmi_watchdog=0
EOF
sudo sysctl --system
```

- Files in `/etc/sysctl.d/` are loaded automatically on every boot.
- `sudo sysctl --system` applies them immediately without a reboot.
- `sudo tee` is used because `sudo echo ... > file` fails: the `>` redirect runs as your normal user, not as root.

### Verify

```bash
sysctl kernel.split_lock_mitigate kernel.nmi_watchdog
```

Both should be `0`.

---

## 3. CPU performance profile

**What it is:** By default, Intel CPUs (with the `intel_pstate` driver) favor power saving and only ramp up clocks under load. That ramp-up adds a little latency during sudden load spikes. The **performance** profile tells the CPU to react immediately. Costs more power, improves frametime consistency.

### Apply

```bash
sudo pacman -S power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon
powerprofilesctl set performance
```

`power-profiles-daemon` remembers the selected profile across reboots.

> [!WARNING]
> Don't combine this with `tlp`, `auto-cpufreq` or similar tools. They fight over the same settings.

### Verify

```bash
powerprofilesctl get
cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort -u
```

Both should print `performance`.

---

## 4. GPU: max performance clocks

**What it is:** GPUs drop their core and memory clocks as soon as the load gets light and ramp them back up when needed. Every ramp-up takes a moment, which can show up as small hitches — for example when a game's load suddenly spikes, or when switching workspaces on the desktop. Locking the GPU at its maximum clocks is the Linux equivalent of **"Prefer maximum performance"** in the NVIDIA Control Panel on Windows. Costs more power and heat, also at idle.

This vault has a setup script for each vendor. Both keep the setting **across reboots and suspend**.

### NVIDIA: [`nvidia-maxperf-setup.sh`](nvidia-maxperf-setup.sh)

Locks the GPU core and memory clocks to fixed values.

**1. Find your card's maximum clocks:**

```bash
nvidia-smi -q -d SUPPORTED_CLOCKS | head -n 20
```

The first `Memory` value and the first `Graphics` value below it are the highest your card supports.

**2. Put those values into the script**, then run it from the vault folder:

```bash
cd ~/config-backup
bash nvidia-maxperf-setup.sh
```

**Verify:**

```bash
nvidia-smi --query-gpu=clocks.gr,clocks.mem --format=csv
```

On the desktop with no game running, both clocks should stay at the locked values instead of dropping back to idle clocks.

### AMD: [`amdgpu-maxperf-setup.sh`](amdgpu-maxperf-setup.sh)

Sets the GPU's performance level to `high`, so it stays at its highest power state.

```bash
cd ~/config-backup
bash amdgpu-maxperf-setup.sh
```

**Verify:**

```bash
cat /sys/class/drm/card*/device/power_dpm_force_performance_level
```

Should print `high`.

---

## 5. Bigger NVIDIA shader cache

**What it is:** The NVIDIA driver stores compiled shaders on disk. When the cache is full, the driver deletes old entries, and those shaders have to be compiled again next time — which causes **stutter**. These two variables make the cache much bigger (12 GB) and stop the driver from cleaning it up automatically.

The cache lives in your home directory (`~/.cache/nvidia/`) and in each Steam library (`steamapps/shadercache/`), so make sure that partition has some free space.

### Apply

```bash
echo '__GL_SHADER_DISK_CACHE_SIZE=12000000000' | sudo tee -a /etc/environment
echo '__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1' | sudo tee -a /etc/environment
```

> [!CAUTION]
> Don't forget the `-a` (append). Without it, `tee` **overwrites** `/etc/environment` and everything else in it is lost — including the [global MangoHud setup](README.md#global-mangohud-system-wide).

Log out and back in for the change to take effect.

Also check in Steam: **Settings → Downloads → Shader Pre-Caching** should be enabled.

### Verify

```bash
env | grep __GL_SHADER
```

---

## 6. Gaming CPU scheduler (optional)

**What it is:** The CPU scheduler decides which process runs on which core and when. With **sched_ext**, alternative schedulers can be loaded at runtime without changing the kernel. **`scx_lavd`** is designed specifically for gaming (it's also used on the Steam Deck) and aims for higher, more consistent frame rates.

Results depend on the game and hardware, so **test first** and compare the frametime graph (e.g. in MangoHud).

> [!WARNING]
> Don't use `ananicy-cpp` (or similar priority daemons) together with sched_ext schedulers. They can make the scheduler time out and get unloaded.

### Test

```bash
sudo pacman -S scx-scheds scx-tools
sudo scx_lavd
```

Keep the terminal open while gaming. Press **Ctrl+C** to stop it — the system immediately falls back to the default scheduler.

### Apply permanently

```bash
sudo mkdir -p /etc/scx_loader
sudo tee /etc/scx_loader/config.toml <<'EOF'
default_sched = "scx_lavd"
default_mode = "Gaming"
EOF
sudo systemctl enable --now scx_loader.service
```

### Verify

```bash
scxctl get
cat /sys/kernel/sched_ext/state
```

---

## 7. Already default on Arch — just verify

These are commonly recommended "tweaks" that a current Arch install already does. No action needed unless the check fails.

| Setting | Check | Expected |
|---|---|---|
| Memory map limit (needed by some Proton games) | `sysctl vm.max_map_count` | `1048576` (Arch default since 2024) |
| NVIDIA DRM kernel modesetting | `cat /sys/module/nvidia_drm/parameters/modeset` | `Y` |
| NVMe I/O scheduler | `cat /sys/block/nvme0n1/queue/scheduler` | `[none]` |
| Swap / zram | `zramctl` and `swapon --show` | a zram device is listed |

### If you have no swap at all

With 16 GB of RAM, a heavy game can fill memory and freeze the system. zram provides compressed swap in RAM:

```bash
sudo pacman -S zram-generator
sudo tee /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service
```

---

## 8. Things to avoid

| Tweak | Why not |
|---|---|
| `mitigations=off` | Disables protection against CPU security vulnerabilities. Almost no gaming gain on modern CPUs. |
| Real-time kernel (`linux-rt`) | Built for guaranteed response times, not throughput. Does not improve gaming performance. |
| Switching kernels (`linux-zen`, etc.) | Not needed — the stock kernel already supports NTSync and sched_ext. With NVIDIA you'd also need the DKMS driver variant. |
| Huge sysctl lists from GitHub/Reddit (`vm.dirty_*`, `net.*`, …) | Usually no measurable effect, sometimes worse. |
| `ananicy-cpp` with sched_ext | Conflicts with sched_ext schedulers (see section 6). |
| `processor.max_cstate=1`, `intel_idle.max_cstate=0` | More heat and power draw for no measurable benefit. |
| GameMode on top of sections 3 and 4 | Mostly switches CPU and GPU to performance while a game runs, which sections 3 and 4 already do permanently. |

---

## 9. Full status check

Paste this into a terminal to see the state of everything in this guide at once:

```bash
echo "NTSync device:       $(test -e /dev/ntsync && echo yes || echo no)"
echo "split_lock_mitigate: $(sysctl -n kernel.split_lock_mitigate)"
echo "nmi_watchdog:        $(sysctl -n kernel.nmi_watchdog)"
echo "Power profile:       $(powerprofilesctl get 2>/dev/null || echo 'not installed')"
echo "CPU EPP:             $(cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort -u | tr '\n' ' ')"
echo "GPU:                 $(nvidia-smi --query-gpu=clocks.gr,clocks.mem --format=csv,noheader 2>/dev/null || cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null)"
echo "Shader cache size:   ${__GL_SHADER_DISK_CACHE_SIZE:-not set}"
echo "Shader cleanup off:  ${__GL_SHADER_DISK_CACHE_SKIP_CLEANUP:-not set}"
echo "sched_ext:           $(cat /sys/kernel/sched_ext/state 2>/dev/null || echo 'n/a')"
echo "vm.max_map_count:    $(sysctl -n vm.max_map_count)"
echo "NVIDIA modeset:      $(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo 'n/a')"
```

Expected:

| Line | Expected |
|---|---|
| NTSync device | `yes` |
| split_lock_mitigate | `0` |
| nmi_watchdog | `0` |
| Power profile | `performance` |
| CPU EPP | `performance` |
| GPU | your locked clocks (NVIDIA) or `high` (AMD), even on the desktop |
| Shader cache size | `12000000000` |
| Shader cleanup off | `1` |
| sched_ext | `enabled` (only if you did section 6) |
| vm.max_map_count | `1048576` |
| NVIDIA modeset | `Y` |

---

## 10. Undo everything

```bash
# 1. NTSync
sudo pacman -Rns ntsync-autoload

# 2. sysctl tweaks
sudo rm /etc/sysctl.d/99-gaming.conf

# 3. CPU profile
powerprofilesctl set balanced

# 4. GPU clocks, NVIDIA: reset now
sudo nvidia-smi -rgc && sudo nvidia-smi -rmc
# 4. GPU, AMD: back to automatic
echo auto | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level

# 5. Shader cache (removes only the two __GL_SHADER lines)
sudo sed -i '/__GL_SHADER_DISK_CACHE/d' /etc/environment

# 6. Scheduler
sudo systemctl disable --now scx_loader.service
```

For the GPU, also disable whatever the setup script installed to re-apply the clocks at boot and after suspend. This lists the candidates:

```bash
systemctl list-unit-files | grep -i -e nvidia -e amdgpu -e maxperf
```

Reboot afterwards.

---

## 11. References

- [ArchWiki — Gaming](https://wiki.archlinux.org/title/Gaming)
- [ArchWiki — Improving performance](https://wiki.archlinux.org/title/Improving_performance)
- [Arch News — Increasing the default vm.max_map_count value](https://archlinux.org/news/increasing-the-default-vmmax_map_count-value/)
- [Arch package — ntsync-autoload](https://archlinux.org/packages/extra/any/ntsync-autoload/)
- [Arch package — scx-tools](https://archlinux.org/packages/extra/x86_64/scx-tools/)
- [scx_loader configuration](https://docs.rs/crate/scx_loader/latest/source/configuration.md)
- [LWN — sched_ext and scx_lavd](https://lwn.net/Articles/991205/)
- [VR on Linux — System configuration (split lock, NTSync)](https://vronlinux.org/docs/other/system_config/)
