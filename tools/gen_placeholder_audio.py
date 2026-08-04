"""Generate Dark Sector's placeholder sound set.

Every file under `assets/audio/` is written by this script. They are stand-ins:
synthesised from sine, square and noise with the Python standard library and
nothing else, deliberately crude, and meant to be replaced one at a time by real
recordings or a sound designer's set. The point of having them is that the game
can be *tuned* with sound in it — when a laser fires, how loud an explosion is
against the music, whether the quiz chime lands before the countdown — none of
which can be judged against silence, and none of which has to be redone when the
real files arrive.

Replacing one is a matter of dropping a `.wav` with the same name into the same
folder. `autoload/Audio.gd` looks sounds up by name and has no idea where they
came from, so nothing in the game needs editing. Any sample rate or bit depth
Godot's WAV importer accepts will do; these are 22.05 kHz 16-bit mono because
that is plenty for placeholders and keeps the repository small.

Run it from the repo root:

    python tools/gen_placeholder_audio.py

It is seeded, so re-running produces byte-identical files and does not churn the
repository. After running, let Godot re-import (`godot --headless --path . --import`).
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100 // 2
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(REPO, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(REPO, "assets", "audio", "music")

# Seeded so the noise beds come out the same on every run — an unseeded
# generator would rewrite every explosion in the repo each time this is touched.
RNG = random.Random(20260804)


# --------------------------------------------------------------------------
# Primitives
# --------------------------------------------------------------------------


def _shape(name, phase):
    if name == "sine":
        return math.sin(phase)
    if name == "square":
        return 1.0 if math.sin(phase) >= 0.0 else -1.0
    if name == "saw":
        return 2.0 * ((phase / math.tau) % 1.0) - 1.0
    if name == "triangle":
        return 2.0 * abs(2.0 * ((phase / math.tau) % 1.0) - 1.0) - 1.0
    raise ValueError(name)


def osc(duration, f0, f1=None, shape="sine"):
    """One oscillator, optionally gliding exponentially from f0 to f1.

    The glide is exponential rather than linear because pitch is heard
    logarithmically: a linear sweep from 900 Hz to 90 Hz spends most of its
    length in the top octave and arrives at the bottom as a click.
    """
    count = max(1, int(duration * SAMPLE_RATE))
    f1 = f0 if f1 is None else f1
    ratio = f1 / f0
    out = [0.0] * count
    phase = 0.0
    for i in range(count):
        freq = f0 * (ratio ** (i / count))
        phase += math.tau * freq / SAMPLE_RATE
        out[i] = _shape(shape, phase)
    return out


def noise(duration):
    count = max(1, int(duration * SAMPLE_RATE))
    return [RNG.uniform(-1.0, 1.0) for _ in range(count)]


def envelope(buf, attack=0.004, release=None, power=2.5):
    """Fade in fast, fade out on a curve. Applied in place, returns the buffer.

    `power` above 1 makes the tail fall away quickly and then linger, which is
    what makes a burst read as an impact rather than as a note being let go.
    """
    count = len(buf)
    attack_samples = max(1, int(attack * SAMPLE_RATE))
    release_samples = count if release is None else max(1, int(release * SAMPLE_RATE))
    start = count - release_samples
    for i in range(count):
        gain = 1.0
        if i < attack_samples:
            gain = i / attack_samples
        if i >= start:
            gain *= (1.0 - (i - start) / release_samples) ** power
        buf[i] *= gain
    return buf


def lowpass(buf, cutoff):
    """One-pole lowpass. Crude, and that is the whole idea — it is what turns
    white noise into something with a body rather than a hiss."""
    alpha = 1.0 - math.exp(-math.tau * cutoff / SAMPLE_RATE)
    out = [0.0] * len(buf)
    value = 0.0
    for i, sample in enumerate(buf):
        value += alpha * (sample - value)
        out[i] = value
    return out


def sweep_lowpass(buf, start_hz, end_hz):
    """Lowpass whose cutoff falls across the buffer — an explosion losing its
    top end as it disperses, which is most of what makes one sound big."""
    out = [0.0] * len(buf)
    value = 0.0
    count = max(1, len(buf))
    ratio = end_hz / start_hz
    for i, sample in enumerate(buf):
        cutoff = start_hz * (ratio ** (i / count))
        alpha = 1.0 - math.exp(-math.tau * cutoff / SAMPLE_RATE)
        value += alpha * (sample - value)
        out[i] = value
    return out


def mix(*buffers):
    length = max(len(b) for b in buffers)
    out = [0.0] * length
    for buf in buffers:
        for i, sample in enumerate(buf):
            out[i] += sample
    return out


def place(canvas, buf, at_seconds, gain=1.0):
    """Add `buf` into `canvas` at a time offset, clipped to the canvas."""
    start = int(at_seconds * SAMPLE_RATE)
    for i, sample in enumerate(buf):
        index = start + i
        if 0 <= index < len(canvas):
            canvas[index] += sample * gain
    return canvas


def gain(buf, amount):
    return [sample * amount for sample in buf]


def normalize(buf, peak=0.86):
    loudest = max((abs(s) for s in buf), default=0.0)
    if loudest < 1e-9:
        return buf
    scale = peak / loudest
    return [sample * scale for sample in buf]


def write(directory, name, buf, peak=0.86):
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, name + ".wav")
    samples = normalize(buf, peak)
    frames = bytearray()
    for sample in samples:
        clamped = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(clamped * 32767))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(frames))
    print("%-28s %5.2fs" % (os.path.relpath(path, REPO), len(samples) / SAMPLE_RATE))


def note_hz(semitones_from_a4):
    return 440.0 * (2.0 ** (semitones_from_a4 / 12.0))


# Semitone offsets from A4, so the music below reads as notes rather than as
# frequencies. C4 is three semitones below A4's octave.
NOTES = {
    "C3": -21, "D3": -19, "E3": -17, "F3": -16, "G3": -14, "A3": -12, "B3": -10,
    "C4": -9, "D4": -7, "E4": -5, "F4": -4, "G4": -2, "A4": 0, "B4": 2,
    "C5": 3, "D5": 5, "E5": 7, "F5": 8, "G5": 10, "A5": 12, "C6": 15,
}


def tone(name, duration, shape="sine", detune=0.0):
    freq = note_hz(NOTES[name]) * (2.0 ** (detune / 1200.0))
    return envelope(osc(duration, freq, shape=shape), attack=0.01, power=2.0)


# --------------------------------------------------------------------------
# Sound effects
# --------------------------------------------------------------------------


def sfx_laser():
    """The turret's shot. Fires up to five times a second, so it is short, and
    its pitch falls fast — a flat blip at that rate turns into a machine noise."""
    body = osc(0.16, 1500.0, 260.0, "square")
    air = gain(lowpass(noise(0.16), 3000.0), 0.35)
    return envelope(mix(gain(body, 0.7), air), attack=0.002, power=3.0)


def sfx_alien_explode():
    low = osc(0.45, 180.0, 45.0, "sine")
    burst = sweep_lowpass(noise(0.45), 4200.0, 320.0)
    return envelope(mix(gain(burst, 0.9), gain(low, 0.6)), attack=0.002, power=2.2)


def sfx_carrier_explode():
    """The ore carrier's death. Longer and an octave lower than a scout's — the
    hardest kill on the field should not sound the same as the easiest."""
    low = osc(0.95, 130.0, 30.0, "sine")
    burst = sweep_lowpass(noise(0.95), 3200.0, 160.0)
    crack = envelope(gain(noise(0.08), 0.8), attack=0.001, power=4.0)
    return envelope(mix(gain(burst, 1.0), gain(low, 0.85), crack), attack=0.002, power=1.8)


def sfx_armour_hit():
    """A hit the carrier walked away from. Metallic and unsatisfying on purpose:
    it has to read as 'that landed, keep shooting', not as a kill."""
    ring = mix(
        gain(osc(0.18, 900.0, 780.0, "triangle"), 0.6),
        gain(osc(0.18, 1370.0, 1200.0, "triangle"), 0.35),
    )
    tick = gain(sweep_lowpass(noise(0.05), 6000.0, 1500.0), 0.5)
    return envelope(mix(ring, tick), attack=0.001, power=3.0)


def sfx_leak():
    """An alien got through. The only sound in the game that is meant to feel
    bad — a falling two-tone alarm, which is the shape of every 'you lost
    something' cue a child has already learned from other games."""
    first = envelope(osc(0.22, 520.0, 500.0, "square"), attack=0.004, power=2.0)
    second = envelope(osc(0.34, 390.0, 300.0, "square"), attack=0.004, power=2.0)
    canvas = [0.0] * int(0.62 * SAMPLE_RATE)
    place(canvas, first, 0.0, 0.55)
    place(canvas, second, 0.2, 0.6)
    return canvas


