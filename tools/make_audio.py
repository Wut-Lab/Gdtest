#!/usr/bin/env python3
"""Generate Square Hop's music and sound effects (needs numpy and ffmpeg).

    python3 tools/make_audio.py

Writes audio/music.ogg (a soft, happy loop, exactly 3:00 at 96 BPM) and audio/jump.wav,
audio/land.wav, audio/hurt.wav, audio/buy.wav, audio/ding.wav, the boss sounds (boss_hit, boss_charge,
boss_crash, boss_defeat) and the boss track music_boss.ogg, plus the Mossy Cave tracks
(music_moss, music_moss_boss, both with crickets) and Old Mossback's moss_* sounds, and
Cavern Lake's music_lake, music_lake_boss and its sounds (chomp, splash, bubbles, harpoon_fire,
lake_boss_hit, lake_boss_defeat), and the Ember Forge's music_forge, music_forge_boss and
its sounds (flame_jet, sizzle, anvil_clang, sparks, forge_boss_hit, forge_boss_defeat). Everything is synthesized here, so edit this file and rerun
it to change the sound, then run `godot --headless --path . --import`.
"""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio")
SR = 32000
rng = np.random.default_rng(7)

# ---------- Instruments ----------

def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env_adsr(n, a, d, s, r, sustain_len):
    """Attack/decay/sustain then release, all in seconds; returns n samples."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = t > sustain_len
    e[rel] *= np.exp(-(t[rel] - sustain_len) / max(r, 1e-4))
    return e


def pluck(f, dur):
    """Music-box / marimba: bright attack, quick fade."""
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.08)
    return w * np.minimum(t / 0.004, 1) * np.exp(-t / 0.32)


def bell(f, dur):
    """Soft bell for melodies in the quiet parts."""
    n = int((dur + 1.0) * SR)
    t = np.arange(n) / SR
    w = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / 0.3)
         + 0.12 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / 0.15))
    return w * np.minimum(t / 0.005, 1) * np.exp(-t / 0.6)


def lead(f, dur):
    """Soft flute-like lead with a little vibrato on long notes."""
    n = int((dur + 0.15) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    w = np.sin(ph) + 0.12 * np.sin(3 * ph) + 0.05 * np.sin(2 * ph)
    return w * env_adsr(n, 0.03, 0.25, 0.75, 0.08, dur)


def pad(f, dur):
    """Warm, slow chord pad: two slightly detuned sines."""
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * f * 0.998 * t) + np.sin(2 * np.pi * f * 1.002 * t)
    return w * 0.5 * env_adsr(n, 0.45, 1.0, 0.8, 0.4, dur)


def bass(f, dur):
    n = int((dur + 0.1) * SR)
    t = np.arange(n) / SR
    w = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(6 * np.pi * f * t)
    return w * env_adsr(n, 0.008, 0.2, 0.6, 0.05, dur)


def kick(_f=0, _d=0):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 50 + 70 * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09)


def noise_hit(decay, bright=True, n_sec=0.15):
    n = int(n_sec * SR)
    x = rng.standard_normal(n)
    if bright:
        x = np.diff(x, prepend=0)          # crude high-pass
    else:
        x = np.convolve(x, np.ones(6) / 6, "same")
    return x * np.exp(-np.arange(n) / SR / decay)


def hat(_f=0, _d=0):
    return noise_hit(0.025) * 0.5


def shaker(_f=0, _d=0):
    return noise_hit(0.04, n_sec=0.1) * 0.25


def clap(_f=0, _d=0):
    return noise_hit(0.06, bright=False, n_sec=0.2)


# ---------- The tune ----------

BPM = 96
BEAT = 60 / BPM
SLOT = BEAT / 2                 # eighth note
BAR = BEAT * 4
SCALE = [0, 2, 4, 5, 7, 9, 11]  # C major


def deg(d, base=60):
    """Scale degree (0 = C4, 7 = C5) to a MIDI note."""
    return base + 12 * (d // 7) + SCALE[d % 7]


CHORDS = {   # root MIDI note (octave 3) and quality
    "C": (48, "maj"), "G": (43, "maj"), "Am": (45, "min"), "F": (41, "maj"),
    "Em": (40, "min"), "Dm": (38, "min"),
}
TRIAD = {"maj": [0, 4, 7], "min": [0, 3, 7]}

PROG = {
    "A": ["C", "G", "Am", "F", "C", "G", "F", "G"],
    "B": ["F", "G", "Em", "Am", "F", "G", "C", "C"],
    "C": ["Dm", "G", "C", "Am", "Dm", "Em", "F", "G"],
}
# Melodies: per bar, (slot, length in slots, scale degree).
MEL = {
    "A": [[(0, 2, 2), (2, 2, 4), (4, 3, 7)],
          [(0, 2, 6), (2, 2, 8), (4, 2, 6), (6, 2, 4)],
          [(0, 3, 5), (3, 1, 7), (4, 4, 9)],
          [(0, 2, 8), (2, 2, 7), (4, 4, 5)],
          [(0, 2, 2), (2, 2, 4), (4, 2, 7), (6, 2, 9)],
          [(0, 3, 8), (3, 1, 6), (4, 4, 4)],
          [(0, 2, 5), (2, 2, 7), (4, 2, 10), (6, 2, 9)],
          [(0, 6, 8)]],
    "B": [[(0, 1, 7), (1, 1, 5), (2, 2, 7), (4, 4, 10)],
          [(0, 2, 8), (2, 2, 6), (4, 2, 4), (6, 2, 6)],
          [(0, 3, 9), (3, 1, 8), (4, 4, 6)],
          [(0, 2, 7), (2, 2, 5), (4, 4, 2)],
          [(0, 2, 3), (2, 2, 5), (4, 2, 7), (6, 2, 8)],
          [(0, 2, 8), (2, 2, 6), (4, 2, 8), (6, 2, 11)],
          [(0, 4, 9), (4, 2, 8), (6, 2, 7)],
          [(0, 6, 7)]],
    "C": [[(0, 4, 3), (4, 4, 5)],
          [(0, 4, 6), (4, 4, 8)],
          [(0, 6, 9), (6, 2, 8)],
          [(0, 8, 7)],
          [(0, 4, 8), (4, 4, 10)],
          [(0, 4, 9), (4, 4, 11)],
          [(0, 4, 12), (4, 2, 11), (6, 2, 10)],
          [(0, 4, 8), (4, 4, 6)]],
}
# Nine 8-bar sections = 72 bars = exactly 3:00. The last one ends on G so it leads back to C.
SECTIONS = [
    dict(part="A", mel=None, drums="light"),
    dict(part="A", mel="lead", drums="full"),
    dict(part="B", mel="lead", drums="full"),
    dict(part="A", mel="lead", bell=True, drums="full"),
    dict(part="C", mel="bell", drums="soft"),
    dict(part="B", mel="lead", drums="full"),
    dict(part="A", mel="lead", bell=True, drums="full"),
    dict(part="C", mel="bell", drums=None),
    dict(part="A", mel="outro", drums="light"),
]
ARP = [0, 1, 2, 3, 2, 1, 2, 1]   # chord-tone index per eighth note


def render_music():
    total = int(len(SECTIONS) * 8 * BAR * SR)
    buf = np.zeros(total + 4 * SR)

    def put(sound, t, gain):
        i = int(t * SR)
        s = sound * gain
        buf[i:i + len(s)] += s[: len(buf) - i]

    bar_i = 0
    for sec in SECTIONS:
        for b in range(8):
            t0 = bar_i * BAR
            root, q = CHORDS[PROG[sec["part"]][b]]
            tones = [root + 12 + x for x in TRIAD[q]] + [root + 24]
            # Pad: the chord, held for the bar.
            for m in tones[:3]:
                put(pad(midi_hz(m + 12), BAR * 0.95), t0, 0.05)
            # Arpeggio on the music box.
            for s, k in enumerate(ARP):
                accent = 1.0 if s % 2 == 0 else 0.75
                put(pluck(midi_hz(tones[k] + 12), SLOT), t0 + s * SLOT, 0.07 * accent)
            # Bouncy bass: root, root, fifth, octave.
            for s, ln, iv in [(0, 2, 0), (3, 1, 0), (4, 2, 7), (6, 2, 12)]:
                put(bass(midi_hz(root - 12 + iv), ln * SLOT * 0.9), t0 + s * SLOT, 0.16)
            # Melody.
            notes = MEL[sec["part"]][b]
            if sec["mel"] == "outro":
                notes = notes if b < 4 else notes[:1]
            for s, ln, d in notes if sec["mel"] else []:
                f = midi_hz(deg(d))
                if sec["mel"] in ("lead", "outro"):
                    put(lead(f, ln * SLOT * 0.92), t0 + s * SLOT, 0.12)
                else:
                    put(bell(f * 2, ln * SLOT), t0 + s * SLOT, 0.08)
                if sec.get("bell"):
                    put(bell(f * 2, ln * SLOT), t0 + s * SLOT, 0.035)
            # Drums, kept soft.
            dr = sec["drums"]
            if dr:
                for s in range(8):
                    t = t0 + s * SLOT
                    if s in (0, 4) and (dr != "light" or b >= 4):
                        put(kick(), t, 0.22)
                    if s % 2 == 1:
                        put(hat(), t, 0.05)
                    if dr == "full" and s in (2, 6):
                        put(clap(), t, 0.05)
                    if dr in ("full", "soft"):
                        put(shaker(), t + SLOT / 2, 0.04)
            bar_i += 1

    # Seamless loop: fold the ringing tail past the end back onto the start.
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.7 / np.max(np.abs(buf))
    return buf


# ---------- Level tracks: busier, 128 BPM, 48 bars = exactly 90 s ----------

LEVEL_SECTIONS = {
    # Practice and dungeon (random) levels.
    "level": dict(shift=0, prog=["A", "A", "B", "C", "B", "A"],
                  mel=[None, "lead", "lead", "bell", "lead", "lead"]),
    # Saved levels in the Replay Room: same tune, new key, different order and colours.
    "saved": dict(shift=2, prog=["C", "B", "A", "C", "A", "B"],
                  mel=[None, "bell", "lead", "lead", "bell", "lead"]),
}


def render_level_music(variant):
    cfg = LEVEL_SECTIONS[variant]
    bpm = 128
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    sh = cfg["shift"]
    total = int(len(cfg["prog"]) * 8 * bar * SR)
    buf = np.zeros(total + 4 * SR)

    def put(sound, t, gain):
        i = int(t * SR)
        x = sound * gain
        buf[i:i + len(x)] += x[: len(buf) - i]

    bar_i = 0
    for si, part in enumerate(cfg["prog"]):
        mel = cfg["mel"][si]
        for b in range(8):
            t0 = bar_i * bar
            root, q = CHORDS[PROG[part][b]]
            root += sh
            tones = [root + 12 + x for x in TRIAD[q]] + [root + 24]
            for m in tones[:3]:
                put(pad(midi_hz(m + 12), bar * 0.95), t0, 0.04)
            # Sixteenth-note arpeggio for drive.
            for k in range(16):
                idx = [0, 1, 2, 3][k % 4] if variant == "level" else [3, 2, 1, 0][k % 4]
                put(pluck(midi_hz(tones[idx] + 12), slot / 2), t0 + k * slot / 2,
                    0.055 * (1.0 if k % 2 == 0 else 0.7))
            # Driving eighth-note bass.
            for k in range(8):
                iv = [0, 0, 12, 0, 7, 0, 12, 7][k]
                put(bass(midi_hz(root - 12 + iv), slot * 0.8), t0 + k * slot, 0.15)
            for st, ln, d in MEL[part][b] if mel else []:
                f = midi_hz(deg(d) + sh)
                if mel == "lead":
                    put(lead(f, ln * slot * 0.9), t0 + st * slot, 0.12)
                    put(bell(f * 2, ln * slot), t0 + st * slot, 0.03)
                else:
                    put(bell(f * 2, ln * slot), t0 + st * slot, 0.09)
            # Drums: four-on-the-floor, claps on 2 and 4, eighth hats, sixteenth shakers.
            intro = si == 0 and b < 4
            for k in range(8):
                t = t0 + k * slot
                if k % 2 == 0 and not intro:
                    put(kick(), t, 0.24)
                if k in (2, 6):
                    put(clap(), t, 0.07)
                put(hat(), t + (slot / 2 if variant == "saved" else 0), 0.045)
                put(shaker(), t + slot / 2, 0.035)
            if b == 7:   # little fill into the next section
                for k in range(4):
                    put(clap(), t0 + (4 + k) * slot + slot / 2, 0.04)
            bar_i += 1

    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.7 / np.max(np.abs(buf))
    return buf


# ---------- Sound effects ----------

def sweep(f0, f1, dur, shape="tri"):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "tri":
        return np.sin(ph) + 0.2 * np.sin(3 * ph) + 0.08 * np.sin(5 * ph)
    return np.sign(np.sin(ph)) * 0.5 + np.sin(ph) * 0.5


def sfx_jump():
    n_dur = 0.14
    w = sweep(330, 720, n_dur)
    t = np.arange(len(w)) / SR
    return w * np.minimum(t / 0.003, 1) * np.exp(-t / 0.07) * 0.6


def sfx_land():
    w = sweep(150, 60, 0.12)
    t = np.arange(len(w)) / SR
    thump = w * np.exp(-t / 0.035)
    dust = noise_hit(0.025, bright=False, n_sec=0.12) * 0.25
    return (thump + dust) * 0.7


def sfx_hurt():
    w = sweep(620, 170, 0.32, shape="square")
    t = np.arange(len(w)) / SR
    w *= 0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 28 * t))    # a little wobble
    w *= np.minimum(t / 0.004, 1) * np.exp(-t / 0.14)
    crunch = noise_hit(0.04, n_sec=0.32) * 0.3
    return (w + crunch) * 0.45


def sfx_buy():
    """Shop purchase: a two-note bell "cha-ching" over a little coin shimmer."""
    out = np.zeros(int(0.7 * SR))
    for start, f in ((0.0, midi_hz(84)), (0.09, midi_hz(91))):
        w = bell(f, 0.2)[: len(out) - int(start * SR)]
        out[int(start * SR): int(start * SR) + len(w)] += w * 0.5
    shimmer = noise_hit(0.05, n_sec=0.15) * 0.15
    out[: len(shimmer)] += shimmer
    return out * 0.36


def sfx_ding():
    """Checkpoint: one soft, warm bell note (G4) with a faint octave above."""
    w = bell(midi_hz(67), 0.3)
    t = np.arange(len(w)) / SR
    w += 0.2 * np.sin(2 * np.pi * midi_hz(79) * t) * np.exp(-t / 0.12)
    return w * 0.3


def sfx_chest_open():
    """Chest opening: a low wooden creak sliding down, then a soft thunk as the lid falls back."""
    out = np.zeros(int(0.6 * SR))
    creak = sweep(180, 110, 0.3)
    t = np.arange(len(creak)) / SR
    creak = creak * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t)) * np.minimum(t / 0.02, 1) * np.exp(-t / 0.2)
    out[: len(creak)] += creak * 0.35
    thunk = sweep(120, 50, 0.15)
    t = np.arange(len(thunk)) / SR
    st = int(0.28 * SR)
    out[st: st + len(thunk)] += thunk * np.exp(-t / 0.05) * 0.5
    return out * 0.6


def sfx_bounce():
    """Rubber bounce: a low, soft boing that bends up and fades."""
    b = sweep(70, 140, 0.22)
    t = np.arange(len(b)) / SR
    return b * np.minimum(t / 0.008, 1) * np.exp(-t / 0.07) * 0.4


def sfx_victory():
    """Level clear: a quick, bright rising arpeggio (C E G C) ending on a held bell."""
    out = np.zeros(int(1.4 * SR))
    for i, n in enumerate((72, 76, 79, 84)):
        st = int(i * 0.09 * SR)
        w = bell(midi_hz(n), 0.25 if i < 3 else 0.5)[: len(out) - st]
        out[st: st + len(w)] += w * (0.4 if i < 3 else 0.55)
    return out * 0.45


def sfx_boss_victory():
    """Boss level clear: a low boom, then a slower, fuller fanfare (G C E G, then a C chord)."""
    out = np.zeros(int(2.4 * SR))
    boom = sweep(110, 45, 0.5)
    t = np.arange(len(boom)) / SR
    out[: len(boom)] += boom * np.exp(-t / 0.18) * 0.6
    for i, n in enumerate((67, 72, 76, 79)):
        st = int((0.1 + i * 0.14) * SR)
        w = bell(midi_hz(n), 0.3)[: len(out) - st]
        out[st: st + len(w)] += w * 0.4
    st = int(0.7 * SR)
    for n in (60, 72, 76, 79, 84):
        w = bell(midi_hz(n), 0.9)[: len(out) - st]
        out[st: st + len(w)] += w * 0.25
    return out / max(1e-9, np.abs(out).max()) * 0.5


# ---------- Boss: sounds and a tense, driving loop ----------

def sfx_boss_hit():
    """Landing on the boss: a heavy, low thump with a squashy crunch."""
    w = sweep(220, 55, 0.25)
    t = np.arange(len(w)) / SR
    thump = w * np.minimum(t / 0.002, 1) * np.exp(-t / 0.08)
    crunch = noise_hit(0.05, bright=False, n_sec=0.25) * 0.5
    ping = sweep(900, 500, 0.12, shape="square")
    ping *= np.exp(-np.arange(len(ping)) / SR / 0.04) * 0.25
    out = thump + crunch
    out[: len(ping)] += ping
    return out * 0.8


def sfx_boss_charge():
    """The 1.5 s glow before his dash: a buzzing tone rising and speeding up."""
    dur = 1.5
    w = sweep(110, 440, dur, shape="square")
    t = np.arange(len(w)) / SR
    trem = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * (6 + 18 * t / dur) * t))
    env = np.minimum(t / 0.05, 1) * np.minimum((dur - t) / 0.03, 1)
    return w * trem * env * (0.25 + 0.35 * t / dur)


def sfx_boss_crash():
    """Slamming into the wall: a deep boom and a rumble."""
    w = sweep(120, 35, 0.5)
    t = np.arange(len(w)) / SR
    boom = w * np.exp(-t / 0.15)
    rumble = noise_hit(0.18, bright=False, n_sec=0.5) * 0.6
    return (boom + rumble) * 0.8


def sfx_boss_defeat():
    """Beaten: a falling crash, then a bright three-note fanfare."""
    out = np.zeros(int(1.4 * SR))
    w = sweep(400, 60, 0.6, shape="square")
    t = np.arange(len(w)) / SR
    w *= np.exp(-t / 0.25) * 0.4
    out[: len(w)] += w + noise_hit(0.2, n_sec=0.6) * 0.35
    for start, m in ((0.45, 72), (0.6, 76), (0.75, 79)):
        b = bell(midi_hz(m + 12), 0.5)
        i = int(start * SR)
        out[i:i + len(b)] += b[: len(out) - i] * 0.45
    return out * 0.8


def render_boss_music():
    """140 BPM in A minor, 16 bars (about 27 s) that loop: pounding kick, driving bass and
    short stabs."""
    bpm = 140
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    prog = [(57, "min"), (53, "maj"), (55, "maj"), (52, "maj")] * 4   # Am F G E
    total = int(len(prog) * bar * SR)
    buf = np.zeros(total + 4 * SR)

    def put(sound, t, gain):
        i = int(t * SR)
        x = sound * gain
        buf[i:i + len(x)] += x[: len(buf) - i]

    riff = [0, 0, 12, 0, 0, 10, 12, 7]
    for bi, (root, q) in enumerate(prog):
        t0 = bi * bar
        tones = [root + x for x in TRIAD[q]]
        for m in tones:
            put(pad(midi_hz(m), bar * 0.95), t0, 0.035)
        for k in range(8):
            put(bass(midi_hz(root - 12 + riff[k]), slot * 0.7), t0 + k * slot, 0.2)
        for k in (0, 3, 6):   # syncopated stabs
            for m in tones:
                put(pluck(midi_hz(m + 12), slot * 0.6), t0 + k * slot, 0.06)
        if bi >= 4:
            for k in range(16):   # a fast arpeggio once it gets going
                put(pluck(midi_hz(tones[k % 3] + 24), slot / 2), t0 + k * slot / 2, 0.03)
        if bi % 4 == 3:
            put(lead(midi_hz(root + 24 + 3), bar * 0.45), t0 + bar / 2, 0.08)
        for k in range(8):
            t = t0 + k * slot
            if k % 2 == 0:
                put(kick(), t, 0.3)
            if k in (2, 6):
                put(clap(), t, 0.09)
            put(hat(), t + slot / 2, 0.05)
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.7 / np.max(np.abs(buf))
    return buf


# ---------- Mossy Cave: crickets, a cave track, a boss track and Old Mossback's sounds ----------

def cricket_layer(total, seed, voices=3, gain=1.0):
    """A field of crickets: each one sings short pulsed chirps at its own pitch and pace,
    with quiet gaps so it never turns into a steady whine."""
    r = np.random.default_rng(seed)
    out = np.zeros(total)
    for v in range(voices):
        f = r.uniform(3900, 5200)          # carrier pitch
        rate = r.uniform(26, 34)           # pulses per second inside a chirp
        pulses = int(r.integers(2, 5))     # pulses per chirp
        gap = r.uniform(0.35, 0.7)         # time between chirps
        level = r.uniform(0.5, 1.0)
        t = r.uniform(0, 1.5)
        n_chirp = int(pulses / rate * SR)
        tt = np.arange(n_chirp) / SR
        env = np.clip(np.sin(np.pi * rate * tt), 0, 1) ** 2
        chirp = np.sin(2 * np.pi * f * tt) * env + 0.25 * np.sin(4 * np.pi * f * tt) * env
        while t < total / SR:
            if r.random() < 0.12:                    # a little rest now and then
                t += r.uniform(1.5, 4.0)
                continue
            i = int(t * SR)
            x = chirp * level * r.uniform(0.75, 1.0)
            out[i:i + len(x)] += x[: total - i]
            t += gap * r.uniform(0.9, 1.1)
    return out * gain


def echo(x, delay, fb, mix):
    """Simple cave echo: repeats that fade."""
    d = int(delay * SR)
    y = x.copy()
    for k in range(1, 6):
        g = mix * fb ** (k - 1)
        if d * k >= len(x):
            break
        y[d * k:] += x[: len(x) - d * k] * g
    return y


def drip(f, _d=0):
    """A water drop in the cave: a quick pitch-rising blip."""
    w = sweep(f, f * 1.9, 0.07)
    t = np.arange(len(w)) / SR
    return w * np.minimum(t / 0.002, 1) * np.exp(-t / 0.025)


def render_moss_music():
    """Mossy Cave levels: 104 BPM in D dorian, 32 bars (about 74 s). Soft and echoey: deep pad,
    plodding bass, a mallet line with cave echo, water drips, light woody percussion, crickets."""
    bpm = 104
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    prog = [(50, "min"), (55, "maj"), (50, "min"), (48, "maj"),
            (53, "maj"), (55, "maj"), (57, "min"), (50, "min")] * 4   # Dm G Dm C F G Am Dm
    total = int(len(prog) * bar * SR)
    buf = np.zeros(total + 4 * SR)
    mel_buf = np.zeros_like(buf)

    def put(sound, t, gain, into=None):
        b = buf if into is None else into
        i = int(t * SR)
        x = sound * gain
        b[i:i + len(x)] += x[: len(b) - i]

    r = np.random.default_rng(31)
    # D dorian, in scale steps from D4.
    dorian = [0, 2, 3, 5, 7, 9, 10]
    def dd(step):
        return 62 + 12 * (step // 7) + dorian[step % 7]
    phrases = [
        [(0, 3, 4), (3, 1, 3), (4, 4, 2)],
        [(0, 2, 1), (2, 2, 2), (4, 4, 0)],
        [(0, 3, 4), (3, 1, 5), (4, 2, 4), (6, 2, 2)],
        [(0, 6, 0)],
    ]
    for bi, (root, q) in enumerate(prog):
        t0 = bi * bar
        sec = bi // 8
        tones = [root + x for x in TRIAD[q]]
        for m in tones:
            put(pad(midi_hz(m), bar * 0.98), t0, 0.05)
        put(pad(midi_hz(root - 12), bar * 0.98), t0, 0.04)
        # Plodding bass on beats 1 and 3, a pickup on the "and" of 4.
        for k, iv in ((0, 0), (4, 7), (7, 12)):
            put(bass(midi_hz(root - 12 + iv), slot * 1.6), t0 + k * slot, 0.16 if k != 7 else 0.08)
        if sec >= 1:   # mallet line, through the echo
            for st, ln, d in phrases[bi % 4]:
                put(pluck(midi_hz(dd(d)), ln * slot), t0 + st * slot, 0.11, mel_buf)
        if sec == 2:   # third section: a soft bell counter-line an octave up
            for k in (2, 6):
                put(bell(midi_hz(tones[(bi + k) % 3] + 24), slot), t0 + k * slot, 0.035, mel_buf)
        # Woody percussion: a soft kick on 1, a click on the off-beats.
        if sec >= 1:
            put(kick(), t0, 0.16)
            put(kick(), t0 + 5 * slot, 0.09)
        for k in (1, 3, 5, 7):
            put(noise_hit(0.012, n_sec=0.05), t0 + k * slot, 0.05)
        # Water drips at random spots.
        for _ in range(int(r.integers(0, 3))):
            put(drip(r.uniform(900, 1500)), t0 + r.uniform(0, bar), 0.12, mel_buf)
    buf += echo(mel_buf, slot * 1.5, 0.45, 0.5)
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.62 / np.max(np.abs(buf))
    buf += cricket_layer(total, 101, voices=4, gain=0.035)
    return buf


def render_moss_boss_music():
    """Old Mossback: 132 BPM in D minor, 16 bars (about 29 s) that loop. Heavy, stomping and
    woody, with log-drum toms, a growling bass and crickets that never stop."""
    bpm = 132
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    prog = [(50, "min"), (46, "maj"), (48, "maj"), (45, "maj")] * 4   # Dm Bb C A
    total = int(len(prog) * bar * SR)
    buf = np.zeros(total + 4 * SR)
    stab_buf = np.zeros_like(buf)

    def put(sound, t, gain, into=None):
        b = buf if into is None else into
        i = int(t * SR)
        x = sound * gain
        b[i:i + len(x)] += x[: len(b) - i]

    def tom(f):
        w = sweep(f, f * 0.6, 0.3)
        t = np.arange(len(w)) / SR
        return w * np.exp(-t / 0.09)

    riff = [0, 0, 0, 3, 0, 0, 5, 3]
    for bi, (root, q) in enumerate(prog):
        t0 = bi * bar
        tones = [root + x for x in TRIAD[q]]
        for m in tones:
            put(pad(midi_hz(m), bar * 0.95), t0, 0.04)
        for k in range(8):
            f = midi_hz(root - 24 + riff[k])
            put(bass(f, slot * 0.7), t0 + k * slot, 0.22)
            put(bass(f * 2, slot * 0.5), t0 + k * slot, 0.05)
        for k in (0, 3, 6):
            for m in tones:
                put(pluck(midi_hz(m + 12), slot * 0.5), t0 + k * slot, 0.05, stab_buf)
        if bi >= 4:   # log-drum toms
            for k, f in ((1, 160), (3, 130), (5, 160), (6, 110), (7, 95)):
                put(tom(f), t0 + k * slot, 0.12)
        if bi >= 8 and bi % 2 == 1:
            put(lead(midi_hz(root + 24 + 7), bar * 0.4), t0 + bar / 2, 0.07)
        for k in range(8):
            t = t0 + k * slot
            if k in (0, 3, 4):
                put(kick(), t, 0.32)
            if k in (2, 6):
                put(clap(), t, 0.08)
            put(noise_hit(0.015, n_sec=0.05), t + slot / 2, 0.06)
    buf += echo(stab_buf, slot * 0.75, 0.35, 0.5)
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.66 / np.max(np.abs(buf))
    buf += cricket_layer(total, 202, voices=3, gain=0.03)
    return buf


def rustle(dur, decay):
    """Leaves and moss shaking."""
    r = np.random.default_rng(int(dur * 1000 + decay * 1e4))
    n = int(dur * SR)
    x = np.diff(r.standard_normal(n), prepend=0)
    t = np.arange(n) / SR
    grain = 0.5 + 0.5 * (r.random(n) < 0.08)
    return x * grain * np.exp(-t / decay)


def wood_knock(f, decay=0.06, dur=0.35):
    """A struck piece of wood: inharmonic modes like a log drum or wood block, fast decay,
    with a tiny click on the attack."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, g, dk in ((1.0, 1.0, 1.0), (2.76, 0.5, 0.55), (5.40, 0.25, 0.3), (8.93, 0.1, 0.2)):
        out += np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (decay * dk)) * g
    click = np.zeros(n)
    m = int(0.004 * SR)
    click[:m] = np.linspace(1, 0, m) * np.sign(np.sin(np.arange(m) * 1.7))
    return (out + click * 0.4) * np.minimum(t / 0.0015, 1)


