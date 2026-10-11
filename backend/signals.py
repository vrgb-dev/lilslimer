#!/usr/bin/env python3

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path
from typing import Any


TERMINAL_WINDOW_CLASSES = {
    "org.kde.konsole",
    "gnome-terminal",
    "kitty",
    "alacritty",
    "wezterm",
}


def run_command(cmd: list[str], timeout: float = 0.75) -> str:
    """Run a command and return stripped stdout, or empty string on failure."""
    try:
        result = subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if result.returncode != 0:
            return ""
        return result.stdout.strip()
    except Exception:
        return ""


def get_cpu_percent() -> tuple[float, float]:
    stat = Path("/proc/stat").read_text(encoding="utf-8").splitlines()[0]
    parts = stat.split()
    if parts[0] != "cpu" or len(parts) < 8:
        raise RuntimeError("Unexpected /proc/stat format")

    values = [int(x) for x in parts[1:8]]
    user, nice, system, idle, iowait, irq, softirq = values

    idle_all = idle + iowait
    non_idle = user + nice + system + irq + softirq
    total = idle_all + non_idle

    return float(total), float(idle_all)


def get_battery_info() -> dict[str, Any]:
    """Discover batteries by sysfs supply type, regardless of device name.

    Battery status is authoritative for charging. AC online is used only if
    battery status is unavailable, and never on battery-less desktops.
    """
    power_dir = Path("/sys/class/power_supply")
    info: dict[str, Any] = {
        "battery_percent": None,
        "charging": None,
        "battery_status": None,
    }

    def read_attribute(directory: Path, name: str) -> str | None:
        try:
            return (directory / name).read_text(encoding="utf-8").strip()
        except (OSError, UnicodeError):
            return None

    try:
        supplies = sorted(power_dir.iterdir())
    except OSError:
        return info

    batteries = [p for p in supplies if read_attribute(p, "type") == "Battery"
                 and read_attribute(p, "present") != "0"]
    if not batteries:
        return info

    # Prefer a system battery over a mouse/headset battery when scope exists.
    batteries.sort(key=lambda p: (read_attribute(p, "scope") == "Device", p.name))
    battery = batteries[0]
    capacity = read_attribute(battery, "capacity")
    if capacity is not None:
        try:
            percent = int(capacity)
            if 0 <= percent <= 100:
                info["battery_percent"] = percent
        except ValueError:
            pass

    status = read_attribute(battery, "status")
    if status:
        info["battery_status"] = status
        if status.lower() != "unknown":
            info["charging"] = status.lower() == "charging"

    if info["charging"] is None:
        # Fallback only when battery status cannot establish charging.
        for supply in supplies:
            if read_attribute(supply, "type") in ("Mains", "USB", "USB_C", "USB_PD"):
                online = read_attribute(supply, "online")
                if online in ("0", "1"):
                    info["charging"] = online == "1"
                    break

    return info


def get_active_window_class() -> str:
    if shutil.which("kdotool"):
        return run_command(
            ["kdotool", "getactivewindow", "getwindowclassname"]
        ).strip().lower()

    if shutil.which("xdotool"):
        return run_command(
            ["xdotool", "getactivewindow", "getwindowclassname"]
        ).strip().lower()

    return ""


def get_active_window_hint() -> str:
    return get_active_window_class()


def get_terminal_activity_hint() -> bool:
    window_class = get_active_window_class()
    if not window_class:
        return False

    return window_class in TERMINAL_WINDOW_CLASSES


if __name__ == "__main__":
    print("battery =", get_battery_info())
    print("active_window =", get_active_window_hint())
    print("terminal_active =", get_terminal_activity_hint())
