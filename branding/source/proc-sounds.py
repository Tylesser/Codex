r"""Codex's own proc sounds, one made for each kind of proc (the user's requests, 2026-11-23: "more suitable sounds
for procs", then "more related to spells, not random sounds"), made here from sine waves and noise: nothing
recorded, nothing taken from the game.

  python proc-sounds.py <outDir>

Writes <outDir>/<key>.wav (44.1 kHz, 16-bit mono, peak -3 dB). The game plays .ogg, so encode them, e.g. with the
Ubuntu image the workspace already has:

  MSYS_NO_PATHCONV=1 docker run --rm -v "<outDir>:/w" ubuntu:24.04 bash -c \
    "apt-get update -qq && apt-get install -y -qq vorbis-tools >/dev/null && cd /w && for f in *.wav; do oggenc -Q -q 5 \"\$f\"; done"

and copy the .ogg files to Modules/QoL/Media/Sounds/ (Codex) and Media/Sounds/ (Proc Glow). The keys and names are
P.SOUNDS in ProcGlow.lua ("codex" group); which proc plays which is P.PROC_SOUNDS.
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 44100


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def shift(track, seconds):
    return silence(seconds) + track


def env(i, attack, decay):
    """Attack (s) then an exponential decay with time constant `decay` (s)."""
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / decay)


def bell(freq, seconds, partials=((1, 1.0, 1.0), (2.76, 0.45, 0.55), (5.4, 0.25, 0.3), (8.93, 0.12, 0.18)),
         attack=0.002, decay=0.45):
    """An inharmonic bell: (ratio, gain, decay factor) partials."""
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        v = 0.0
        for ratio, gain, k in partials:
            v += gain * math.sin(2 * math.pi * freq * ratio * t) * env(i, attack, decay * k)
        out.append(v)
    return out


def tone(freq, seconds, attack=0.01, decay=0.3, shape=None, vibrato=0.0, glide=0.0):
    out, phase = [], 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        f = freq * (1 + glide * t) * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t))
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase)
        if shape == "soft":
            s = 0.8 * s + 0.2 * math.sin(2 * phase)
        out.append(s * env(i, attack, decay))
    return out


def noise(seconds, seed, attack, decay, cutoff):
    """Noise through a one-pole low-pass (cutoff in Hz), with an envelope."""
    rng = random.Random(seed)
    a = math.exp(-2 * math.pi * cutoff / RATE)
    y, out = 0.0, []
    for i in range(int(RATE * seconds)):
        y = (1 - a) * rng.uniform(-1, 1) + a * y
        out.append(y * env(i, attack, decay))
    return out


def gain(track, g):
    return [v * g for v in track]


def fade_out(track, seconds=0.04):
    n = int(RATE * seconds)
    for k in range(min(n, len(track))):
        track[-1 - k] *= k / n
    return track


# More building blocks for spell sounds -------------------------------------------------------------------------------

def band(track, low, high):
    """A rough band-pass: a one-pole high-pass at `low` then a one-pole low-pass at `high` (Hz)."""
    a_hp = math.exp(-2 * math.pi * low / RATE)
    a_lp = math.exp(-2 * math.pi * high / RATE)
    out, prev_x, hp, lp = [], 0.0, 0.0, 0.0
    for x in track:
        hp = a_hp * (hp + x - prev_x)
        prev_x = x
        lp = (1 - a_lp) * hp + a_lp * lp
        out.append(lp)
    return out


def sweep_noise(seconds, seed, f0, f1, attack, decay, width=0.6):
    """Noise whose band glides from f0 to f1 Hz: a whoosh."""
    rng = random.Random(seed)
    out, lp1, lp2 = [], 0.0, 0.0
    n = int(RATE * seconds)
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / n)
        a1 = math.exp(-2 * math.pi * f * (1 + width) / RATE)
        a2 = math.exp(-2 * math.pi * f * (1 - width / 2) / RATE)
        x = rng.uniform(-1, 1)
        lp1 = (1 - a1) * x + a1 * lp1
        lp2 = (1 - a2) * x + a2 * lp2
        out.append((lp1 - lp2) * 3 * env(i, attack, decay))
    return out


def crackle(seconds, seed, rate, decay):
    """Random sharp clicks (fire, sparks), each a tiny decaying burst."""
    rng = random.Random(seed)
    n = int(RATE * seconds)
    out = [0.0] * n
    t = 0.0
    while True:
        t += rng.expovariate(rate)
        if t >= seconds:
            break
        start = int(t * RATE)
        amp = rng.uniform(0.3, 1) * math.exp(-t / decay)
        for k in range(min(260, n - start)):
            out[start + k] += amp * rng.uniform(-1, 1) * math.exp(-k / 40)
    return out


def saw(freq, seconds, attack, decay, detune=0.0, cutoff=2500):
    out, p1, p2 = [], 0.0, 0.0
    for i in range(int(RATE * seconds)):
        p1 = (p1 + freq / RATE) % 1
        p2 = (p2 + freq * (1 + detune) / RATE) % 1
        out.append(((2 * p1 - 1) + (2 * p2 - 1)) * 0.5 * env(i, attack, decay))
    return band(out, 40, cutoff)


def echo(track, delay, feedback, count):
    out = list(track) + silence(delay * count)
    for k in range(1, count + 1):
        g = feedback ** k
        offset = int(RATE * delay * k)
        for i, v in enumerate(track):
            out[i + offset] += v * g
    return out


def metal(freq, seconds, decay, seed=1):
    """A struck blade: high inharmonic partials and a noise transient."""
    ring = bell(freq, seconds, partials=((1, 1.0, 1.0), (1.47, 0.7, 0.8), (2.09, 0.55, 0.6), (2.74, 0.4, 0.45),
                                          (3.9, 0.25, 0.3)), attack=0.001, decay=decay)
    hit = band(noise(0.08, seed, 0.0005, 0.012, 12000), 2500, 12000)
    return mix(gain(ring, 0.6), gain(hit, 1.2))


def thump(freq, seconds, decay, seed=2):
    body = tone(freq, seconds, attack=0.002, decay=decay, glide=-0.55)
    smack = band(noise(0.12, seed, 0.0005, 0.02, 3000), 200, 3000)
    return mix(body, gain(smack, 0.9))


def holy_chord(seconds, root=523.25):
    return mix(*[tone(f, seconds, attack=0.05, decay=seconds * 0.45, shape="soft", vibrato=0.003)
                 for f in (root, root * 1.25, root * 1.5, root * 2)])


# The sounds, one made for each kind of proc (2026-11-23, the user: "more related to spells, not random sounds") ----

def s_sword_clash():  # Overpower: two blades meeting
    return mix(metal(2350, 0.7, 0.22, 3), shift(gain(metal(1980, 0.6, 0.2, 4), 0.8), 0.07))


def s_shield_bash():  # Revenge: a shield slammed forward
    return mix(thump(95, 0.5, 0.1, 5), gain(metal(820, 0.45, 0.12, 6), 0.45))


def s_axe_chop():  # Execute: a heavy swing, then the blow
    swing = sweep_noise(0.32, 7, 300, 1800, 0.18, 0.12)
    blow = mix(thump(70, 0.5, 0.13, 8), gain(metal(1300, 0.4, 0.1, 9), 0.4))
    return mix(gain(swing, 0.8), shift(blow, 0.24))


def s_victory():  # Victory Rush: a short rising horn call
    notes = [(392, 0.0, 0.18), (523.25, 0.13, 0.18), (659.25, 0.26, 0.5)]
    return mix(*[shift(saw(f, length + 0.25, 0.02, length, 0.004, 2200), at) for f, at, length in notes])


def s_parry():  # Riposte, Counterattack: a deflected blade, a quick scrape
    ting = metal(3100, 0.55, 0.16, 10)
    scrape = band(noise(0.22, 11, 0.01, 0.07, 9000), 3000, 9000)
    return mix(ting, shift(gain(scrape, 0.6), 0.03))


def s_beast_snap():  # Mongoose Bite: a growl and snapping jaws
    growl = []
    rng = random.Random(12)
    for i in range(int(RATE * 0.35)):
        t = i / RATE
        growl.append(math.sin(2 * math.pi * 85 * t + 3 * math.sin(2 * math.pi * 31 * t)) * rng.uniform(0.6, 1)
                     * env(i, 0.04, 0.12))
    snap = mix(band(noise(0.06, 13, 0.0005, 0.008, 8000), 1500, 8000), tone(900, 0.05, 0.001, 0.01))
    return mix(gain(band(growl, 60, 900), 1.4), shift(gain(snap, 1.3), 0.2), shift(gain(snap, 1.0), 0.29))


def s_holy_hammer():  # Hammer of Wrath: a hammer blow that rings with light
    blow = mix(thump(80, 0.5, 0.12, 14), gain(metal(1100, 0.5, 0.15, 15), 0.5))
    return mix(blow, shift(gain(holy_chord(1.0), 0.7), 0.05), shift(gain(bell(2093, 0.8, decay=0.3), 0.3), 0.08))


def s_holy_echo():  # the paladin's echoes: a holy bell that echoes back
    return echo(mix(bell(784, 0.6, decay=0.25), gain(holy_chord(0.6, 784), 0.4)), 0.16, 0.5, 3)


def s_shadow():  # Shadow Trance: a dark swell and a whisper
    drone = saw(73.4, 1.0, 0.0, 10, 0.012, 700)
    n = len(drone)
    swell = [v * (i / n) ** 1.6 * (1 - max(0.0, (i / n - 0.85) / 0.15)) for i, v in enumerate(drone)]
    whisper = band(noise(1.0, 16, 0.3, 0.4, 7000), 2500, 7000)
    return mix(gain(swell, 1.2), gain(whisper, 0.5), shift(gain(tone(146.8, 0.5, 0.01, 0.2), 0.4), 0.82))


def s_arcane():  # Clearcasting (mage): a bright arcane shimmer
    out = []
    for i in range(int(RATE * 0.9)):
        t = i / RATE
        mod = 2.5 * math.sin(2 * math.pi * 1650 * t) * math.exp(-t / 0.35)
        out.append(math.sin(2 * math.pi * 880 * t + mod) * (0.65 + 0.35 * math.sin(2 * math.pi * 11 * t))
                   * env(i, 0.03, 0.3))
    sparkle = mix(*[shift(bell(f, 0.4, decay=0.12), k * 0.06) for k, f in enumerate((1760, 2349, 2637))])
    return mix(out, gain(sparkle, 0.35))


def s_missiles():  # Missile Barrage: three arcane bolts
    zap = []
    phase = 0.0
    for i in range(int(RATE * 0.18)):
        t = i / RATE
        f = 1800 * (0.35 ** (t / 0.18))
        phase += 2 * math.pi * f / RATE
        zap.append(math.sin(phase) * env(i, 0.002, 0.07))
    return mix(*[shift(gain(zap, 1 - k * 0.15), k * 0.12) for k in range(3)])


def s_fire():  # Heating Up: fire catching, with crackles
    whoosh = sweep_noise(0.7, 17, 250, 2200, 0.15, 0.25)
    sparks = band(crackle(0.8, 18, 45, 0.5), 1500, 9000)
    roar = band(noise(0.7, 19, 0.1, 0.3, 500), 60, 500)
    return mix(gain(whoosh, 1.0), gain(sparks, 0.7), gain(roar, 1.4))


def s_nature():  # Clearcasting (druid): wooden chimes and rustling leaves
    chimes = [(659.25, 0.0), (880, 0.07), (987.77, 0.15)]
    wood = mix(*[shift(bell(f, 0.5, partials=((1, 1.0, 1.0), (3.9, 0.3, 0.25), (9.2, 0.1, 0.12)), decay=0.12), at)
                 for f, at in chimes])
    leaves = band(noise(0.6, 20, 0.1, 0.18, 6000), 1500, 6000)
    return mix(wood, gain(leaves, 0.35))


def s_lightning():  # Clearcasting (shaman): an electric crackle and a zap
    crack = band(crackle(0.5, 21, 120, 0.15), 800, 12000)
    zap = []
    rng = random.Random(22)
    for i in range(int(RATE * 0.4)):
        t = i / RATE
        zap.append((1 if math.sin(2 * math.pi * 120 * t) > 0 else -1) * rng.uniform(0.7, 1) * env(i, 0.002, 0.08))
    return mix(gain(crack, 1.2), gain(band(zap, 200, 5000), 0.6))


SOUNDS = {
    "sword_clash": s_sword_clash, "shield_bash": s_shield_bash, "axe_chop": s_axe_chop, "victory": s_victory,
    "parry": s_parry, "beast_snap": s_beast_snap, "holy_hammer": s_holy_hammer, "holy_echo": s_holy_echo,
    "shadow": s_shadow, "arcane": s_arcane, "missiles": s_missiles, "fire": s_fire, "nature": s_nature,
    "lightning": s_lightning,
}


def write(path, samples):
    peak = max(abs(v) for v in samples) or 1.0
    rms = math.sqrt(sum(v * v for v in samples) / len(samples)) or 1.0
    scale = min(0.708 / peak, 0.11 / rms)  # about the same loudness each, never over -3 dB
    samples = fade_out([v * scale for v in samples])
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in samples))


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for key, make in SOUNDS.items():
        path = os.path.join(out, key + ".wav")
        write(path, make())
        print("wrote", path)


if __name__ == "__main__":
    main()