def wood_creak(f0, f1, dur, gain=0.2):
    """Bending wood: a slow, raspy, wavering tone."""
    w = sweep(f0, f1, dur, shape="square")
    t = np.arange(len(w)) / SR
    rasp = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (34 + 8 * np.sin(2 * np.pi * 3 * t)) * t))
    return w * rasp * np.minimum(t / 0.03, 1) * np.exp(-t / (dur * 0.5)) * gain


def sfx_moss_hit():
    """Stomping Old Mossback: a hollow wooden knock, a bark crunch and a puff of leaves."""
    out = np.zeros(int(0.45 * SR))
    for f, g in ((190, 1.0), (410, 0.45), (690, 0.2)):   # hollow log knock
        t = np.arange(int(0.3 * SR)) / SR
        out[: len(t)] += np.sin(2 * np.pi * f * t) * np.exp(-t / (0.09 / (1 + f / 600))) * g
    out[: int(0.2 * SR)] += noise_hit(0.04, bright=False, n_sec=0.2) * 0.5
    out += rustle(0.45, 0.12) * 0.12
    out[: int(0.35 * SR)] += wood_knock(150, 0.08) * 0.8 + wood_knock(240, 0.05) * 0.4
    k = wood_creak(160, 120, 0.3, 0.12)
    out[int(0.04 * SR): int(0.04 * SR) + len(k)] += k
    return out * 0.7