def sfx_quiz_correct():
    """A rising major arpeggio — the reward for the educational layer, and the
    one sound that should make a kid want to hear it again."""
    canvas = [0.0] * int(0.95 * SAMPLE_RATE)
    for index, name in enumerate(["C5", "E5", "G5", "C6"]):
        place(canvas, tone(name, 0.5, "triangle"), index * 0.09, 0.5)
    return canvas


def sfx_quiz_wrong():
    """Soft, low and short. The storyboard is firm that a wrong answer is not a
    punishment, so this is a shrug rather than a buzzer — no dissonance, no
    rasp, nothing a child would hear as being told off."""
    canvas = [0.0] * int(0.6 * SAMPLE_RATE)
    place(canvas, tone("G4", 0.3, "sine"), 0.0, 0.55)
    place(canvas, tone("E4", 0.42, "sine"), 0.13, 0.5)
    return canvas


def sfx_ui_click():
    return envelope(osc(0.06, 880.0, 620.0, "triangle"), attack=0.001, power=3.0)


def sfx_ui_key():
    """The on-screen keyboard, tapped dozens of times per name. Quieter and
    shorter than a button, or signing in becomes a drum solo."""
    return envelope(osc(0.035, 1500.0, 1200.0, "sine"), attack=0.001, power=3.0)


