#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class SlimerInputs:
    cpu_percent: float
    cpu_avg_30s: float
    cpu_avg_3m: float
    battery_percent: int | None
    charging: bool | None
    recent_spike: bool
    calm_seconds: int
    productive_seconds: int
    hell_seconds: int
    hell_hold_seconds: int
    unamused_active: bool = False


@dataclass
class SlimerState:
    state: str
    mood: str
    reason: str


def decide_state(data: SlimerInputs) -> SlimerState:
    """
    State priority:

    charging > battery (dead/drained) > hell > productive > unamused > idle ladder > normal
    """

    # 🔥 CHARGING OVERRIDE
    if data.charging:
        return SlimerState(
            state="charging",
            mood="charging",
            reason="device is charging",
        )

    # 🔋 BATTERY STATES (only if NOT charging)
    if data.battery_percent is not None:
        if data.battery_percent <= 10:
            return SlimerState(
                state="dead",
                mood="no_power",
                reason="battery <= 10",
            )
        elif data.battery_percent <= 20:
            return SlimerState(
                state="drained",
                mood="low_power",
                reason="battery <= 20",
            )

    # 🔥 HELL (SUSTAINED HEAVY LOAD + STICKY EXIT)
    if data.hell_seconds >= 8 or data.hell_hold_seconds > 0:
        return SlimerState(
            state="hell",
            mood="overloaded",
            reason="sustained heavy load or hell hold active",
        )

    # 😎 PRODUCTIVE (FOCUSED WORK — STABLE LOGIC)
    if data.productive_seconds >= 12:
        return SlimerState(
            state="productive",
            mood="focused",
            reason="sustained work for 12+ seconds",
        )

    # 😒 TEMPORARY DISCOVER NOTIFICATION
    if data.unamused_active:
        return SlimerState(state="unamused", mood="unamused", reason="Discover announced updates")

    # 😴 IDLE LADDER
    if (
        data.cpu_avg_3m < 15.0
        and not data.recent_spike
        and data.calm_seconds >= 120
    ):
        return SlimerState(
            state="sleep",
            mood="asleep",
            reason="quiet system sustained for 2+ minutes",
        )

    if (
        data.cpu_avg_3m < 15.0
        and not data.recent_spike
        and data.calm_seconds >= 60
    ):
        return SlimerState(
            state="drowsy",
            mood="sleepy",
            reason="quiet system sustained for 1+ minute",
        )

    if (
        data.cpu_avg_30s < 10.0
        and not data.recent_spike
        and data.calm_seconds >= 20
    ):
        return SlimerState(
            state="calm",
            mood="calm",
            reason="quiet system sustained for 20+ seconds",
        )

    # 🟢 DEFAULT
    return SlimerState(
        state="normal",
        mood="baseline",
        reason="default baseline behavior",
    )