def sfx_moss_land():
    """His heavy landing: a soft, deep thud with mossy rustling."""
    w = sweep(110, 45, 0.35)
    t = np.arange(len(w)) / SR
    out = w * np.minimum(t / 0.003, 1) * np.exp(-t / 0.1)
    out += noise_hit(0.08, bright=False, n_sec=0.35) * 0.45
    out += rustle(0.35, 0.1) * 0.15
    out[: int(0.35 * SR)] += wood_knock(95, 0.1) * 0.7
    out[int(0.03 * SR): int(0.03 * SR) + int(0.3 * SR)] += wood_knock(180, 0.04, 0.3) * 0.3
    return out * 0.8


def sfx_moss_throw():
    """Throwing a square: a quick airy whoosh."""
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = rng.standard_normal(n)
    out = np.zeros(n)
    # Sweep a resonant band upward by mixing smoothed noise with its derivative.
    for k in range(4):
        sm = np.convolve(x, np.ones(12 - 3 * k) / (12 - 3 * k), "same")
        seg = (t >= k * 0.06) & (t < (k + 1) * 0.06 + 0.08)
        out[seg] += sm[seg]
    env = np.sin(np.pi * np.clip(t / 0.3, 0, 1)) ** 1.5
    out[: int(0.25 * SR)] += wood_creak(220, 300, 0.25, 0.1)
    out[: int(0.35 * SR)][: int(0.3 * SR)] += wood_knock(320, 0.03)[: int(0.3 * SR)] * 0.35
    return out * env * 0.5