def sfx_countdown():
    return envelope(osc(0.12, 780.0, 780.0, "sine"), attack=0.004, power=2.5)


def sfx_launch():
    return envelope(osc(0.4, 420.0, 1240.0, "triangle"), attack=0.01, power=1.6)


def sfx_scene_cleared():
    canvas = [0.0] * int(1.5 * SAMPLE_RATE)
    for index, name in enumerate(["C5", "E5", "G5"]):
        place(canvas, tone(name, 0.7, "triangle"), index * 0.13, 0.45)
    place(canvas, tone("C6", 0.9, "triangle"), 0.42, 0.5)
    place(canvas, tone("G5", 0.9, "sine"), 0.42, 0.3)
    return canvas


def sfx_victory():
    """Scene 4 cleared: 'Yay!! We protected Earth!'. The longest cue in the set,
    because it plays under the one screen nobody is in a hurry to leave."""
    canvas = [0.0] * int(2.6 * SAMPLE_RATE)
    fanfare = ["C5", "E5", "G5", "C6", "G5", "C6"]
    for index, name in enumerate(fanfare):
        place(canvas, tone(name, 0.55, "triangle"), index * 0.16, 0.4)
    for index, name in enumerate(["C4", "G4", "C5"]):
        place(canvas, tone(name, 1.6, "sine"), 0.96, 0.22 - index * 0.04)
    place(canvas, tone("C6", 1.4, "triangle"), 1.1, 0.42)
    place(canvas, tone("E5", 1.4, "sine"), 1.1, 0.24)
    return canvas


def sfx_game_over():
    """Falling, but resolved rather than sour: the run ended and the score still
    goes on the board, so this should not sound like a mistake was made."""
    canvas = [0.0] * int(1.8 * SAMPLE_RATE)
    for index, name in enumerate(["G4", "E4", "C4"]):
        place(canvas, tone(name, 0.9, "triangle"), index * 0.24, 0.45)
    place(canvas, tone("C3", 1.3, "sine"), 0.48, 0.35)
    return canvas


# --------------------------------------------------------------------------
# Music
# --------------------------------------------------------------------------

# Both beds are written to loop: they are an exact number of bars long, the
# first beat lands on sample zero, and nothing is scheduled late enough to still
# be ringing at the end. `Audio.gd` sets AudioStreamWAV.loop_mode at load time
# rather than relying on import settings, so the seam is a wrap, not a restart.

MENU_BARS = 4
MENU_BAR_SECONDS = 3.0


