#!/usr/bin/env python3

from __future__ import annotations

import json
import random
import signal
import sys
import time
from collections import deque
from pathlib import Path

from signals import (
    get_battery_info,
    get_cpu_percent,
    get_terminal_activity_hint,
)
from state_machine import SlimerInputs, decide_state


POLL_SECONDS = 2
STATE_PATH = (
    Path.home()
    / ".local/share/plasma/plasmoids/org.vrgb.lilslimer/contents/ui/state.json"
)


JUDGE_CHANCE = 0.25
JUDGE_MIN_SECONDS = 8
JUDGE_MAX_SECONDS = 20
JUDGE_COOLDOWN_MIN_SECONDS = 30
JUDGE_COOLDOWN_MAX_SECONDS = 90


class CpuSampler:
    def __init__(self) -> None:
        total, idle = get_cpu_percent()
        self.prev_total = total
        self.prev_idle = idle

    def sample(self) -> float:
        total, idle = get_cpu_percent()

        total_delta = total - self.prev_total
        idle_delta = idle - self.prev_idle

        self.prev_total = total
        self.prev_idle = idle

        if total_delta <= 0:
            return 0.0

        usage = 100.0 * (1.0 - (idle_delta / total_delta))
        return max(0.0, min(100.0, usage))


def atomic_write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(".tmp")

    with temp_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

    temp_path.replace(path)


def rolling_average(values: deque[float]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)



class JudgeSampler:
    """
    Rolls judge once per terminal activation, then holds/suppresses it
    so judge feels occasional instead of flickery.
    """

    def __init__(self) -> None:
        self.was_terminal_active = False
        self.judge_until = 0.0
        self.cooldown_until = 0.0

    def update(self, terminal_active: bool, now: float) -> bool:
        if not terminal_active:
            self.was_terminal_active = False
            return False

        judge_active = now < self.judge_until

        if not self.was_terminal_active:
            self.was_terminal_active = True

            if now >= self.cooldown_until and random.random() < JUDGE_CHANCE:
                duration = random.randint(JUDGE_MIN_SECONDS, JUDGE_MAX_SECONDS)
                cooldown = random.randint(
                    JUDGE_COOLDOWN_MIN_SECONDS,
                    JUDGE_COOLDOWN_MAX_SECONDS,
                )
                self.judge_until = now + duration
                self.cooldown_until = self.judge_until + cooldown
                judge_active = True

        if now >= self.judge_until:
            judge_active = False

        return judge_active


def main() -> int:
    running = True

    def handle_signal(signum, frame) -> None:
        nonlocal running
        running = False

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    cpu_sampler = CpuSampler()
    judge_sampler = JudgeSampler()

    cpu_history_30s: deque[float] = deque(maxlen=max(1, 30 // POLL_SECONDS))
    cpu_history_3m: deque[float] = deque(maxlen=max(1, 180 // POLL_SECONDS))
    recent_spikes: deque[bool] = deque(maxlen=max(1, 60 // POLL_SECONDS))

    calm_seconds = 0
    productive_seconds = 0
    hell_seconds = 0
    hell_hold_seconds = 0

    print(f"[slimer] writing state to: {STATE_PATH}", flush=True)

    while running:
        loop_started = time.time()

        try:
            cpu_now = cpu_sampler.sample()
            cpu_history_30s.append(cpu_now)
            cpu_history_3m.append(cpu_now)

            spike = cpu_now > 20.0
            recent_spikes.append(spike)
            recent_spike = any(recent_spikes)

            battery = get_battery_info()
            terminal_active = get_terminal_activity_hint()
            judge_active = judge_sampler.update(terminal_active, time.time())

            cpu_avg_30s = rolling_average(cpu_history_30s)
            cpu_avg_3m = rolling_average(cpu_history_3m)

            currently_calm = (
                cpu_now < 12.0
                and cpu_avg_30s < 10.0
                and not recent_spike
            )

            currently_productive = (
                cpu_avg_30s >= 22.0
                and cpu_now >= 12.0
            )

            currently_hell = (
                cpu_avg_30s >= 55.0
                or cpu_avg_3m >= 40.0
                or (cpu_now >= 75.0 and cpu_avg_30s >= 35.0)
            )

            if currently_calm:
                calm_seconds += POLL_SECONDS
            else:
                calm_seconds = 0

            if currently_productive:
                productive_seconds += POLL_SECONDS
            else:
                productive_seconds = 0

            if currently_hell:
                hell_seconds += POLL_SECONDS
                if hell_seconds >= 8:
                    hell_hold_seconds = 10
            else:
                hell_seconds = 0
                hell_hold_seconds = max(0, hell_hold_seconds - POLL_SECONDS)

            state_inputs = SlimerInputs(
                cpu_percent=round(cpu_now, 2),
                cpu_avg_30s=round(cpu_avg_30s, 2),
                cpu_avg_3m=round(cpu_avg_3m, 2),
                battery_percent=battery["battery_percent"],
                charging=battery["charging"],
                recent_spike=recent_spike,
                calm_seconds=calm_seconds,
                productive_seconds=productive_seconds,
                hell_seconds=hell_seconds,
                hell_hold_seconds=hell_hold_seconds,
            )

            slimer_state = decide_state(state_inputs)

            payload = {
                "state": slimer_state.state,
                "mood": slimer_state.mood,
                "reason": slimer_state.reason,
                "cpu_percent": state_inputs.cpu_percent,
                "cpu_avg_30s": state_inputs.cpu_avg_30s,
                "cpu_avg_3m": state_inputs.cpu_avg_3m,
                "battery_percent": state_inputs.battery_percent,
                "charging": state_inputs.charging,
                "recent_spike": state_inputs.recent_spike,
                "calm_seconds": state_inputs.calm_seconds,
                "productive_seconds": state_inputs.productive_seconds,
                "hell_seconds": state_inputs.hell_seconds,
                "hell_hold_seconds": state_inputs.hell_hold_seconds,
                "terminal_active": terminal_active,
                "judge_active": judge_active,
                "updated_at": int(time.time()),
            }

            atomic_write_json(STATE_PATH, payload)

            print(
                "[slimer] "
                f"cpu={payload['cpu_percent']:.2f}% "
                f"avg30={payload['cpu_avg_30s']:.2f}% "
                f"avg3m={payload['cpu_avg_3m']:.2f}% "
                f"battery={payload['battery_percent']} "
                f"charging={payload['charging']} "
                f"spike={payload['recent_spike']} "
                f"calm={payload['calm_seconds']}s "
                f"productive={payload['productive_seconds']}s "
                f"hell={payload['hell_seconds']}s "
                f"hell_hold={payload['hell_hold_seconds']}s "
                f"judge={payload['judge_active']} "
                f"state={payload['state']} "
                f"reason={payload['reason']}",
                flush=True,
            )

        except Exception as exc:
            print(f"[slimer] error: {exc}", file=sys.stderr, flush=True)

        elapsed = time.time() - loop_started
        sleep_for = max(0.0, POLL_SECONDS - elapsed)
        time.sleep(sleep_for)

    print("[slimer] shutting down cleanly", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