def sfx_moss_crack():
    """Bark splitting (his blocks crumble, or a hard smash): a sharp crack and creak."""
    out = np.zeros(int(0.6 * SR))
    for st in (0.0, 0.035, 0.09):
        c = noise_hit(0.012, n_sec=0.08) * (1.0 if st == 0 else 0.6)
        i = int(st * SR)
        out[i:i + len(c)] += c
    creak = sweep(140, 95, 0.45, shape="square")
    t = np.arange(len(creak)) / SR
    creak *= (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 38 * t))) * np.exp(-t / 0.18) * 0.2
    i = int(0.05 * SR)
    out[i:i + len(creak)] += creak
    out += noise_hit(0.15, bright=False, n_sec=0.6) * 0.25
    for st, f in ((0.0, 420), (0.035, 610), (0.09, 330)):
        k = wood_knock(f, 0.025, 0.2)
        i = int(st * SR)
        out[i:i + len(k)] += k * 0.45
    return out * 0.75


def sfx_moss_defeat():
    """Old Mossback beaten: a long creak, a crumbling fall, then a gentle three-note bell."""
    out = np.zeros(int(1.8 * SR))
    creak = sweep(180, 70, 0.7, shape="square")
    t = np.arange(len(creak)) / SR
    creak *= (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 30 * t))) * np.exp(-t / 0.35) * 0.25
    out[: len(creak)] += creak
    i = int(0.25 * SR)
    fall = noise_hit(0.3, bright=False, n_sec=0.8) * 0.5 + rustle(0.8, 0.3) * 0.2
    out[i:i + len(fall)] += fall
    for start, m in ((0.75, 74), (0.92, 77), (1.09, 81)):   # D F A
        b = bell(midi_hz(m + 12), 0.5)
        i = int(start * SR)
        out[i:i + len(b)] += b[: len(out) - i] * 0.42
    k = wood_creak(200, 60, 1.0, 0.22)
    out[: len(k)] += k
    for st, f in ((0.3, 140), (0.42, 110), (0.5, 175), (0.62, 90)):   # logs tumbling
        w = wood_knock(f, 0.07)
        i = int(st * SR)
        out[i:i + len(w)] += w * 0.5
    return out * 0.8


