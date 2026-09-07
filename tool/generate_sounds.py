"""Generates the Hi Hi Block sound effects as small mono WAV files.

Everything here is synthesised from scratch — plain sine partials with a soft
attack and an exponential decay — so the assets are original and carry no
third-party licence. Re-run with:

    python tool/generate_sounds.py

Output: assets/audio/*.wav (44.1 kHz, 16-bit mono).
"""

import math
import os
import struct
import wave

RATE = 44100
AMPLITUDE = 0.42  # headroom so nothing clips when partials stack


def envelope(t, duration, attack=0.008, decay=4.0):
    """Soft attack, exponential decay — a rounded 'pop' rather than a click."""
    if t < attack:
        return t / attack
    remaining = (t - attack) / max(duration - attack, 1e-6)
    return math.exp(-decay * remaining)


def tone(duration, partials, decay=4.0, pitch_bend=0.0):
    """One voice: `partials` is a list of (frequency_hz, relative_gain)."""
    frames = int(RATE * duration)
    out = []
    for i in range(frames):
        t = i / RATE
        # A gentle downward bend makes short blips feel soft instead of beepy.
        bend = 1.0 + pitch_bend * (t / duration)
        sample = 0.0
        for freq, gain in partials:
            sample += gain * math.sin(2 * math.pi * freq * bend * t)
        out.append(sample * envelope(t, duration, decay=decay))
    return out


def sequence(*voices):
    """Plays voices one after another, keeping any tail that overlaps."""
    total = []
    cursor = 0
    for offset_seconds, samples in voices:
        start = int(offset_seconds * RATE)
        if len(total) < start + len(samples):
            total.extend([0.0] * (start + len(samples) - len(total)))
        for i, s in enumerate(samples):
            total[start + i] += s
        cursor = max(cursor, start + len(samples))
    return total[:cursor]


def write(path, samples):
    peak = max((abs(s) for s in samples), default=1.0) or 1.0
    scale = AMPLITUDE / peak
    data = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
        for s in samples
    )
    with wave.open(path, "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data)
    print(f"{path}  {len(data) // 2} frames  {len(data) / 1024:.1f} KiB")


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)

    def target(name):
        return os.path.normpath(os.path.join(out_dir, name))

    # Place: a soft rounded pop with a slight downward bend.
    write(
        target("place.wav"),
        tone(0.09, [(660, 1.0), (1320, 0.18)], decay=6.0, pitch_bend=-0.18),
    )

    # Invalid: a low, dull tick. Quiet and short — never harsh.
    write(
        target("invalid.wav"),
        tone(0.11, [(180, 1.0), (240, 0.35)], decay=9.0, pitch_bend=-0.12),
    )

    # Clear: a bright two-note chime, A5 into E6.
    write(
        target("clear.wav"),
        sequence(
            (0.00, tone(0.26, [(880, 1.0), (1760, 0.22)], decay=4.5)),
            (0.06, tone(0.24, [(1318, 0.85), (2637, 0.16)], decay=4.5)),
        ),
    )

    # Combo: the same idea a fifth higher, so it reads as "more".
    write(
        target("combo.wav"),
        sequence(
            (0.00, tone(0.24, [(1046, 1.0), (2093, 0.22)], decay=4.5)),
            (0.05, tone(0.24, [(1568, 0.9), (3136, 0.18)], decay=4.5)),
            (0.10, tone(0.22, [(2093, 0.6)], decay=5.0)),
        ),
    )

    # Game over: a short, gentle descending pair. Wistful, not scary.
    write(
        target("game_over.wav"),
        sequence(
            (0.00, tone(0.30, [(523, 1.0), (1046, 0.15)], decay=3.5)),
            (0.16, tone(0.34, [(392, 0.95), (784, 0.14)], decay=3.0)),
        ),
    )


if __name__ == "__main__":
    main()