def music_menu():
    """The title, briefing, quiz and results bed. Slow, wide and harmonically
    still — it plays under the fact card, which is the screen in this game that
    most needs a child's attention on the words rather than the sound."""
    total = MENU_BARS * MENU_BAR_SECONDS
    canvas = [0.0] * int(total * SAMPLE_RATE)
    chords = [
        ["C3", "G3", "C4", "E4"],
        ["A3", "E4", "A4", "C5"],
        ["F3", "C4", "F4", "A4"],
        ["G3", "D4", "G4", "B4"],
    ]
    for bar, chord in enumerate(chords):
        at = bar * MENU_BAR_SECONDS
        for voice, name in enumerate(chord):
            pad = envelope(
                osc(MENU_BAR_SECONDS * 0.96, note_hz(NOTES[name]), shape="triangle"),
                attack=0.5,
                release=1.4,
                power=1.6,
            )
            # A few cents of detune between voices, so four oscillators read as
            # a chord with air in it instead of one thick buzzing note.
            shimmer = envelope(
                osc(
                    MENU_BAR_SECONDS * 0.96,
                    note_hz(NOTES[name]) * (2.0 ** (6.0 / 1200.0)),
                    shape="sine",
                ),
                attack=0.6,
                release=1.4,
                power=1.6,
            )
            place(canvas, pad, at, 0.16 - voice * 0.02)
            place(canvas, shimmer, at, 0.12)
        # A single high note per bar, so the loop has something to be counted by.
        place(canvas, tone(["G5", "A5", "C6", "D5"][bar], 1.2, "sine"), at + 0.4, 0.10)
    return canvas


BATTLE_BEATS = 32
BATTLE_BEAT_SECONDS = 0.375  # 160 bpm


def music_battle():
    """The bed under the shooting. Faster, thinner and mostly rhythm: it has to
    sit beneath lasers firing five times a second and explosions on top of that,
    so the melody is a plain arpeggio and the low end is left free for them."""
    total = BATTLE_BEATS * BATTLE_BEAT_SECONDS
    canvas = [0.0] * int(total * SAMPLE_RATE)

    bassline = ["C3", "C3", "G3", "C3", "A3", "A3", "E3", "G3"]
    arpeggio = ["C5", "E5", "G5", "E5", "A4", "C5", "E5", "C5",
                "F4", "A4", "C5", "A4", "G4", "B4", "D5", "G4"]

    for beat in range(BATTLE_BEATS):
        at = beat * BATTLE_BEAT_SECONDS

        # Kick on every other beat: the pulse the scene is paced to.
        if beat % 2 == 0:
            kick = envelope(osc(0.16, 150.0, 45.0, "sine"), attack=0.001, power=3.0)
            place(canvas, kick, at, 0.5)

        # Off-beat hat, quiet, just to keep the grid audible under gunfire.
        if beat % 2 == 1:
            hat = envelope(gain(noise(0.05), 0.5), attack=0.001, power=4.0)
            place(canvas, hat, at, 0.12)

        bass_name = bassline[(beat // 4) % len(bassline)]
        bass = envelope(
            osc(BATTLE_BEAT_SECONDS * 0.9, note_hz(NOTES[bass_name]), shape="saw"),
            attack=0.01,
            power=2.0,
        )
        place(canvas, lowpass(bass, 500.0), at, 0.30)

        lead_name = arpeggio[beat % len(arpeggio)]
        lead = envelope(
            osc(BATTLE_BEAT_SECONDS * 0.8, note_hz(NOTES[lead_name]), shape="square"),
            attack=0.005,
            power=2.4,
        )
        place(canvas, lead, at, 0.13)

    return canvas


# --------------------------------------------------------------------------

SFX = {
    "laser": sfx_laser,
    "alien_explode": sfx_alien_explode,
    "carrier_explode": sfx_carrier_explode,
    "armour_hit": sfx_armour_hit,
    "leak": sfx_leak,
    "quiz_correct": sfx_quiz_correct,
    "quiz_wrong": sfx_quiz_wrong,
    "ui_click": sfx_ui_click,
    "ui_key": sfx_ui_key,
    "countdown": sfx_countdown,
    "launch": sfx_launch,
    "scene_cleared": sfx_scene_cleared,
    "victory": sfx_victory,
    "game_over": sfx_game_over,
}

MUSIC = {
    "menu": music_menu,
    "battle": music_battle,
}


def main():
    for name, build in sorted(SFX.items()):
        write(SFX_DIR, name, build())
    for name, build in sorted(MUSIC.items()):
        # Beds are written well under full scale: they are mixed on their own bus
        # and normalising them to the same peak as an explosion would leave the
        # music competing with the game.
        write(MUSIC_DIR, name, build(), peak=0.55)


if __name__ == "__main__":
    main()