# ---------- Cavern Lake: a watery cave track, a shanty boss track and the lake's sounds ----------

def harp(f, dur):
    """Plucked harp: soft attack, a little shimmer, long fade."""
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    w = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.25)
         + 0.1 * np.sin(6 * np.pi * f * t) * np.exp(-t / 0.12))
    return w * np.minimum(t / 0.006, 1) * np.exp(-t / 0.75)


def squeeze(f, dur):
    """Accordion-ish lead: two detuned reedy tones with a wobble."""
    n = int((dur + 0.12) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for det in (0.996, 1.004):
        ph = 2 * np.pi * f * det * t
        out += np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph) + 0.15 * np.sin(5 * ph)
    out *= 1 + 0.12 * np.sin(2 * np.pi * 6.0 * t)
    return out * 0.5 * env_adsr(n, 0.02, 0.15, 0.85, 0.06, dur)


def blip_bubble(f, rng_):
    """One bubble: a short rising sine blip."""
    d = rng_.uniform(0.04, 0.08)
    w = sweep(f, f * rng_.uniform(1.6, 2.4), d)
    t = np.arange(len(w)) / SR
    return w * np.sin(np.pi * t / d) ** 2


def render_lake_music():
    """Cavern Lake levels: 108 BPM in E minor, 32 bars (about 71 s). Harp arpeggios through a
    long cave echo, a deep pad, slow bass, brushed shaker, a bell tune, drips and bubbles."""
    bpm = 108
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    prog = [(52, "min"), (48, "maj"), (55, "maj"), (50, "maj"),
            (52, "min"), (45, "min"), (47, "maj"), (52, "min")] * 4   # Em C G D Em Am B Em
    total = int(len(prog) * bar * SR)
    buf = np.zeros(total + 4 * SR)
    wet = np.zeros_like(buf)
    r = np.random.default_rng(41)

    def put(sound, t, gain, into=None):
        b = buf if into is None else into
        i = int(t * SR)
        x = sound * gain
        b[i:i + len(x)] += x[: len(b) - i]

    tune = [[(0, 3, 7), (3, 1, 6), (4, 4, 4)], [(0, 2, 2), (2, 2, 4), (4, 4, 6)],
            [(0, 3, 7), (3, 1, 9), (4, 2, 7), (6, 2, 6)], [(0, 6, 4)]]
    minor = [0, 2, 3, 5, 7, 8, 10]

    def em(step):
        return 64 + 12 * (step // 7) + minor[step % 7]

    for bi, (root, q) in enumerate(prog):
        t0 = bi * bar
        sec = bi // 8
        tones = [root + x for x in TRIAD[q]]
        for m in tones:
            put(pad(midi_hz(m), bar * 0.98), t0, 0.045)
        put(pad(midi_hz(root - 12), bar * 0.98), t0, 0.04)
        put(bass(midi_hz(root - 12), slot * 3), t0, 0.15)
        put(bass(midi_hz(root - 12 + 7), slot * 2), t0 + 4 * slot, 0.1)
        arp = [0, 1, 2, 1, 2, 0, 1, 2]   # rippling harp, an octave up
        for k in range(8):
            put(harp(midi_hz(tones[arp[k]] + 12), slot), t0 + k * slot, 0.055, wet)
        if sec >= 1:
            for st, ln, d in tune[bi % 4]:
                put(bell(midi_hz(em(d) + 12), ln * slot), t0 + st * slot, 0.07, wet)
        if sec >= 1:
            for k in range(8):
                put(shaker(), t0 + k * slot + slot / 2, 0.25 if k % 2 else 0.15)
            put(kick(), t0, 0.06)
        for _ in range(int(r.integers(1, 4))):   # drips and little bubble runs
            if r.random() < 0.5:
                put(drip(r.uniform(1000, 1600)), t0 + r.uniform(0, bar), 0.1, wet)
            else:
                tb = t0 + r.uniform(0, bar - 0.4)
                for j in range(int(r.integers(2, 5))):
                    put(blip_bubble(r.uniform(500, 900), r), tb + j * r.uniform(0.05, 0.1), 0.06)
    buf += echo(wet, slot * 1.5, 0.5, 0.55)
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.66 / np.max(np.abs(buf))
    return buf


def render_lake_boss_music():
    """Crazy Harry: a pirate-shanty battle at 138 BPM in D minor, 16 bars (about 28 s) that
    loop. Oom-pah bass, stomping kick, claps, an accordion-ish lead and twangy harp stabs."""
    bpm = 138
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    prog = [(50, "min"), (50, "min"), (48, "maj"), (45, "maj"),
            (50, "min"), (46, "maj"), (45, "maj"), (50, "min")] * 2   # Dm Dm C A Dm Bb A Dm
    total = int(len(prog) * bar * SR)
    buf = np.zeros(total + 4 * SR)
    r = np.random.default_rng(43)

    def put(sound, t, gain):
        i = int(t * SR)
        x = sound * gain
        buf[i:i + len(x)] += x[: len(buf) - i]

    # A shanty-style tune in D minor (MIDI notes), two bars a line.
    shanty = [[(0, 2, 62), (2, 1, 65), (3, 1, 67), (4, 2, 69), (6, 2, 69)],
              [(0, 2, 70), (2, 2, 69), (4, 2, 67), (6, 2, 65)],
              [(0, 2, 64), (2, 1, 67), (3, 1, 64), (4, 4, 60)],
              [(0, 2, 61), (2, 2, 64), (4, 4, 69)],
              [(0, 2, 62), (2, 1, 65), (3, 1, 67), (4, 2, 69), (6, 2, 72)],
              [(0, 2, 70), (2, 2, 69), (4, 2, 67), (6, 2, 65)],
              [(0, 2, 64), (2, 2, 61), (4, 2, 64), (6, 2, 67)],
              [(0, 6, 62)]]
    for bi, (root, q) in enumerate(prog):
        t0 = bi * bar
        tones = [root + x for x in TRIAD[q]]
        for m in tones:
            put(pad(midi_hz(m), bar * 0.95), t0, 0.03)
        for k in range(8):   # oom-pah: low root on the beat, chord stab on the off-beat
            if k % 2 == 0:
                put(bass(midi_hz(root - 12 + (0 if k % 4 == 0 else 7)), slot * 0.8), t0 + k * slot, 0.22)
            else:
                for m in tones:
                    put(harp(midi_hz(m + 12), slot * 0.4), t0 + k * slot, 0.045)
        for st, ln, m in shanty[bi % 8]:
            put(squeeze(midi_hz(m), ln * slot * 0.92), t0 + st * slot, 0.07 if bi >= 8 else 0.055)
        for k in range(8):
            t = t0 + k * slot
            if k in (0, 4):
                put(kick(), t, 0.34)
            if k in (2, 6):
                put(clap(), t, 0.09)
            put(hat(), t + slot / 2, 0.04)
        if bi % 2 == 1:   # a splash of bubbles every other bar
            tb = t0 + bar - beat
            for j in range(4):
                put(blip_bubble(r.uniform(600, 1000), r), tb + j * 0.06, 0.05)
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.7 / np.max(np.abs(buf))
    return buf


def sfx_chomp():
    """A piranha bite: two quick wet snaps of teeth."""
    r = np.random.default_rng(51)
    out = np.zeros(int(0.3 * SR))
    for st, f in ((0.0, 900), (0.11, 760)):
        n = int(0.07 * SR)
        t = np.arange(n) / SR
        snap = np.diff(r.standard_normal(n), prepend=0) * np.exp(-t / 0.008)
        click = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.015)
        thud = np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.03)
        i = int(st * SR)
        out[i:i + n] += snap * 0.5 + click * 0.6 + thud * 0.5
    return out


def sfx_splash():
    """Something big breaking the surface: a burst of water and a few droplets."""
    r = np.random.default_rng(52)
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    x = r.standard_normal(n)
    body = np.convolve(x, np.ones(4) / 4, "same") * np.exp(-t / 0.14) * np.minimum(t / 0.01, 1)
    low = np.sin(2 * np.pi * 90 * t) * np.exp(-t / 0.08) * 0.6
    out = body + low
    for _ in range(6):   # droplets
        d = drip(r.uniform(1200, 2200))
        i = int(r.uniform(0.12, 0.55) * SR)
        out[i:i + len(d)] += d[: n - i] * 0.25
    return out


def sfx_bubbles():
    """A stream of bubbles rising and popping (Pork, and the boss's dive)."""
    r = np.random.default_rng(53)
    out = np.zeros(int(1.0 * SR))
    t = 0.0
    while t < 0.8:
        b = blip_bubble(r.uniform(450, 1100) * (1 + t * 0.6), r)
        i = int(t * SR)
        out[i:i + len(b)] += b[: len(out) - i] * r.uniform(0.5, 1.0)
        t += r.uniform(0.03, 0.09)
    return out


def sfx_harpoon_fire():
    """The harpoon gun: a tight string twang and a whoosh of the harpoon leaving."""
    r = np.random.default_rng(54)
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = 220 * (1 + 0.6 * np.exp(-t / 0.02))
    ph = 2 * np.pi * np.cumsum(f) / SR
    twang = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)) * np.exp(-t / 0.12)
    clack = wood_knock(520, 0.02, 0.5) * 0.5
    x = r.standard_normal(n)
    whoosh = (x - np.convolve(x, np.ones(8) / 8, "same")) * np.sin(np.pi * np.clip(t / 0.35, 0, 1)) * 0.25
    return twang * 0.6 + clack + whoosh


def sfx_lake_boss_hit():
    """Stomping Crazy Harry: a heavy wet slap, a squelch and an angry gurgle."""
    r = np.random.default_rng(55)
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    slap = np.convolve(r.standard_normal(n), np.ones(3) / 3, "same") * np.exp(-t / 0.03)
    thump = sweep(180, 60, 0.6) * np.exp(-t / 0.1)
    gurgle = np.zeros(n)
    tb = 0.12
    while tb < 0.5:
        b = blip_bubble(r.uniform(200, 380), r)
        i = int(tb * SR)
        gurgle[i:i + len(b)] += b[: n - i]
        tb += r.uniform(0.025, 0.05)
    return slap * 0.6 + thump * 0.9 + gurgle * 0.35


def sfx_lake_boss_defeat():
    """Crazy Harry beaten: a huge splash, bubbles sinking away, then a bright fanfare (E G B)."""
    out = np.zeros(int(2.0 * SR))
    sp = sfx_splash()
    out[: len(sp)] += sp * 1.1
    r = np.random.default_rng(56)
    tb = 0.2
    while tb < 0.9:   # bubbles falling in pitch as he sinks
        b = blip_bubble(900 - (tb - 0.2) * 800, r)
        i = int(tb * SR)
        out[i:i + len(b)] += b * 0.4
        tb += r.uniform(0.03, 0.06)
    for start, m in ((0.95, 76), (1.12, 79), (1.29, 83)):
        b = bell(midi_hz(m + 12), 0.5)
        i = int(start * SR)
        out[i:i + len(b)] += b[: len(out) - i] * 0.45
    return out


# ---------- Ember Forge: an anvil-driven forge track, a boss track and its sounds ----------

def anvil(f, dur=0.6, decay=0.35):
    """A hammer on an anvil: a bright metallic ring (inharmonic partials) with a sharp strike."""
    n = int((dur + decay * 2) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, g, dk in ((1.0, 1.0, 1.0), (2.41, 0.6, 0.7), (3.87, 0.4, 0.5), (5.95, 0.25, 0.35), (8.4, 0.12, 0.2)):
        out += np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (decay * dk)) * g
    strike = np.zeros(n)
    m = int(0.006 * SR)
    strike[:m] = np.random.default_rng(int(f)).standard_normal(m) * np.linspace(1, 0, m)
    return (out + strike) * np.minimum(t / 0.001, 1)


def brass(f, dur):
    """A low, buzzy horn for the forge's heavy chords."""
    n = int((dur + 0.15) * SR)
    t = np.arange(n) / SR
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.35 * np.sin(3 * ph) + 0.2 * np.sin(4 * ph) + 0.1 * np.sin(5 * ph)
    return w * 0.4 * env_adsr(n, 0.06, 0.3, 0.75, 0.1, dur)


def rumble(dur, seed):
    """Low lava rumble: smoothed noise."""
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    x = r.standard_normal(n)
    for _ in range(3):
        x = np.convolve(x, np.ones(40) / 40, "same")
    return x / (np.max(np.abs(x)) + 1e-9)


def render_forge_music():
    """Ember Forge levels: 116 BPM in C phrygian-ish minor, 32 bars (about 66 s). A heavy horn
    pad, a pulsing low bass, anvil clangs as the backbeat, a hammered bell riff and lava rumble."""
    bpm = 116
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    prog = [(48, "min"), (49, "maj"), (48, "min"), (46, "min"),
            (44, "maj"), (49, "maj"), (43, "maj"), (48, "min")] * 4   # Cm Db Cm Bbm Ab Db G Cm
    total = int(len(prog) * bar * SR)
    buf = np.zeros(total + 4 * SR)
    wet = np.zeros_like(buf)

    def put(sound, t, gain, into=None):
        b = buf if into is None else into
        i = int(t * SR)
        x = sound * gain
        b[i:i + len(x)] += x[: len(b) - i]

    riff = [(0, 0), (3, 3), (4, 7), (6, 5)]   # (slot, semitones over the chord root)
    for bi, (root, q) in enumerate(prog):
        t0 = bi * bar
        sec = bi // 8
        tones = [root + x for x in TRIAD[q]]
        for m in tones:
            put(brass(midi_hz(m), bar * 0.95), t0, 0.05)
        for k in range(8):   # pulsing eighth-note bass
            put(bass(midi_hz(root - 12), slot * 0.6), t0 + k * slot, 0.14 if k % 2 == 0 else 0.09)
        put(kick(), t0, 0.3)
        put(kick(), t0 + 4 * slot, 0.24)
        if sec >= 1 or bi >= 4:
            for k in (2, 6):   # the anvil on the backbeat
                put(anvil(1180, 0.3, 0.18), t0 + k * slot, 0.09)
        if sec >= 1:
            for st, iv in riff:
                put(bell(midi_hz(root + 24 + iv), slot), t0 + st * slot, 0.05, wet)
        if sec == 2:
            for k in range(8):
                put(hat(), t0 + k * slot + slot / 2, 0.04)
        if bi % 4 == 3:
            put(anvil(880, 0.4, 0.3), t0 + 7 * slot, 0.08)
    buf += echo(wet, slot * 1.5, 0.35, 0.4)
    buf[:total] += rumble(total / SR, 61) * 0.05
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.68 / np.max(np.abs(buf))
    return buf


def render_forge_boss_music():
    """Anvil Annie: 148 BPM in C minor, 16 bars (about 26 s) that loop. Pounding double kicks,
    anvil hits on every beat, a horn riff and a fast hammered arpeggio."""
    bpm = 148
    beat = 60 / bpm
    slot = beat / 2
    bar = beat * 4
    prog = [(48, "min"), (44, "maj"), (46, "maj"), (43, "maj")] * 4   # Cm Ab Bb G
    total = int(len(prog) * bar * SR)
    buf = np.zeros(total + 4 * SR)

    def put(sound, t, gain):
        i = int(t * SR)
        x = sound * gain
        buf[i:i + len(x)] += x[: len(buf) - i]

    riff = [0, 0, 12, 0, 10, 0, 7, 3]
    for bi, (root, q) in enumerate(prog):
        t0 = bi * bar
        tones = [root + x for x in TRIAD[q]]
        for m in tones:
            put(brass(midi_hz(m), bar * 0.95), t0, 0.04)
        for k in range(8):
            put(bass(midi_hz(root - 12 + riff[k]), slot * 0.7), t0 + k * slot, 0.2)
        for k in (0, 1, 4, 5):
            put(kick(), t0 + k * slot, 0.3 if k % 4 == 0 else 0.2)
        for k in (0, 2, 4, 6):
            put(anvil(1180 if k in (2, 6) else 980, 0.25, 0.14), t0 + k * slot, 0.07)
        if bi >= 4:
            for k in range(16):
                put(pluck(midi_hz(tones[k % 3] + 24), slot / 2), t0 + k * slot / 2, 0.03)
        if bi % 2 == 1:
            put(brass(midi_hz(root + 12 + 7), bar * 0.4), t0 + bar / 2, 0.09)
        for k in range(8):
            put(hat(), t0 + k * slot + slot / 2, 0.05)
    buf[:total] += rumble(total / SR, 62) * 0.04
    tail = buf[total:]
    buf = buf[:total]
    buf[: len(tail)] += tail
    buf *= 0.7 / np.max(np.abs(buf))
    return buf


def sfx_flame_jet():
    """A fire jet roaring up: a rush of noise that swells, roars and dies away."""
    r = np.random.default_rng(71)
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    x = r.standard_normal(n)
    roar = np.convolve(x, np.ones(6) / 6, "same") * np.minimum(t / 0.06, 1) * np.exp(-np.maximum(t - 0.6, 0) / 0.15)
    low = rumble(1.0, 72) * 0.8 * np.minimum(t / 0.05, 1) * np.exp(-t / 0.5)
    crackle = np.zeros(n)
    for _ in range(14):
        i = int(r.uniform(0.05, 0.85) * SR)
        c = noise_hit(0.004, n_sec=0.02)
        crackle[i:i + len(c)] += c * 0.5
    return roar * 0.5 + low + crackle


def sfx_sizzle():
    """Something burning: a hiss that fades, with little pops."""
    r = np.random.default_rng(73)
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    x = r.standard_normal(n)
    hiss = (x - np.convolve(x, np.ones(4) / 4, "same")) * np.exp(-t / 0.18) * np.minimum(t / 0.01, 1)
    for _ in range(5):
        i = int(r.uniform(0.0, 0.35) * SR)
        c = noise_hit(0.003, n_sec=0.015)
        hiss[i:i + len(c)] += c * 1.2
    return hiss


def sfx_anvil_clang():
    """Anvil Annie's slam: a huge clang over a deep thud."""
    out = anvil(620, 1.0, 0.5) * 0.7
    hi = anvil(930, 1.0, 0.3)
    out[: len(hi)] += hi * 0.3
    thud = sweep(110, 40, 0.5)
    t = np.arange(len(thud)) / SR
    out[: len(thud)] += thud * np.exp(-t / 0.12) * 1.2
    return out


def sfx_sparks():
    """Sparks spat out: a crackling fizz."""
    r = np.random.default_rng(74)
    out = np.zeros(int(0.45 * SR))
    for _ in range(18):
        i = int(r.uniform(0.0, 0.35) * SR)
        c = noise_hit(r.uniform(0.002, 0.006), n_sec=0.03)
        out[i:i + len(c)] += c * r.uniform(0.4, 1.0)
    t = np.arange(len(out)) / SR
    return out * np.exp(-t / 0.25)


def sfx_forge_boss_hit():
    """Stomping Anvil Annie: a ringing clang and a grunt of iron."""
    out = anvil(780, 0.7, 0.28)
    g = sweep(160, 90, 0.25, shape="square")
    t = np.arange(len(g)) / SR
    out[: len(g)] += g * np.exp(-t / 0.08) * 0.3
    return out


def sfx_forge_boss_defeat():
    """Anvil Annie beaten: a cracking clang, a heavy fall, cooling hiss, then a fanfare (C Eb G C)."""
    out = np.zeros(int(2.2 * SR))
    c = sfx_anvil_clang()
    out[: len(c)] += c[: len(out)]
    s = sfx_sizzle()
    i = int(0.4 * SR)
    out[i:i + len(s)] += s * 0.6
    for start, m in ((1.0, 72), (1.14, 75), (1.28, 79), (1.42, 84)):
        b = bell(midi_hz(m + 12), 0.5)
        i = int(start * SR)
        out[i:i + len(b)] += b[: len(out) - i] * 0.45
    return out


def write_wav(path, x, rate=SR):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes((x * 32767).astype("<i2").tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav(os.path.join(OUT, "jump.wav"), sfx_jump())
    write_wav(os.path.join(OUT, "land.wav"), sfx_land())
    write_wav(os.path.join(OUT, "hurt.wav"), sfx_hurt())
    write_wav(os.path.join(OUT, "buy.wav"), sfx_buy())
    write_wav(os.path.join(OUT, "ding.wav"), sfx_ding())
    write_wav(os.path.join(OUT, "victory.wav"), sfx_victory())
    write_wav(os.path.join(OUT, "bounce.wav"), sfx_bounce())
    write_wav(os.path.join(OUT, "chest_open.wav"), sfx_chest_open())
    write_wav(os.path.join(OUT, "boss_victory.wav"), sfx_boss_victory())
    tmp = os.path.join(OUT, "_music.wav")
    music = render_music()
    write_wav(tmp, music)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", "2", os.path.join(OUT, "music.ogg")], check=True)
    os.remove(tmp)
    for v in ("level", "saved"):
        m = render_level_music(v)
        write_wav(tmp, m)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                        "-q:a", "2", os.path.join(OUT, "music_%s.ogg" % v)], check=True)
        os.remove(tmp)
        print("AUDIO OK: music_%s %.1fs" % (v, len(m) / SR))
    print("AUDIO OK: music %.1fs" % (len(music) / SR))
    for name, fn in (("boss_hit", sfx_boss_hit), ("boss_charge", sfx_boss_charge),
                     ("boss_crash", sfx_boss_crash), ("boss_defeat", sfx_boss_defeat)):
        write_wav(os.path.join(OUT, name + ".wav"), fn())
    m = render_boss_music()
    write_wav(tmp, m)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", "2", os.path.join(OUT, "music_boss.ogg")], check=True)
    os.remove(tmp)
    print("AUDIO OK: music_boss %.1fs" % (len(m) / SR))
    for name, fn in (("moss_hit", sfx_moss_hit), ("moss_land", sfx_moss_land),
                     ("moss_throw", sfx_moss_throw), ("moss_crack", sfx_moss_crack),
                     ("moss_defeat", sfx_moss_defeat)):
        x = fn()
        write_wav(os.path.join(OUT, name + ".wav"), x * 0.9 / np.max(np.abs(x)))
    for name, fn in (("chomp", sfx_chomp), ("splash", sfx_splash), ("bubbles", sfx_bubbles),
                     ("harpoon_fire", sfx_harpoon_fire), ("lake_boss_hit", sfx_lake_boss_hit),
                     ("lake_boss_defeat", sfx_lake_boss_defeat), ("flame_jet", sfx_flame_jet),
                     ("sizzle", sfx_sizzle), ("anvil_clang", sfx_anvil_clang), ("sparks", sfx_sparks),
                     ("forge_boss_hit", sfx_forge_boss_hit), ("forge_boss_defeat", sfx_forge_boss_defeat)):
        x = fn()
        write_wav(os.path.join(OUT, name + ".wav"), x * 0.9 / np.max(np.abs(x)))
    for name, fn in (("music_moss", render_moss_music), ("music_moss_boss", render_moss_boss_music),
                     ("music_lake", render_lake_music), ("music_lake_boss", render_lake_boss_music),
                     ("music_forge", render_forge_music), ("music_forge_boss", render_forge_boss_music)):
        m = fn()
        write_wav(tmp, m)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                        "-q:a", "2", os.path.join(OUT, name + ".ogg")], check=True)
        os.remove(tmp)
        print("AUDIO OK: %s %.1fs" % (name, len(m) / SR))


if __name__ == "__main__":
    main()
