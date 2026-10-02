#!/usr/bin/env python3
"""Procedural audio generator for Crystal Bastion.

Synthesizes every sound effect and music loop that scripts/autoload/audio.gd
expects and writes them to assets/audio/{sfx,music}:

  sfx/<name>.wav    16-bit mono 44.1 kHz one-shots, peak-normalized to -3 dBFS
  sfx/laser.ogg     seamless 1.0 s loop (every component is periodic in 1 s), set to -14 LUFS
  music/<name>.ogg  stereo Vorbis loops built from whole bars, mastered to -18 LUFS

The .wav.import files keep the short one-shots uncompressed in Godot (compress/mode=0):
the default QOA codec only reaches 17-22 dB SNR on the noisy ones (explosion, arrow, tesla).
The three long tonal jingles (victory, defeat, boss) use QOA (compress/mode=2) to keep the
arm64 APK under 30 MB; QOA is transparent enough on tonal material.

Everything is plain numpy DSP (additive, wavetable, modal and FM synthesis,
FFT-domain filters). Music is rendered into a buffer one loop long: note tails
that ring past the loop end are folded back onto the start, and reverb/delay
are circular convolutions, so the end of each track flows into its start.

Deterministic: all randomness comes from fixed seeds. OGG encoding uses ffmpeg
(libvorbis) with bit-exact flags.

Usage:
  python3 crystal-bastion/tools/gen_audio.py              # everything
  python3 crystal-bastion/tools/gen_audio.py coin menu    # only these names
"""

import os
import subprocess
import sys
import time
import wave
import zlib

import numpy as np

SR = 44100
TAU = 2.0 * np.pi
HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
SFX_DIR = os.path.join(PROJECT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(PROJECT, "assets", "audio", "music")


# =========================================================================
# Basic helpers
# =========================================================================

def ns(sec):
	return int(round(sec * SR))


def tvec(n):
	return np.arange(n, dtype=np.float64) / SR


def mtof(m):
	return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def dbg(db):
	return 10.0 ** (db / 20.0)


def rms(x):
	return float(np.sqrt(np.mean(np.square(x)) + 1e-20))


def rng_for(name, salt=0):
	return np.random.default_rng(zlib.crc32(name.encode()) * 131 + salt)


def ramp(n):
	"""Raised-cosine 0 -> 1 over n samples (first sample exactly 0)."""
	if n <= 0:
		return np.ones(0)
	return 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / n)


def fades(x, fin=0.0015, fout=0.02):
	x = np.array(x, dtype=np.float64, copy=True)
	a = min(ns(fin), x.shape[-1])
	b = min(ns(fout), x.shape[-1])
	if a > 0:
		x[..., :a] *= ramp(a)
	if b > 0:
		x[..., -b:] *= ramp(b)[::-1]
	return x


def env_perc(n, attack, decay, hold=0.0):
	"""Smooth attack, optional hold, exponential decay (time constant `decay`)."""
	t = tvec(n)
	env = np.exp(-np.maximum(t - attack - hold, 0.0) / decay)
	a = min(ns(attack), n)
	if a > 0:
		env[:a] *= ramp(a)
	return env


def ramp_env(n, attack):
	"""1.0 everywhere except a raised-cosine fade-in over `attack` seconds."""
	e = np.ones(n)
	a = min(ns(attack), n)
	e[:a] = ramp(a)
	return e


def env_note(n, attack, dur, release, sustain=1.0, settle=0.3):
	"""Attack -> settle towards `sustain` -> raised-cosine release at `dur`."""
	t = tvec(n)
	env = sustain + (1.0 - sustain) * np.exp(-np.maximum(t - attack, 0.0) / settle)
	a = min(ns(attack), n)
	if a > 0:
		env[:a] *= ramp(a)
	r0 = ns(dur)
	if r0 < n:
		m = min(ns(release), n - r0)
		tail = np.zeros(n - r0)
		if m > 0:
			tail[:m] = ramp(m)[::-1] ** 1.5
		env[r0:] *= tail
	return env


def place(buf, sig, start):
	start = int(start)
	if start >= buf.shape[-1]:
		return
	n = min(sig.shape[-1], buf.shape[-1] - start)
	buf[..., start:start + n] += sig[..., :n]


def next_fast(n):
	best = 1 << int(np.ceil(np.log2(max(n, 1))))
	p5 = 1
	while p5 <= best:
		p35 = p5
		while p35 <= best:
			v = p35
			while v < n:
				v *= 2
			best = min(best, v)
			p35 *= 3
		p5 *= 5
	return best


# =========================================================================
# Filters (FFT domain, zero phase)
# =========================================================================

def lp(fc, order=2):
	return lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def hp(fc, order=2):
	def g(f):
		x = (f / fc) ** order
		return x / np.sqrt(1.0 + x * x)
	return g


def band(lo, hi, order=2):
	a, b = hp(lo, order), lp(hi, order)
	return lambda f: a(f) * b(f)


def sfilt(x, resp, circular=False):
	"""Zero-phase filter. Non-circular mode zero-pads so nothing wraps."""
	n = x.shape[-1]
	size = n if circular else next_fast(n + min(n, 16384) + 256)
	spec = np.fft.rfft(x, size)
	f = np.fft.rfftfreq(size, 1.0 / SR)
	return np.fft.irfft(spec * resp(f), size)[..., :n]


def fnoise(n, r, resp, circular=False):
	"""RMS-normalized filtered white noise."""
	y = sfilt(r.standard_normal(n), resp, circular)
	return y / (rms(y) + 1e-12)


def band_partition(f, centers):
	"""Raised-cosine partition of unity over log-frequency."""
	lf = np.log(np.maximum(f, 1.0))
	lc = np.log(centers)
	parts = []
	for i in range(len(centers)):
		g = np.zeros_like(f)
		if i == 0:
			g[lf <= lc[i]] = 1.0
		else:
			m = (lf > lc[i - 1]) & (lf <= lc[i])
			g[m] = np.sin(0.5 * np.pi * (lf[m] - lc[i - 1]) / (lc[i] - lc[i - 1])) ** 2
		if i == len(centers) - 1:
			g[lf > lc[i]] = 1.0
		else:
			m = (lf > lc[i]) & (lf < lc[i + 1])
			g[m] = np.cos(0.5 * np.pi * (lf[m] - lc[i]) / (lc[i + 1] - lc[i])) ** 2
		parts.append(g)
	return parts


def swept_noise(n, r, fc, mode="lp", q=1.5, order=2, nb=20, fmin=60.0, fmax=15000.0, circular=False):
	"""Noise through a time-varying filter, built by morphing a bank of bands."""
	w = r.standard_normal(n)
	size = n if circular else next_fast(n + 4096)
	spec = np.fft.rfft(w, size)
	f = np.fft.rfftfreq(size, 1.0 / SR)
	fc = np.maximum(np.broadcast_to(np.asarray(fc, dtype=np.float64), (n,)), 1.0)
	centers = np.geomspace(fmin, fmax, nb)
	out = np.zeros(n)
	for c, g in zip(centers, band_partition(f, centers)):
		b = np.fft.irfft(spec * g, size)[:n]
		if mode == "lp":
			wgt = 1.0 / np.sqrt(1.0 + (c / fc) ** (2 * order))
		elif mode == "hp":
			x = (c / fc) ** order
			wgt = x / np.sqrt(1.0 + x * x)
		else:
			wgt = 1.0 / np.sqrt(1.0 + (q * (c / fc - fc / c)) ** 2)
		out += b * wgt
	return out / (rms(out) + 1e-12)


def dc_block(x, fc=18.0):
	"""Causal one-pole DC blocker (keeps attacks free of pre-ringing)."""
	a = np.exp(-TAU * fc / SR)
	y = np.empty_like(x)
	px = 0.0
	py = 0.0
	for i, v in enumerate(x.tolist()):
		py = v - px + a * py
		px = v
		y[i] = py
	return y


# =========================================================================
# Oscillators and voices
# =========================================================================

TABLE = 4096


def harmonic_table(amps):
	"""Single-cycle table with sine harmonics amps[k-1] (peak-normalized)."""
	amps = np.asarray(amps, dtype=np.float64)
	k = min(len(amps), TABLE // 2 - 1)
	spec = np.zeros(TABLE // 2 + 1, dtype=np.complex128)
	spec[1:k + 1] = amps[:k] * (TABLE / 2.0) * (-1j)
	tab = np.fft.irfft(spec, TABLE)
	return tab / (np.max(np.abs(tab)) + 1e-12)


def table_read(tab, cycles):
	pos = np.mod(cycles, 1.0) * TABLE
	i0 = pos.astype(np.int64)
	frac = pos - i0
	i0 %= TABLE
	a = tab[i0]
	b = tab[(i0 + 1) % TABLE]
	return a + (b - a) * frac


def phase_of(freq, n, start=0.0):
	if np.ndim(freq) == 0:
		return start + float(freq) * np.arange(n) / SR
	return start + np.cumsum(freq) / SR


def saw_amps(f0, fmax, cutoff=None, order=2, slope=1.0):
	kmax = max(1, int(fmax / f0))
	k = np.arange(1, kmax + 1)
	a = 1.0 / k ** slope
	if cutoff:
		a *= lp(cutoff, order)(k * f0)
	return a


def modal(n, freqs, amps, decays, r, attack=0.001):
	"""Sum of exponentially decaying sine partials (bells, bars, bodies)."""
	t = tvec(n)
	out = np.zeros(n)
	for f, a, d in zip(freqs, amps, decays):
		if f >= SR * 0.45 or a == 0.0:
			continue
		out += a * np.sin(TAU * f * t + r.uniform(0, TAU)) * np.exp(-t / d)
	a_n = min(ns(attack), n)
	if a_n > 0:
		out[:a_n] *= ramp(a_n)
	return fades(out, 0.0, min(0.04, n / SR * 0.3))


def pluck(freq, dur, r, bright=0.5, decay=1.0, pos=0.2, nh=16, inharm=0.0, fmax=11000.0, attack=0.0025):
	"""Additive plucked string: comb-shaped spectrum, faster decay for high partials."""
	n = ns(dur)
	t = tvec(n)
	f0 = float(np.mean(freq)) if np.ndim(freq) else float(freq)
	cyc = phase_of(freq, n)
	out = np.zeros(n)
	norm = 0.0
	for k in range(1, nh + 1):
		stretch = np.sqrt(1.0 + inharm * k * k)
		fk = k * f0 * stretch
		if fk > fmax:
			break
		a = (abs(np.sin(np.pi * k * pos)) + 0.05) / k ** (1.55 - bright)
		dk = decay / (1.0 + (k - 1) * (1.25 - bright) * 0.55)
		out += a * np.sin(TAU * k * stretch * cyc + r.uniform(0, TAU)) * np.exp(-t / dk)
		norm += a * a
	out /= np.sqrt(norm) + 1e-12
	a_n = ns(attack)
	out[:a_n] *= ramp(a_n)
	return fades(out, 0.0, 0.03)


# =========================================================================
# Instruments (music)
# =========================================================================

def vibrato(n, r, rate=5.0, depth=0.004, delay=0.25, rise=0.35):
	t = tvec(n)
	amt = np.clip((t - delay) / rise, 0.0, 1.0)
	return 1.0 + depth * amt * np.sin(TAU * rate * t + r.uniform(0, TAU))


def formant_gain(f, formants, base=0.3):
	g = np.full_like(f, base, dtype=np.float64)
	for fc, amp, q in formants:
		g = g + amp / np.sqrt(1.0 + (q * (f / fc - fc / np.maximum(f, 1.0))) ** 2)
	return g


BRASS_FORMANTS = [(560.0, 1.0, 1.5), (1250.0, 0.65, 1.7), (2700.0, 0.25, 2.0)]


def brass_voice(fcurve, bright_env, r, f_ref, bright_top=4200.0):
	n = len(fcurve)
	kmax = max(1, int(min(7000.0, SR * 0.4) / (f_ref * 1.04)))
	k = np.arange(1, kmax + 1)
	fk = k * f_ref
	form = formant_gain(fk, BRASS_FORMANTS)
	dark = harmonic_table(form / k ** 1.35 * lp(1000, 2)(fk))
	bright = harmonic_table(form / k ** 0.6 * lp(bright_top, 2)(fk))
	cyc = phase_of(fcurve, n, r.uniform())
	a = table_read(dark, cyc)
	b = table_read(bright, cyc)
	return a + (b - a) * np.clip(bright_env, 0.0, 1.0)


def inst_horn(midi, dur, r, vel=1.0, release=0.25, scoop=0.5, bright=0.6, attack=0.07):
	f0 = mtof(midi)
	n = ns(dur + release + 0.03)
	t = tvec(n)
	f = f0 * 2.0 ** (-(scoop / 12.0) * np.exp(-t / 0.05)) * vibrato(n, r, 4.8, 0.0035, 0.3)
	env = env_note(n, attack, dur, release, sustain=0.8, settle=0.3)
	s = brass_voice(f, bright * env * (0.75 + 0.35 * vel), r, f0)
	s += 0.5 * brass_voice(f * 1.003, bright * 0.8 * env, r, f0)
	return s * env * vel / 1.5


def inst_trumpet(midi, dur, r, vel=1.0, release=0.12):
	f0 = mtof(midi)
	n = ns(dur + release + 0.03)
	t = tvec(n)
	f = f0 * 2.0 ** (-(0.35 / 12.0) * np.exp(-t / 0.025)) * vibrato(n, r, 5.5, 0.004, 0.2)
	env = env_note(n, 0.025, dur, release, sustain=0.75, settle=0.12)
	s = brass_voice(f, 0.45 + 0.55 * env, r, f0, bright_top=5500.0)
	return s * env * vel


_flute_cache = {}


def inst_flute(midi, dur, r, vel=1.0, release=0.12, breath=0.07, attack=0.045):
	f0 = mtof(midi)
	n = ns(dur + release + 0.03)
	t = tvec(n)
	key = int(midi)
	if key not in _flute_cache:
		amps = np.array([1.0, 0.42, 0.14, 0.07, 0.03, 0.015])
		k = np.arange(1, len(amps) + 1)
		amps = amps * (k * f0 < 12000)
		_flute_cache[key] = harmonic_table(amps)
	f = f0 * vibrato(n, r, 5.2, 0.0045, 0.18) * 2.0 ** (-(0.12 / 12.0) * np.exp(-t / 0.03))
	tone = table_read(_flute_cache[key], phase_of(f, n, r.uniform()))
	env = env_note(n, attack, dur, release, sustain=0.85, settle=0.25)
	air = fnoise(n, r, band(f0 * 1.5, min(f0 * 6.0, 12000.0), 1))
	air_env = 0.6 + 1.6 * np.exp(-t / 0.05)
	return (tone + breath * air * air_env) * env * vel


def inst_whistle(midi, dur, r, vel=1.0, release=0.14):
	f0 = mtof(midi)
	n = ns(dur + release + 0.03)
	t = tvec(n)
	f = f0 * 2.0 ** (-(0.9 / 12.0) * np.exp(-t / 0.045)) * vibrato(n, r, 5.7, 0.007, 0.16, 0.3)
	cyc = phase_of(f, n, r.uniform())
	tone = np.sin(TAU * cyc) + 0.06 * np.sin(2 * TAU * cyc) + 0.02 * np.sin(3 * TAU * cyc)
	env = env_note(n, 0.035, dur, release, sustain=0.8, settle=0.3)
	air = fnoise(n, r, band(f0 * 0.9, f0 * 2.5, 1))
	return (tone + 0.035 * air) * env * vel


def inst_strings(midi, dur, r, vel=1.0, attack=0.14, release=0.35, cutoff=2600.0):
	f0 = mtof(midi)
	n = ns(dur + release + 0.03)
	tab = harmonic_table(saw_amps(f0, 9000.0, cutoff, 2))
	out = np.zeros(n)
	for cents in (-6.0, 0.0, 6.5):
		f = f0 * 2.0 ** (cents / 1200.0) * vibrato(n, r, 5.0 + r.uniform(-0.3, 0.3), 0.004, 0.2)
		out += table_read(tab, phase_of(f, n, r.uniform()))
	env = env_note(n, attack, dur, release, sustain=0.9, settle=0.4)
	return out / 3.0 * env * vel


def inst_pad(midis, dur, r, attack=0.8, release=1.5, cutoff=1800.0, detune=7.0, kind="warm",
		voices=3, width=0.8):
	"""Stereo chord pad, slow attack, detuned voices spread across the field."""
	n = ns(dur + release + 0.05)
	out = np.zeros((2, n))
	for m in midis:
		f0 = mtof(m)
		if kind == "glass":
			k = np.arange(1, 6)
			amps = np.array([1.0, 0.28, 0.1, 0.05, 0.02]) * (k * f0 < 12000)
		elif kind == "choir":
			kk = np.arange(1, max(2, int(5000 / f0)) + 1)
			amps = formant_gain(kk * f0, [(330.0, 1.0, 2.2), (850.0, 0.55, 2.5), (2500.0, 0.12, 3.0)], 0.04) / kk
		else:
			amps = saw_amps(f0, 8000.0, cutoff, 2)
		tab = harmonic_table(amps)
		for v in range(voices):
			off = (v - (voices - 1) / 2.0) / max((voices - 1) / 2.0, 1.0)
			cents = off * detune + r.uniform(-1.0, 1.0)
			drift = 1.0 + 0.0015 * np.sin(TAU * r.uniform(0.15, 0.4) * tvec(n) + r.uniform(0, TAU))
			sig = table_read(tab, phase_of(f0 * 2.0 ** (cents / 1200.0) * drift, n, r.uniform()))
			th = (off * width + 1.0) * np.pi / 4.0
			out[0] += sig * np.cos(th)
			out[1] += sig * np.sin(th)
		if kind == "glass":
			# soft shimmer an octave up with slow tremolo
			tab2 = harmonic_table([1.0])
			t = tvec(n)
			sh = table_read(tab2, phase_of(2.0 * f0 * 1.001, n, r.uniform()))
			sh *= 0.12 * (0.6 + 0.4 * np.sin(TAU * r.uniform(0.3, 0.7) * t + r.uniform(0, TAU)))
			out[0] += sh
			out[1] += sh
	env = env_note(n, attack, dur, release, sustain=1.0, settle=1.0)
	return out * env * np.sqrt(2.0) / (len(midis) * voices) ** 0.5 / 1.6


def inst_pluck(midi, r, vel=1.0, dur=1.6, bright=0.55, decay=1.0, pos=0.25, inharm=0.0, courses=1):
	f0 = mtof(midi)
	bright = min(0.95, bright + 0.12 * (vel - 0.8))
	out = pluck(f0, dur, r, bright, decay, pos, inharm=inharm)
	for c in range(1, courses):
		out = out + pluck(f0 * 2.0 ** ((2.2 * c) / 1200.0), dur, r, bright, decay, pos, inharm=inharm)
	n = len(out)
	pick = fnoise(n, r, band(1500, 7000, 1)) * env_perc(n, 0.0005, 0.004) * 0.08 * bright
	return (out / courses + pick) * vel


def inst_bell(midi, r, vel=1.0, dur=2.5, kind="celesta"):
	f0 = mtof(midi)
	n = ns(dur)
	if kind == "celesta":
		ratios, amps, decays = [1.0, 2.0, 3.0, 4.07], [1.0, 0.2, 0.06, 0.04], [1.5, 0.55, 0.3, 0.18]
	elif kind == "glock":
		ratios, amps, decays = [1.0, 2.76, 5.40], [1.0, 0.28, 0.08], [0.9, 0.28, 0.1]
	else:  # chime (wind chimes, inharmonic tube)
		ratios, amps, decays = [1.0, 2.76, 5.40, 8.93], [1.0, 0.33, 0.12, 0.05], [2.0, 0.8, 0.3, 0.15]
	s = modal(n, [f0 * q for q in ratios], amps, decays, r, attack=0.0015)
	s += 0.6 * modal(n, [f0 * 1.0015], [0.35], [decays[0] * 0.8], r)
	strike = fnoise(n, r, band(2000, 9000, 1)) * env_perc(n, 0.0003, 0.003) * 0.05
	return fades((s + strike) * vel, 0.0, 0.08) / 1.3


def inst_bass(midi, dur, r, vel=1.0, kind="round", release=0.12):
	f0 = mtof(midi)
	if kind == "pluck":
		s = pluck(f0, dur + 0.4, r, bright=0.3, decay=0.75, pos=0.22, nh=10)
		s *= env_note(len(s), 0.004, dur, 0.15)
		return s * vel * 1.3
	n = ns(dur + release + 0.02)
	t = tvec(n)
	if kind == "sub":
		tab = harmonic_table([1.0, 0.18, 0.05])
		env = env_note(n, 0.25, dur, max(release, 0.6), sustain=1.0, settle=1.0)
	else:
		tab = harmonic_table([1.0, 0.4, 0.16, 0.07, 0.03])
		env = env_note(n, 0.012, dur, release, sustain=0.65, settle=0.5)
	s = table_read(tab, phase_of(f0 * (1.0 + 0.004 * np.exp(-t / 0.03)), n, 0.0))
	return s * env * vel


# =========================================================================
# Percussion
# =========================================================================

def dr_kick(r, vel=1.0, f_hi=115.0, f_lo=48.0, decay=0.28):
	n = ns(decay * 3.0 + 0.05)
	t = tvec(n)
	f = f_lo + (f_hi - f_lo) * np.exp(-t / 0.035)
	body = np.sin(TAU * phase_of(f, n)) * env_perc(n, 0.002, decay)
	click = fnoise(n, r, band(600, 3500, 1)) * env_perc(n, 0.0005, 0.005) * 0.12
	return fades(np.tanh(1.4 * (body + click)) * vel, 0.0, 0.03)


def dr_frame(r, vel=1.0, pitch=1.0):
	n = ns(0.5)
	t = tvec(n)
	f = (72.0 + 40.0 * np.exp(-t / 0.03)) * pitch
	low = np.sin(TAU * phase_of(f, n)) * env_perc(n, 0.002, 0.16)
	skin = fnoise(n, r, band(250 * pitch, 1800 * pitch, 1)) * env_perc(n, 0.001, 0.03) * 0.35
	ring = modal(n, [190.0 * pitch, 305.0 * pitch], [0.25, 0.12], [0.07, 0.05], r)
	return fades((low + skin + ring) * vel, 0.0, 0.05)


def dr_shaker(r, vel=1.0, length=0.12):
	n = ns(length)
	return fnoise(n, r, band(4000, 11000, 2)) * env_perc(n, 0.009, 0.03) * vel * 0.5


def dr_tamb(r, vel=1.0):
	n = ns(0.35)
	jing = modal(n, [5300.0, 6870.0, 8420.0, 9900.0, 7600.0], [1.0, 0.8, 0.6, 0.4, 0.5],
			[0.07, 0.06, 0.05, 0.04, 0.06], r)
	hiss = fnoise(n, r, band(6000, 13000, 2)) * env_perc(n, 0.002, 0.05)
	return fades((0.25 * jing + 0.35 * hiss) * vel, 0.0, 0.05)


def dr_wood(r, vel=1.0, f=820.0):
	n = ns(0.18)
	s = modal(n, [f, f * 2.71, f * 4.5], [1.0, 0.4, 0.12], [0.04, 0.018, 0.01], r, attack=0.0005)
	s += fnoise(n, r, band(1500, 6000, 1)) * env_perc(n, 0.0003, 0.002) * 0.2
	return fades(s * vel, 0.0, 0.03)


def dr_timp(r, midi, vel=1.0, decay=1.1):
	f0 = mtof(midi)
	n = ns(decay * 2.2)
	t = tvec(n)
	glide = 1.0 + 0.02 * np.exp(-t / 0.04)
	cyc = phase_of(f0 * glide, n)
	s = np.zeros(n)
	for q, a, d in ((1.0, 1.0, 1.0), (1.505, 0.5, 0.7), (1.99, 0.35, 0.5), (2.44, 0.2, 0.35), (2.98, 0.1, 0.25)):
		s += a * np.sin(TAU * q * cyc + r.uniform(0, TAU)) * np.exp(-t / (decay * d))
	s *= ramp_env(n, 0.002)
	mallet = fnoise(n, r, lp(1200, 1)) * env_perc(n, 0.001, 0.02) * 0.4
	return fades((s + mallet) * vel / 1.6, 0.0, 0.08)


def dr_swell(r, dur=1.6, vel=1.0):
	"""Reverse-cymbal style swell that ends on the following downbeat."""
	n = ns(dur)
	t = tvec(n)
	u = t / dur
	s = swept_noise(n, r, 900.0 + 9000.0 * u ** 2, mode="lp")
	s = sfilt(s, hp(500, 1))
	env = u ** 3
	return fades(s * env * vel * 0.5, 0.05, 0.012)


def dr_cymbal(r, vel=1.0, decay=0.9):
	n = ns(decay * 3.0)
	freqs = r.uniform(3000, 12000, 18)
	s = modal(n, freqs, r.uniform(0.3, 1.0, 18), r.uniform(0.3, 1.0, 18) * decay, r) / 6.0
	s += fnoise(n, r, band(5000, 14000, 2)) * env_perc(n, 0.002, decay * 0.6) * 0.5
	return fades(s * vel * 0.6, 0.0, 0.1)


def dr_boom(r, vel=1.0):
	n = ns(2.2)
	t = tvec(n)
	f = 42.0 + 38.0 * np.exp(-t / 0.08)
	s = np.sin(TAU * phase_of(f, n)) * env_perc(n, 0.004, 0.7)
	s += 0.25 * np.sin(2 * TAU * phase_of(f, n)) * env_perc(n, 0.004, 0.25)
	s += fnoise(n, r, lp(500, 2)) * env_perc(n, 0.003, 0.09) * 0.25
	return fades(s * vel, 0.0, 0.2)


# =========================================================================
# Harmony helpers
# =========================================================================

NOTE_PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
		"G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
QUALITIES = {
	"": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11),
	"sus4": (0, 5, 7), "sus2": (0, 2, 7), "add9": (0, 4, 7, 14), "madd9": (0, 3, 7, 14),
	"m9": (0, 3, 7, 10, 14), "6": (0, 4, 7, 9),
}


class Chord:
	def __init__(self, name):
		self.name = name
		bass = None
		if "/" in name:
			name, b = name.split("/")
			bass = NOTE_PC[b]
		root = name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]
		self.root = NOTE_PC[root]
		ivs = QUALITIES[name[len(root):]]
		self.pcs = sorted({(self.root + iv) % 12 for iv in ivs})
		self.core = sorted({(self.root + iv) % 12 for iv in ivs if iv < 12})
		self.bass = self.root if bass is None else bass
		self.fifth = (self.root + 7) % 12

	def tones(self, lo, hi, core=False):
		pcs = self.core if core else self.pcs
		return [m for m in range(lo, hi + 1) if m % 12 in pcs]

	def voicing(self, lo, count=4):
		"""Close voicing of the core triad/7th from `lo`; extensions (9ths) go on top."""
		notes = self.tones(lo, lo + 24, core=True)[:count]
		for pc in self.pcs:
			if pc not in self.core:
				notes.append(self.low(pc, notes[-1] + 1))
		return notes

	def low(self, pc, lo):
		m = lo
		while m % 12 != pc:
			m += 1
		return m


def parse_prog(bars, bpb=4):
	out = []
	for i, s in enumerate(bars):
		parts = s.split("|")
		each = bpb / len(parts)
		for j, p in enumerate(parts):
			out.append((i + 1, j * each, each, Chord(p)))
	return out


def chord_at(prog, bar, beat):
	cur = None
	for b, s, _, c in prog:
		if b < bar or (b == bar and s <= beat + 1e-9):
			cur = c
	return cur


def lint_melody(track, prog, mel):
	"""Warn about held melody notes that clash (a semitone above a chord tone) with the chord."""
	for bar, notes in mel.items():
		for note in notes:
			beat, dur, m = note[0], note[1], note[2]
			if dur >= 1.0 and abs(beat - round(beat)) < 1e-6:
				c = chord_at(prog, bar, beat)
				if m % 12 not in c.pcs and (m - 1) % 12 in c.pcs:
					print("    [lint] %s bar %d beat %.1f: note %d clashes with %s" % (track, bar, beat, m, c.name))


# =========================================================================
# Reverb / delay / loop mixer
# =========================================================================

def make_ir(r, rt60, predelay=0.02, damp=0.5, lowcut=180.0, highcut=9000.0, early=True):
	length = min(rt60 * 1.15, 6.0)
	n = ns(length)
	t = tvec(n)
	size = next_fast(n + 4096)
	spec = np.fft.rfft(r.standard_normal(n), size)
	f = np.fft.rfftfreq(size, 1.0 / SR)
	centers = np.array([200.0, 800.0, 2500.0, 6000.0, 12000.0])
	rts = rt60 * np.array([1.1, 1.0, 0.85, 0.85 - 0.5 * (1 - damp), 0.55 * damp + 0.2])
	ir = np.zeros(n)
	for c, g, rt in zip(centers, band_partition(f, centers), rts):
		ir += np.fft.irfft(spec * g, size)[:n] * np.exp(-6.9078 * t / max(rt, 0.05))
	ir = sfilt(ir, band(lowcut, highcut, 2))
	ir[:ns(0.012)] *= ramp(ns(0.012))
	if early:
		for _ in range(7):
			d = ns(r.uniform(0.004, 0.05))
			ir[d] += r.uniform(-1.0, 1.0) * 0.25 * np.max(np.abs(ir))
	ir = np.concatenate([np.zeros(ns(predelay)), ir])
	return ir / np.sqrt(np.sum(ir * ir))


def circ_conv(x, ir):
	n = x.shape[-1]
	return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, n), n)


def a_weighting(f):
	f2 = np.maximum(f, 1.0) ** 2
	ra = (12194.0 ** 2 * f2 * f2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194.0 ** 2))
	return ra * dbg(2.0)


def a_weighted_rms(x):
	return rms(sfilt(x, a_weighting, circular=True))


def k_weighting(f):
	"""Magnitude of the ITU-R BS.1770 K-weighting pre-filter (high shelf + high-pass) at SR,
	designed the way libebur128 / ffmpeg's ebur128 filter do it."""
	def biquad(b, a):
		z = np.exp(-1j * TAU * f / SR)
		return np.abs((b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z))

	k = np.tan(np.pi * 1681.974450955533 / SR)
	q = 0.7071752369554196
	vh = 10.0 ** (3.999843853973347 / 20.0)
	vb = vh ** 0.4996667741545416
	shelf = biquad([vh + vb * k / q + k * k, 2.0 * (k * k - vh), vh - vb * k / q + k * k],
			[1.0 + k / q + k * k, 2.0 * (k * k - 1.0), 1.0 - k / q + k * k])
	k = np.tan(np.pi * 38.13547087602444 / SR)
	q = 0.5003270373238773
	a0 = 1.0 + k / q + k * k
	highpass = biquad([1.0, -2.0, 1.0], [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0])
	return shelf * highpass


def loudness(x):
	"""Ungated BS.1770 loudness (LUFS) of a loop. Mono counts as played on both speakers,
	as Godot outputs a mono stream at full level on each channel."""
	x = np.atleast_2d(x)
	if x.shape[0] == 1:
		x = np.vstack([x, x])
	y = sfilt(x, k_weighting, circular=True)
	return -0.691 + 10.0 * np.log10(np.sum(np.mean(y * y, axis=-1)) + 1e-20)


def soft_limit(x, ceiling, knee=0.6):
	k = knee * ceiling
	a = np.abs(x)
	y = np.array(x, copy=True)
	m = a > k
	y[m] = np.sign(x[m]) * (k + (ceiling - k) * np.tanh((a[m] - k) / (ceiling - k)))
	return y


# every track is mastered to the same BS.1770 loudness so level changes between menu and maps
# come only from the crossfade
MUSIC_LUFS = -18.0


class Mix:
	"""Stereo loop buffer. Sounds past the loop end are folded onto the start."""

	def __init__(self, name, bpm, bars, bpb=4, tail=7.0):
		self.name = name
		self.bpm = bpm
		self.bars = bars
		self.bpb = bpb
		self.beat = 60.0 / bpm
		exact = bars * bpb * self.beat * SR
		self.L = int(round(exact))
		assert abs(exact - self.L) < 1e-6, "loop length must be a whole number of samples"
		self.N = self.L + ns(tail)
		self.dry = np.zeros((2, self.N))
		self.rev = np.zeros((2, self.N))
		self.dly = np.zeros((2, self.N))
		self.stems = {}
		self.r = rng_for(name)

	def t(self, bar, beat=0.0):
		return ((bar - 1) * self.bpb + beat) * self.beat

	def add(self, sig, at, gain=1.0, pan=0.0, rev=0.25, dly=0.0, stem="misc"):
		if sig.ndim == 1:
			th = (np.clip(pan, -1, 1) + 1.0) * np.pi / 4.0
			st = np.vstack([sig * np.cos(th), sig * np.sin(th)]) * (np.sqrt(2.0) * gain)
		else:
			st = sig * np.array([[min(1.0, 1.0 - pan)], [min(1.0, 1.0 + pan)]]) * gain
		start = ns(at) % self.L
		n = st.shape[1]
		assert start + n <= self.N, "%s: sound at %.2fs is longer than the fold-back tail" % (self.name, at)
		seg = st
		self.dry[:, start:start + n] += seg
		if rev:
			self.rev[:, start:start + n] += seg * rev
		if dly:
			self.dly[:, start:start + n] += seg * dly
		if stem not in self.stems:
			self.stems[stem] = np.zeros(self.N, dtype=np.float32)
		self.stems[stem][start:start + n] += (seg[0] + seg[1]) * 0.5

	def fold(self, buf):
		out = np.array(buf[..., :self.L], copy=True)
		pos = self.L
		while pos < buf.shape[-1]:
			chunk = buf[..., pos:pos + self.L]
			out[..., :chunk.shape[-1]] += chunk
			pos += self.L
		return out

	def render(self, rt60=2.4, predelay=0.025, damp=0.5, delay=(0.75, 1.0, 0.3, 3000.0, 0.3),
			lufs=MUSIC_LUFS, ceiling=-3.5):
		"""Fold, add delay + reverb, then master. `lufs` is the integrated loudness target."""
		L = self.L
		dry = self.fold(self.dry)
		rv = self.fold(self.rev)
		dl = self.fold(self.dly)
		out = dry
		if delay:
			bl, br, fb, damp_hz, to_rev = delay
			k = np.arange(L // 2 + 1)
			f = np.fft.rfftfreq(L, 1.0 / SR)
			dmp = lp(damp_hz, 1)(f) * hp(180.0, 1)(f)
			wet = np.zeros_like(dl)
			for ch, beats in ((0, bl), (1, br)):
				z = np.exp(-2j * np.pi * k * (ns(beats * self.beat) / L))
				h = dmp * z / (1.0 - fb * dmp * z)
				wet[ch] = np.fft.irfft(np.fft.rfft(dl[ch]) * h, L)
			out = out + wet
			rv = rv + wet * to_rev
		r = rng_for(self.name + "/ir")
		for ch in range(2):
			ir = make_ir(r, rt60, predelay + 0.004 * ch, damp)
			out[ch] = out[ch] + circ_conv(rv[ch], ir)
		# master: clean lows, soften the very top, level, gentle limiting
		out = sfilt(out, lambda f: hp(32.0, 2)(f) * lp(12500.0, 1)(f), circular=True)
		out *= dbg(lufs - loudness(out))
		out = soft_limit(out, dbg(ceiling))
		return out

	def stem_report(self):
		"""A-weighted level of each stem relative to the whole dry mix (dB)."""
		tot = a_weighted_rms(self.fold(0.5 * (self.dry[0] + self.dry[1])))
		parts = []
		for k, v in sorted(self.stems.items()):
			lvl = a_weighted_rms(self.fold(v.astype(np.float64))) / tot
			parts.append("%s %.1f" % (k, 20 * np.log10(lvl + 1e-9)))
		return ", ".join(parts)


def melody_notes(mel):
	for bar in sorted(mel):
		for note in mel[bar]:
			vel = note[3] if len(note) > 3 else 1.0
			yield bar, note[0], note[1], note[2], vel


def diatonic_below(m, scale_pcs, steps=2):
	x = m
	for _ in range(steps):
		x -= 1
		while x % 12 not in scale_pcs:
			x -= 1
	return x


# =========================================================================
# Music: menu (calm heroic) — D major, 84 BPM, 16 bars
# =========================================================================

def music_menu():
	m = Mix("menu", 84, 16)
	r = m.r
	prog = parse_prog(["D", "Bm", "G", "A", "D", "Bm", "Em", "A",
			"G", "A", "F#m", "Bm", "G", "D/F#", "Em7", "Asus4|A"])
	horn_a = {
		1: [(0, 1.5, 66), (1.5, 0.5, 69), (2, 2, 74)],
		2: [(0, 1, 74), (1, 1, 73), (2, 2, 71)],
		3: [(0, 1.5, 71), (1.5, 0.5, 69), (2, 1, 67), (3, 1, 71)],
		4: [(0, 3, 69), (3, 0.5, 71), (3.5, 0.5, 73)],
		5: [(0, 1.5, 74), (1.5, 0.5, 76), (2, 2, 78)],
		6: [(0, 1, 78), (1, 1, 76), (2, 1.5, 74), (3.5, 0.5, 71)],
		7: [(0, 1.5, 76), (1.5, 0.5, 74), (2, 1, 71), (3, 1, 67)],
		8: [(0, 3.5, 69)],
	}
	strings_b = {
		9: [(0, 1.5, 74), (1.5, 0.5, 76), (2, 1.5, 79), (3.5, 0.5, 78)],
		10: [(0, 2, 76), (2, 1, 73), (3, 1, 76)],
		11: [(0, 3, 78), (3, 0.5, 76), (3.5, 0.5, 73)],
		12: [(0, 2, 74), (2, 1, 71), (3, 1, 74)],
		13: [(0, 1.5, 79), (1.5, 0.5, 78), (2, 1, 74), (3, 1, 71)],
		14: [(0, 2, 78), (2, 1, 81), (3, 1, 78)],
		15: [(0, 1.5, 79), (1.5, 0.5, 78), (2, 1, 76), (3, 1, 74)],
		16: [(0, 3, 76), (3, 1, 73)],
	}
	lint_melody("menu", prog, horn_a)
	lint_melody("menu", prog, strings_b)
	b = m.beat
	for bar, beat, beats, ch in prog:
		at = m.t(bar, beat)
		m.add(inst_pad(ch.voicing(50, 4), beats * b, r, attack=0.7, release=1.6, cutoff=1600),
				at, gain=0.28, rev=0.35, stem="pad")
		root = ch.low(ch.bass, 36)
		if bar <= 8:
			m.add(inst_bass(root, beats * b * 0.96, r, 0.9), at, gain=0.40, rev=0.08, stem="bass")
		else:
			for k in range(int(beats // 2)):
				note = root if k == 0 else ch.low(ch.fifth, 36)
				m.add(inst_bass(note, 2 * b * 0.9, r, 0.85), at + k * 2 * b, gain=0.40, rev=0.08, stem="bass")
	# harp arpeggio in 8ths
	pattern = [0, 1, 2, 3, 4, 3, 2, 1]
	for bar in range(1, 17):
		for i in range(8):
			ch = chord_at(prog, bar, i * 0.5)
			tones = ch.tones(62, 86, core=True)
			note = tones[min(pattern[i], len(tones) - 1)]
			vel = (0.85 if i % 2 == 0 else 0.68) * (0.75 if bar <= 4 else 1.0)
			m.add(inst_pluck(note, r, vel, dur=1.8, bright=0.5, decay=1.1, pos=0.28), m.t(bar, i * 0.5),
					gain=0.13, pan=0.3, rev=0.3, dly=0.14, stem="harp")
	# melodies
	for bar, beat, dur, note, vel in melody_notes(horn_a):
		m.add(inst_horn(note, dur * b * 0.94, r, vel * 0.95), m.t(bar, beat), gain=0.30, pan=-0.12,
				rev=0.32, dly=0.06, stem="horn")
	for bar, beat, dur, note, vel in melody_notes(strings_b):
		m.add(inst_strings(note, dur * b * 0.96, r, vel), m.t(bar, beat), gain=0.30, pan=0.1,
				rev=0.38, dly=0.05, stem="lead")
		m.add(inst_flute(note, dur * b * 0.92, r, vel * 0.55, breath=0.05), m.t(bar, beat), gain=0.16,
				pan=0.15, rev=0.3, stem="lead")
	# low horn section sustaining chord tones under the B melody
	for bar, beat, beats, ch in prog:
		if bar >= 9:
			t = min(ch.tones(55, 66, core=True), key=lambda x: abs(x - 61))
			m.add(inst_horn(t, beats * b * 0.95, r, 0.55, release=0.4, scoop=0.2, bright=0.35, attack=0.25),
					m.t(bar, beat), gain=0.20, pan=-0.3, rev=0.4, stem="horn")
	# timpani + soft drums
	for bar in range(1, 17):
		ch = chord_at(prog, bar, 0)
		tp = ch.low(ch.root, 41)
		m.add(dr_timp(r, tp, 0.8 if bar > 8 else 0.55, decay=1.0), m.t(bar), gain=0.38, rev=0.25, stem="drums")
		if bar > 8:
			m.add(dr_frame(r, 0.45, 0.9), m.t(bar, 2), gain=0.32, pan=0.15, rev=0.2, stem="drums")
			m.add(dr_frame(r, 0.3, 1.1), m.t(bar, 3.5), gain=0.32, pan=-0.15, rev=0.2, stem="drums")
	for roll_bar in (8, 16):
		ch = chord_at(prog, roll_bar, 2)
		tp = ch.low(ch.root, 41)
		for i in range(8):
			m.add(dr_timp(r, tp, 0.25 + 0.07 * i, decay=0.6), m.t(roll_bar, 2 + i * 0.25), gain=0.30,
					rev=0.25, stem="drums")
		m.add(dr_swell(r, 2 * b, 0.9), m.t(roll_bar + 1) - 2 * b, gain=0.15, rev=0.3, stem="drums")
		m.add(dr_cymbal(r, 0.5, 1.2), m.t(roll_bar + 1), gain=0.10, pan=0.2, rev=0.35, stem="drums")
	print("    stems:", m.stem_report())
	return m.render(rt60=2.6, delay=(0.75, 1.0, 0.28, 2800.0, 0.3))


# =========================================================================
# Music: meadow (bright folk) — G major, 112 BPM, 24 bars
# =========================================================================

def music_meadow():
	m = Mix("meadow", 112, 24)
	r = m.r
	prog_a = ["G", "D", "Em", "C", "G", "D", "C", "D"]
	prog_b = ["C", "D", "Bm", "Em", "Am", "C", "D", "D7"]
	prog_a2 = ["G", "D", "Em", "C", "G", "D", "C", "C|D"]
	prog = parse_prog(prog_a + prog_b + prog_a2)
	mel_a = {
		1: [(0, .5, 74), (.5, .5, 71), (1, .5, 74), (1.5, .5, 79), (2, 1, 83), (3, .5, 81), (3.5, .5, 79)],
		2: [(0, 1, 78), (1, .5, 81), (1.5, .5, 78), (2, 1.5, 74), (3.5, .5, 76)],
		3: [(0, 1, 79), (1, .5, 76), (1.5, .5, 79), (2, 1, 83), (3, .5, 81), (3.5, .5, 79)],
		4: [(0, 1.5, 76), (1.5, .5, 74), (2, 2, 72)],
		5: [(0, .5, 74), (.5, .5, 71), (1, .5, 74), (1.5, .5, 79), (2, 1, 83), (3, .5, 86), (3.5, .5, 83)],
		6: [(0, 1.5, 81), (1.5, .5, 78), (2, 1, 74), (3, 1, 78)],
		7: [(0, 1, 79), (1, 1, 76), (2, 1, 72), (3, 1, 76)],
		8: [(0, 1.5, 78), (1.5, .5, 76), (2, 2, 74)],
	}
	mel_b = {
		9: [(0, 1, 76), (1, 1, 79), (2, 1.5, 84), (3.5, .5, 83)],
		10: [(0, 1, 81), (1, 1, 78), (2, 2, 74)],
		11: [(0, 1, 78), (1, 1, 83), (2, 1, 81), (3, 1, 78)],
		12: [(0, 3, 79), (3, .5, 78), (3.5, .5, 76)],
		13: [(0, 1, 76), (1, 1, 72), (2, 1, 76), (3, 1, 81)],
		14: [(0, 1.5, 79), (1.5, .5, 76), (2, 2, 72)],
		15: [(0, 1, 74), (1, 1, 78), (2, 1, 81), (3, 1, 84)],
		16: [(0, 1.5, 86), (1.5, .5, 84), (2, 1, 81), (3, 1, 78)],
	}
	mel_a2 = {k + 16: v for k, v in mel_a.items()}
	mel_a2[24] = [(0, 2, 76), (2, 1, 78), (3, 1, 81)]
	lint_melody("meadow", prog, mel_a)
	lint_melody("meadow", prog, mel_b)
	lint_melody("meadow", prog, mel_a2)
	b = m.beat
	g_major = {7, 9, 11, 0, 2, 4, 6}
	for bar, beat, beats, ch in prog:
		at = m.t(bar, beat)
		sect_b = 9 <= bar <= 16
		m.add(inst_pad(ch.voicing(55, 4), beats * b, r, attack=0.5, release=1.0, cutoff=2200, detune=6),
				at, gain=0.30 if sect_b else 0.22, rev=0.3, stem="pad")
		root = ch.low(ch.bass, 40)
		five = ch.low(ch.fifth, 40)
		hits = [(0, root), (2, five)] if beats >= 4 else [(0, root)]
		if bar > 8 and beats >= 4:
			hits.append((3.5, root))
		for hb, note in hits:
			m.add(inst_bass(note, 0.9 * b, r, 0.9, kind="pluck"), at + hb * b, gain=0.42, rev=0.08, stem="bass")
	# lute arpeggio
	pattern = [0, 2, 1, 3, 2, 4, 3, 2]
	for bar in range(1, 25):
		for i in range(8):
			ch = chord_at(prog, bar, i * 0.5)
			tones = ch.tones(55, 79, core=True)
			note = tones[min(pattern[i], len(tones) - 1)]
			vel = 0.9 if i % 2 == 0 else 0.7
			m.add(inst_pluck(note, r, vel, dur=1.1, bright=0.62, decay=0.7, pos=0.16, courses=2),
					m.t(bar, i * 0.5), gain=0.21, pan=-0.35, rev=0.2, dly=0.06, stem="lute")
	# flute in A and A', dulcimer in B
	for mel, harmony in ((mel_a, False), (mel_a2, True)):
		for bar, beat, dur, note, vel in melody_notes(mel):
			m.add(inst_flute(note, dur * b * 0.9, r, vel), m.t(bar, beat), gain=0.30, pan=0.12,
					rev=0.25, dly=0.10, stem="flute")
			if harmony:
				low = diatonic_below(note, g_major)
				m.add(inst_flute(low, dur * b * 0.9, r, vel * 0.6, breath=0.04), m.t(bar, beat), gain=0.22,
						pan=-0.25, rev=0.28, stem="flute")
				if beat == 0:
					m.add(inst_bell(note + 12, r, 0.6, 1.4, "glock"), m.t(bar, beat), gain=0.14, pan=0.4,
							rev=0.3, dly=0.15, stem="glock")
	for bar, beat, dur, note, vel in melody_notes(mel_b):
		strikes = max(1, int(round(dur / 0.5))) if dur >= 1.5 else 1
		for s in range(strikes):
			v = vel * (1.0 if s == 0 else 0.55)
			m.add(inst_pluck(note, r, v, dur=1.4, bright=0.82, decay=0.9, pos=0.11, inharm=0.00012, courses=2),
					m.t(bar, beat + s * 0.5), gain=0.36, pan=0.15, rev=0.25, dly=0.12, stem="dulcimer")
		m.add(inst_flute(note - 12, dur * b * 0.9, r, vel * 0.45, breath=0.05), m.t(bar, beat), gain=0.18,
				pan=-0.1, rev=0.3, stem="flute")
	# percussion
	for bar in range(1, 25):
		sect = 0 if bar <= 8 else (1 if bar <= 16 else 2)
		m.add(dr_frame(r, 0.9), m.t(bar, 0), gain=0.5, rev=0.12, stem="drums")
		m.add(dr_frame(r, 0.55, 1.15), m.t(bar, 2), gain=0.5, rev=0.12, stem="drums")
		if sect >= 1:
			m.add(dr_frame(r, 0.3, 1.3), m.t(bar, 1.5), gain=0.5, pan=0.2, rev=0.12, stem="drums")
			m.add(dr_frame(r, 0.3, 1.3), m.t(bar, 3.5), gain=0.5, pan=-0.2, rev=0.12, stem="drums")
		for i in range(8):
			v = (0.55 if i % 2 else 0.35) * (0.7 if sect == 0 else 1.0)
			m.add(dr_shaker(r, v), m.t(bar, i * 0.5), gain=0.16, pan=0.45, rev=0.1, stem="drums")
		if sect == 2:
			for beat in (1, 3):
				m.add(dr_tamb(r, 0.6), m.t(bar, beat), gain=0.15, pan=-0.4, rev=0.15, stem="drums")
	m.add(dr_swell(r, 2 * b, 0.6), m.t(9) - 2 * b, gain=0.14, rev=0.3, stem="drums")
	m.add(dr_swell(r, 2 * b, 0.6), m.t(25) - 2 * b, gain=0.14, rev=0.3, stem="drums")
	print("    stems:", m.stem_report())
	return m.render(rt60=1.8, delay=(0.75, 0.5, 0.22, 3500.0, 0.25))


# =========================================================================
# Music: canyon (western sunset) — A minor pentatonic, 80 BPM, 16 bars
# =========================================================================

def music_canyon():
	m = Mix("canyon", 80, 16)
	r = m.r
	prog = parse_prog(["Am", "G", "F", "E", "Am", "G", "F", "E",
			"Dm", "Am", "Dm", "E", "F", "G", "Am", "E"])
	twang = {
		1: [(0, 1.5, 57), (1.5, .5, 60), (2, 2, 64)],
		2: [(0, 1.5, 62), (1.5, .5, 59), (2, 2, 55)],
		3: [(0, 1.5, 57), (1.5, .5, 60), (2, 1, 65), (3, 1, 64)],
		4: [(0, 2, 59), (2, 2, 56)],
		9: [(0, 1.5, 62), (1.5, .5, 65), (2, 2, 69)],
		10: [(0, 1.5, 64), (1.5, .5, 60), (2, 2, 57)],
		11: [(0, 1, 62), (1, 1, 65), (2, 1, 69), (3, 1, 65)],
		12: [(0, 3, 64), (3, 1, 59)],
	}
	whistle = {
		5: [(0, 2.5, 76), (2.5, .5, 74), (3, 1, 72)],
		6: [(0, 1.5, 74), (1.5, .5, 72), (2, 2, 67)],
		7: [(0, 1, 69), (1, 1, 72), (2, 1.5, 76), (3.5, .5, 74)],
		8: [(0, 2, 71), (2, 1, 68), (3, 1, 64)],
		13: [(0, 2, 81), (2, 1, 77), (3, 1, 72)],
		14: [(0, 1.5, 74), (1.5, .5, 76), (2, 2, 79)],
		15: [(0, 3, 81), (3, 1, 76)],
		16: [(0, 2, 80), (2, 1, 76), (3, 1, 71)],
	}
	lint_melody("canyon", prog, twang)
	lint_melody("canyon", prog, whistle)
	b = m.beat
	for bar, beat, beats, ch in prog:
		at = m.t(bar, beat)
		m.add(inst_pad(ch.voicing(52, 3), beats * b, r, attack=1.0, release=1.5, cutoff=1200, detune=5),
				at, gain=0.30 if bar > 4 else 0.2, rev=0.35, stem="pad")
		root = ch.low(ch.bass, 33)
		if bar <= 4:
			m.add(inst_bass(root, beats * b * 0.9, r, 0.85, kind="pluck"), at, gain=0.6, rev=0.1, stem="bass")
		else:
			m.add(inst_bass(root, 1.8 * b, r, 0.9, kind="pluck"), at, gain=0.6, rev=0.1, stem="bass")
			m.add(inst_bass(ch.low(ch.fifth, 33), 1.6 * b, r, 0.75, kind="pluck"), at + 2 * b, gain=0.6,
					rev=0.1, stem="bass")
	# fingerpicked guitar, triplet feel
	for bar in range(1, 17):
		ch = chord_at(prog, bar, 0)
		mids = ch.tones(55, 74, core=True)
		for beat in range(4):
			bass_note = ch.low(ch.root if beat % 2 == 0 else ch.fifth, 40)
			picks = [bass_note, mids[min(1 + beat % 2, len(mids) - 1)], mids[min(2 + beat % 2, len(mids) - 1)]]
			for j, note in enumerate(picks):
				vel = 0.9 if j == 0 else (0.62 if j == 1 else 0.55)
				m.add(inst_pluck(note, r, vel, dur=1.6, bright=0.6, decay=1.3, pos=0.13, inharm=0.00006),
						m.t(bar, beat + j / 3.0), gain=0.17, pan=-0.3, rev=0.25, dly=0.05, stem="guitar")
	# baritone twang melody with tremolo
	for bar, beat, dur, note, vel in melody_notes(twang):
		s = inst_pluck(note, r, vel, dur=dur * b + 1.2, bright=0.72, decay=1.6, pos=0.09, inharm=0.00004)
		t = tvec(len(s))
		s *= 1.0 - 0.35 * (0.5 + 0.5 * np.sin(TAU * 6.0 * t - np.pi / 2))
		s *= env_note(len(s), 0.002, dur * b * 1.05, 0.5)
		m.add(s, m.t(bar, beat), gain=0.36, pan=0.2, rev=0.42, dly=0.22, stem="twang")
	for bar, beat, dur, note, vel in melody_notes(whistle):
		m.add(inst_whistle(note, dur * b * 0.92, r, vel), m.t(bar, beat), gain=0.26, pan=0.08,
				rev=0.38, dly=0.2, stem="whistle")
	# clip-clop + soft kick + shaker
	for bar in range(1, 17):
		for beat in range(4):
			m.add(dr_wood(r, 0.55, 880.0), m.t(bar, beat), gain=0.26, pan=-0.2, rev=0.15, stem="drums")
			m.add(dr_wood(r, 0.4, 640.0), m.t(bar, beat + 2 / 3.0), gain=0.26, pan=-0.25, rev=0.15, stem="drums")
			if bar > 4:
				for j in range(3):
					m.add(dr_shaker(r, 0.45 if j == 0 else 0.3, 0.1), m.t(bar, beat + j / 3.0), gain=0.1,
							pan=0.4, rev=0.1, stem="drums")
		if bar > 4:
			m.add(dr_kick(r, 0.7, 100.0, 45.0, 0.25), m.t(bar, 0), gain=0.4, rev=0.08, stem="drums")
			m.add(dr_kick(r, 0.5, 100.0, 45.0, 0.25), m.t(bar, 2), gain=0.4, rev=0.08, stem="drums")
	m.add(dr_swell(r, 2 * b, 0.7), m.t(17) - 2 * b, gain=0.12, rev=0.3, stem="drums")
	# desert wind (periodic in the loop)
	loop_s = m.L / SR
	t = tvec(m.L)
	center = 650.0 * 2.0 ** (0.8 * np.sin(TAU * 3.0 / loop_s * t))
	wind = swept_noise(m.L, rng_for("canyon/wind"), center, mode="bp", q=2.5, circular=True)
	wind *= 0.55 + 0.45 * np.sin(TAU * 2.0 / loop_s * t + 1.0)
	m.add(np.vstack([wind, np.roll(wind, ns(0.37))]), 0.0, gain=0.028, rev=0.0, stem="wind")
	print("    stems:", m.stem_report())
	return m.render(rt60=2.8, delay=(0.75, 1.0, 0.33, 2600.0, 0.35))


# =========================================================================
# Music: frost (mystic icy night) — E minor, 70 BPM, 16 bars
# =========================================================================

def music_frost():
	m = Mix("frost", 70, 16)
	r = m.r
	prog = parse_prog(["Emadd9", "Cmaj7", "Am9", "Bsus4|B", "Em", "Cmaj7", "G", "D/F#",
			"Em", "Cmaj7", "Am", "B7", "C", "Am", "Bsus4", "B"])
	bells = {
		5: [(0, 2, 83), (2, 1, 79), (3, 1, 78)],
		6: [(0, 2, 79), (2, 2, 83)],
		7: [(0, 1, 86), (1, 1, 83), (2, 2, 79)],
		8: [(0, 3, 81), (3, 1, 78)],
		9: [(0, 1.5, 76), (1.5, .5, 78), (2, 2, 79)],
		10: [(0, 2, 83), (2, 1, 84), (3, 1, 83)],
		11: [(0, 2, 81), (2, 1, 76), (3, 1, 79)],
		12: [(0, 3, 78), (3, 1, 75)],
		13: [(0, 2, 76), (2, 1, 79), (3, 1, 84)],
		14: [(0, 2, 83), (2, 2, 81)],
		15: [(0, 2, 83), (2, 2, 76)],
		16: [(0, 2, 78), (2, 2, 75)],
	}
	lint_melody("frost", prog, bells)
	b = m.beat
	for bar, beat, beats, ch in prog:
		at = m.t(bar, beat)
		m.add(inst_pad(ch.voicing(52, 4), beats * b, r, attack=1.6, release=2.6, kind="glass", detune=6),
				at, gain=0.38, rev=0.5, stem="pad")
		if bar >= 9:
			m.add(inst_pad(ch.voicing(59, 3), beats * b, r, attack=1.4, release=2.2, kind="choir", detune=8),
					at, gain=0.30, rev=0.55, stem="choir")
		m.add(inst_bass(ch.low(ch.bass, 38), beats * b * 0.95, r, 0.9, kind="sub", release=1.2), at,
				gain=0.30, rev=0.1, stem="bass")
	# celesta arpeggio (8ths)
	pats = ([0, 1, 2, 3, 4, 3, 2, 1], [0, 2, 1, 3, 2, 4, 3, 1])
	for bar in range(1, 17):
		pattern = pats[(bar - 1) // 4 % 2]
		for i in range(8):
			ch = chord_at(prog, bar, i * 0.5)
			tones = ch.tones(71, 91)
			note = tones[min(pattern[i], len(tones) - 1)]
			vel = (0.8 if i % 2 == 0 else 0.6) * (0.8 if bar <= 4 else 1.0)
			m.add(inst_bell(note, r, vel, 2.2, "celesta"), m.t(bar, i * 0.5), gain=0.11,
					pan=-0.3 + 0.6 * (i % 2), rev=0.45, dly=0.22, stem="celesta")
	for bar, beat, dur, note, vel in melody_notes(bells):
		m.add(inst_bell(note, r, vel, 3.2, "celesta"), m.t(bar, beat), gain=0.30, pan=0.05, rev=0.45,
				dly=0.18, stem="melody")
		m.add(inst_flute(note - 12, dur * b * 0.92, r, vel * 0.5, breath=0.09, attack=0.12), m.t(bar, beat),
				gain=0.16, pan=-0.1, rev=0.5, stem="melody")
	# wind chimes from E minor pentatonic
	cr = rng_for("frost/chimes")
	chime_notes = [88, 91, 93, 95, 98, 100]
	for bar in range(1, 17):
		for _ in range(2):
			if cr.random() < 0.7:
				beat = float(cr.integers(0, 16)) * 0.25
				m.add(inst_bell(int(cr.choice(chime_notes)), cr, cr.uniform(0.3, 0.7), 3.0, "chime"),
						m.t(bar, beat), gain=0.08, pan=cr.uniform(-0.8, 0.8), rev=0.6, dly=0.1, stem="chimes")
	for bar in (1, 5, 9, 13):
		m.add(dr_boom(r, 0.8), m.t(bar), gain=0.40, rev=0.3, stem="drums")
		m.add(dr_swell(r, 2 * b, 0.7), m.t(bar) - 2 * b, gain=0.16, rev=0.45, stem="drums")
	for bar in range(9, 17):
		m.add(dr_frame(r, 0.25, 0.8), m.t(bar, 2.5), gain=0.30, pan=0.2, rev=0.35, stem="drums")
	# icy wind (periodic in the loop)
	loop_s = m.L / SR
	t = tvec(m.L)
	center = 2600.0 * 2.0 ** (0.9 * np.sin(TAU * 2.0 / loop_s * t))
	wind = swept_noise(m.L, rng_for("frost/wind"), center, mode="bp", q=3.0, circular=True)
	wind *= 0.5 + 0.5 * np.sin(TAU * 3.0 / loop_s * t + 2.0)
	m.add(np.vstack([wind, np.roll(wind, ns(0.53))]), 0.0, gain=0.025, rev=0.0, stem="wind")
	print("    stems:", m.stem_report())
	return m.render(rt60=4.2, damp=0.65, delay=(0.75, 1.5, 0.42, 3200.0, 0.4))


# =========================================================================
# Sound effects
# =========================================================================

def sfx_arrow():
	r = rng_for("arrow")
	n = ns(0.46)
	t = tvec(n)
	f = 150.0 * (1.0 + 0.07 * np.exp(-t / 0.025))
	cyc = phase_of(f, n)
	tw = np.zeros(n)
	for k in range(1, 16):
		a = (abs(np.sin(np.pi * k * 0.13)) + 0.05) / k ** 0.9
		tw += a * np.sin(TAU * k * cyc + r.uniform(0, TAU)) * np.exp(-t / (0.16 / (1 + 0.35 * (k - 1))))
	tw = tw / np.max(np.abs(tw)) * ramp_env(n, 0.0015)
	slap = fnoise(n, r, band(900, 4000, 1)) * env_perc(n, 0.0005, 0.006)
	wh = swept_noise(n, r, 700.0 + 2600.0 * np.exp(-t / 0.16), mode="bp", q=1.6)
	wenv = np.clip(t / 0.06, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 0.07, 0) / 0.1)
	return 0.9 * tw + 0.25 * slap + 0.35 * wh * wenv


def sfx_cannon():
	r = rng_for("cannon")
	n = ns(1.0)
	t = tvec(n)
	boom = np.sin(TAU * phase_of(42.0 + 70.0 * np.exp(-t / 0.07), n)) * env_perc(n, 0.002, 0.28)
	punch = np.sin(TAU * phase_of(95.0 + 170.0 * np.exp(-t / 0.025), n)) * env_perc(n, 0.001, 0.085)
	crack = fnoise(n, r, lp(4000, 2)) * env_perc(n, 0.0008, 0.02)
	body = fnoise(n, r, band(150, 1200, 2)) * env_perc(n, 0.004, 0.12)
	rumble = fnoise(n, r, band(60, 450, 2)) * env_perc(n, 0.02, 0.28)
	x = 0.7 * boom + 0.9 * punch + 0.45 * crack + 0.6 * body + 0.4 * rumble
	return np.tanh(2.2 * x)


def sfx_explosion():
	r = rng_for("explosion")
	n = ns(0.9)
	t = tvec(n)
	burst = swept_noise(n, r, 220.0 + 5200.0 * np.exp(-t / 0.08), mode="lp")
	env = 0.75 * env_perc(n, 0.003, 0.1) + 0.45 * env_perc(n, 0.012, 0.32)
	sub = np.sin(TAU * phase_of(34.0 + 62.0 * np.exp(-t / 0.06), n)) * env_perc(n, 0.002, 0.25)
	crackle = np.zeros(n)
	times = np.sort(r.exponential(0.14, 45)) + 0.02
	for tc in times:
		if tc > 0.6:
			continue
		m = ns(0.03)
		tt = tvec(m)
		pop = np.sin(TAU * r.uniform(800, 3500) * tt) * np.exp(-tt / 0.004) * r.uniform(0.4, 1.0)
		place(crackle, pop * np.exp(-tc / 0.25), ns(tc))
	x = 0.85 * burst * env + 0.7 * sub + 0.3 * crackle
	return np.tanh(1.5 * x)


def sfx_frost():
	r = rng_for("frost")
	n = ns(0.85)
	t = tvec(n)
	ratios, amps, decays = [1.0, 2.76, 5.4], [1.0, 0.45, 0.2], [0.42, 0.18, 0.08]
	chime = np.zeros(n)
	for t0, f0, g in ((0.0, 1760.0, 1.0), (0.035, 2637.0, 0.75), (0.07, 3520.0, 0.4)):
		c = modal(n - ns(t0), [f0 * q for q in ratios] + [f0 + 4.0], amps + [0.5], decays + [0.4], r)
		place(chime, c * g, ns(t0))
	crack = np.zeros(n)
	for _ in range(18):
		tc = r.uniform(0.0, 0.28)
		m = ns(0.02)
		tt = tvec(m)
		tick = np.sin(TAU * r.uniform(3500, 9000) * tt) * np.exp(-tt / r.uniform(0.002, 0.005))
		place(crack, tick * r.uniform(0.3, 1.0) * (1.0 - tc / 0.35), ns(tc))
	air = fnoise(n, r, band(4500, 12000, 2)) * env_perc(n, 0.02, 0.15)
	return 0.75 * chime + 0.5 * crack + 0.1 * air


def sfx_tesla():
	r = rng_for("tesla")
	n = ns(0.45)
	t = tvec(n)
	seg = ns(0.006)
	jit = r.uniform(-1.0, 1.0, n // seg + 2)
	f = 95.0 * 2.0 ** (0.4 * sfilt(np.repeat(jit, seg)[:n], lp(200, 1)))
	buzz = table_read(harmonic_table(saw_amps(95.0 * 1.35, 8000.0)), phase_of(f, n))
	gate = np.zeros(n)
	pos = 0
	while pos < n:
		length = int(r.integers(ns(0.003), ns(0.016)))
		p_on = 0.9 - 0.6 * (pos / n)
		if r.random() < p_on:
			seg_env = np.ones(length)
			a = min(ns(0.001), length // 2)
			seg_env[:a] = ramp(a)
			seg_env[length - a:] = ramp(a)[::-1]
			place(gate, seg_env * r.uniform(0.5, 1.0), pos)
		pos += length
	crack = fnoise(n, r, band(1500, 7500, 2))
	env = env_perc(n, 0.001, 0.14)
	zap_cyc = phase_of(400.0 + 2600.0 * np.exp(-t / 0.02), n)
	zap = (np.sin(TAU * zap_cyc) + 0.3 * np.sin(3 * TAU * zap_cyc)) * env_perc(n, 0.001, 0.035)
	return (0.55 * buzz * gate + 0.4 * crack * gate) * env + 0.5 * zap


def sfx_laser():
	"""Seamless 1.0 s loop: integer-Hz partials and circularly filtered noise."""
	r = rng_for("laser")
	n = SR
	t = np.arange(n) / SR
	hum = np.zeros(n)
	# buzzy beam: a 900 Hz / 2 kHz formant over a 110 Hz series keeps most of the energy in the
	# range phone speakers reproduce; only a light 55 Hz sub remains for headphones
	formants = [(900.0, 1.0, 1.1), (2000.0, 0.45, 1.5)]
	for f0, g in ((110, 1.0), (111, 0.6)):
		for k in range(1, 31):
			fk = float(f0 * k)
			amp = formant_gain(np.array([fk]), formants, 0.3)[0] / k ** 0.85 * lp(3000.0, 2)(fk)
			hum += g * np.sin(TAU * fk * t + r.uniform(0, TAU)) * amp
	hum += 0.12 * np.sin(TAU * 55 * t)
	shimmer = 0.12 * (np.sin(TAU * 1320 * t) + np.sin(TAU * 1324 * t + 1.0)) * (0.6 + 0.4 * np.sin(TAU * 6 * t))
	sizzle = fnoise(n, r, band(1500, 5000, 2), circular=True) * 0.06 * (0.7 + 0.3 * np.sin(TAU * 12 * t))
	return hum * (1.0 + 0.12 * np.sin(TAU * 7 * t)) + shimmer + sizzle


def sfx_hit():
	r = rng_for("hit")
	n = ns(0.2)
	t = tvec(n)
	body = np.sin(TAU * phase_of(115.0 + 110.0 * np.exp(-t / 0.018), n)) * env_perc(n, 0.001, 0.05)
	knock = fnoise(n, r, band(300, 2000, 2)) * env_perc(n, 0.0005, 0.012)
	mid = np.sin(TAU * phase_of(380.0 - 80.0 * np.clip(t / 0.04, 0, 1), n)) * env_perc(n, 0.001, 0.028)
	return np.tanh(1.6 * (0.8 * body + 0.45 * knock + 0.55 * mid))


def sfx_death():
	r = rng_for("death")
	n = ns(0.36)
	t = tvec(n)
	pop = np.sin(TAU * phase_of(380.0 * 2.0 ** (1.6 * np.clip(t / 0.075, 0, 1)), n)) * env_perc(n, 0.002, 0.045)
	sq = swept_noise(n, r, 500.0 + 900.0 * np.exp(-t / 0.06), mode="bp", q=2.5)
	sq *= (0.6 + 0.4 * np.sin(TAU * 32.0 * t)) * env_perc(n, 0.004, 0.07)
	t2 = np.maximum(t - 0.05, 0.0)
	boop = np.sin(TAU * phase_of(900.0 * 2.0 ** (-np.clip(t2 / 0.12, 0, 1)), n))
	boop_env = np.exp(-t2 / 0.06) * np.clip(t2 / 0.005, 0, 1) * (t >= 0.05)
	return 0.8 * pop + 0.35 * sq + 0.4 * boop * boop_env


def coin_tone(freq, n, decay, r):
	return modal(n, [freq, 2 * freq, 3 * freq, 4.16 * freq], [1.0, 0.4, 0.18, 0.1],
			[decay, decay * 0.6, decay * 0.4, decay * 0.3], r, attack=0.0015)


def sfx_coin():
	r = rng_for("coin")
	n = ns(0.5)
	x = np.zeros(n)
	a = coin_tone(987.77, ns(0.09), 0.06, r)
	place(x, fades(a, 0.0, 0.012) * 0.8, 0)
	place(x, coin_tone(1318.51, n - ns(0.075), 0.17, r), ns(0.075))
	return x


def sfx_build():
	r = rng_for("build")
	n = ns(0.7)
	x = np.zeros(n)

	def thunk(scale):
		# stone/wood knock: the 400-1500 Hz modes carry it on phone speakers, the 85 Hz drop adds weight
		m = ns(0.35)
		s = modal(m, [170 * scale, 410 * scale, 655 * scale, 1020 * scale, 1480 * scale], [0.75, 0.6, 0.5, 0.4, 0.25],
				[0.1, 0.06, 0.045, 0.03, 0.02], r, attack=0.0008)
		s += fnoise(m, r, band(700, 3500, 1)) * env_perc(m, 0.0005, 0.007) * 0.8
		tt = tvec(m)
		s += 0.5 * np.sin(TAU * phase_of(85.0 * scale * (1 + 0.3 * np.exp(-tt / 0.01)), m)) * env_perc(m, 0.001, 0.05)
		return s

	place(x, thunk(1.0), 0)
	place(x, thunk(1.25) * 0.6, ns(0.1))
	for i, f in enumerate((2093.0, 2637.0, 3136.0, 4186.0)):
		p = modal(ns(0.4), [f, f * 2.76], [1.0, 0.2], [0.12, 0.05], r)
		place(x, p * 0.3 * (1.0 - 0.15 * i), ns(0.17 + 0.04 * i))
	# soft saturation tames the knock's peak so the whole sound sits louder at the same peak level
	return np.tanh(2.0 * x / np.max(np.abs(x)))


def sfx_upgrade():
	r = rng_for("upgrade")
	n = ns(0.9)
	t = tvec(n)
	x = np.zeros(n)
	notes = [523.25, 659.25, 783.99, 1046.5, 1318.51, 1567.98]
	for i, f in enumerate(notes):
		d = 0.25 if i < len(notes) - 1 else 0.33
		m = n - ns(i * 0.065)
		s = modal(m, [f, 2 * f, 3 * f, f * 1.004], [1.0, 0.3, 0.1, 0.6], [d, d * 0.5, d * 0.3, d], r)
		place(x, s * (0.55 + 0.09 * i), ns(i * 0.065))
	whoosh = swept_noise(n, r, 800.0 * 2.0 ** (2.6 * np.clip(t / 0.45, 0, 1)), mode="bp", q=1.2)
	whoosh *= np.clip(t / 0.3, 0, 1) * np.exp(-np.maximum(t - 0.3, 0) / 0.12) * 0.12
	tail = np.zeros(n)
	for f in (1046.5, 1318.51, 1567.98):
		tail += np.sin(TAU * f * t)
	tail *= (0.6 + 0.4 * np.sin(TAU * 14.0 * t)) * np.exp(-np.maximum(t - 0.35, 0) / 0.18)
	tail *= np.clip((t - 0.33) / 0.05, 0, 1) * 0.08
	return x + whoosh + tail


def sfx_sell():
	r = rng_for("sell")
	n = ns(0.7)
	x = np.zeros(n)
	for i, f in enumerate((1567.98, 1318.51, 1046.5, 783.99)):
		d = 0.12 if i < 3 else 0.25
		place(x, coin_tone(f, n - ns(i * 0.07), d, r) * (1.0 - 0.08 * i), ns(i * 0.07))
	for _ in range(7):
		tc = r.uniform(0.0, 0.3)
		f = r.uniform(3000, 6500)
		p = modal(ns(0.15), [f, f * 1.48, f * 2.1], [1.0, 0.6, 0.3], [0.05, 0.035, 0.025], r)
		place(x, p * r.uniform(0.1, 0.2), ns(tc))
	return x


def horn_call(n, r, f0, t_start, t_end, release=0.28, scoop=1.8, fall=0.6, growl=0.04, layers=((1.0, 1.0),)):
	t = tvec(n)
	tl = np.maximum(t - t_start, 0.0)
	f = f0 * 2.0 ** ((-scoop / 12.0) * np.exp(-tl / 0.07))
	f *= vibrato(n, r, 5.2, 0.004, t_start + 0.35, 0.3)
	f *= 2.0 ** (-(fall / 12.0) * np.clip((t - (t_end - 0.25)) / 0.35, 0, 1))
	amp = np.zeros(n)
	seg = env_note(n - ns(t_start), 0.09, t_end - t_start, release, sustain=0.85, settle=0.3)
	place(amp, seg, ns(t_start))
	amp *= 1.0 + 0.15 * np.clip((t - t_start - 0.2) / 0.6, 0, 1)
	amp *= 1.0 + growl * np.sin(TAU * 31.0 * t)
	out = np.zeros(n)
	for ratio, g in layers:
		out += g * brass_voice(f * ratio, 0.35 + 0.55 * amp, r, f0 * ratio)
	breath = fnoise(n, r, band(800, 3000, 1)) * 0.03
	return (out + breath) * amp


def sfx_wave():
	r = rng_for("wave")
	n = ns(1.35)
	return horn_call(n, r, 146.83, 0.0, 1.05, layers=((1.0, 1.0), (1.0035, 0.6), (0.5, 0.45)))


def sfx_boss():
	r = rng_for("boss")
	n = ns(1.85)
	t = tvec(n)

	def taiko(vel):
		m = ns(1.2)
		tt = tvec(m)
		s = np.sin(TAU * phase_of(48.0 + 50.0 * np.exp(-tt / 0.05), m)) * env_perc(m, 0.002, 0.42)
		s += fnoise(m, r, band(200, 1400, 1)) * env_perc(m, 0.001, 0.03) * 0.5
		s += np.sin(TAU * phase_of(150.0 + 90.0 * np.exp(-tt / 0.02), m)) * env_perc(m, 0.001, 0.06) * 0.7
		return s * vel

	drum = np.zeros(n)
	place(drum, taiko(1.0), 0)
	place(drum, taiko(0.55), ns(0.32))
	horn = horn_call(n, r, 73.42, 0.12, 1.45, release=0.35, scoop=1.5, fall=0.8, growl=0.08,
			layers=((1.0, 0.8), (1.5, 0.6), (2.0, 0.65), (1.004, 0.5), (3.0, 0.25)))
	return np.tanh(1.4 * (0.8 * drum + 1.1 * horn / 1.6))


def sfx_leak():
	r = rng_for("leak")
	n = ns(0.7)
	t = tvec(n)
	thud = np.sin(TAU * phase_of(70.0 + 80.0 * np.exp(-t / 0.03), n)) * env_perc(n, 0.002, 0.12)
	thud += fnoise(n, r, band(250, 2000, 1)) * env_perc(n, 0.001, 0.02) * 0.5
	x = 0.6 * thud
	for t0, fa, fb, g in ((0.0, 233.0, 175.0, 1.0), (0.24, 196.0, 147.0, 0.8)):
		m = ns(0.35)
		tt = tvec(m)
		f = fa * (fb / fa) ** np.clip(tt / 0.25, 0, 1)
		# brassy "bwaa": full harmonic series with a ~1 kHz formant so it reads on phone speakers
		k = np.arange(1, 25)
		amps = formant_gain(k * fa, [(950.0, 1.0, 1.3), (2300.0, 0.35, 1.8)], 0.2) / k ** 0.8 * lp(4200, 2)(k * fa)
		bw = table_read(harmonic_table(amps), phase_of(f, m)) * env_note(m, 0.01, 0.2, 0.1, sustain=0.7, settle=0.08)
		place(x, 0.7 * g * bw, ns(t0))
	return np.tanh(1.8 * x / np.max(np.abs(x)))


def small_reverb(x, name, rt60=1.2, wet=0.18):
	ir = make_ir(rng_for(name + "/ir"), rt60, 0.015, 0.5, lowcut=250.0)
	size = next_fast(len(x) + len(ir))
	y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x)]
	return x + wet * y


def sfx_victory():
	r = rng_for("victory")
	n = ns(3.2)
	x = np.zeros(n)
	lead = [(0.00, 0.11, 67), (0.13, 0.11, 72), (0.26, 0.11, 76), (0.39, 0.36, 79),
			(0.80, 0.11, 76), (0.94, 0.11, 79), (1.08, 1.45, 84)]
	for t0, d, m in lead:
		place(x, inst_trumpet(m, d, r, 1.0) * 0.55, ns(t0))
		place(x, inst_trumpet(m - 12, d, r, 0.7) * 0.25, ns(t0))
	for m in (60, 64, 67, 72):
		place(x, inst_horn(m, 1.45, r, 0.7, release=0.5, scoop=0.3, bright=0.5, attack=0.05) * 0.22, ns(1.08))
	for t0, d, m in ((0.0, 0.35, 48), (0.39, 0.4, 43), (1.08, 1.5, 36)):
		place(x, inst_bass(m, d, r, 1.0) * 0.35, ns(t0))
	place(x, dr_timp(r, 43, 0.7, 0.6) * 0.5, ns(0.39))
	place(x, dr_timp(r, 48, 1.0, 0.9) * 0.6, ns(1.08))
	gl = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96]
	for i, m in enumerate(gl):
		place(x, inst_pluck(m, r, 0.5 + 0.03 * i, dur=1.2, bright=0.6, decay=0.8) * 0.18, ns(1.1 + i * 0.028))
	cr = rng_for("victory/sparkle")
	for i in range(9):
		m = int(cr.choice([84, 88, 91, 96, 100]))
		place(x, inst_bell(m, cr, cr.uniform(0.3, 0.6), 1.2, "glock") * 0.12, ns(1.3 + i * 0.13 + cr.uniform(0, 0.05)))
	place(x, dr_cymbal(r, 0.6, 1.1) * 0.35, ns(1.08))
	return small_reverb(x, "victory", 1.4, 0.2)


def sfx_defeat():
	r = rng_for("defeat")
	n = ns(3.25)
	x = np.zeros(n)
	lead = [(0.0, 0.42, 76), (0.45, 0.42, 74), (0.9, 0.42, 72), (1.35, 0.55, 71), (1.95, 1.0, 69)]
	for t0, d, m in lead:
		place(x, inst_flute(m, d, r, 0.9, release=0.25, breath=0.06, attack=0.06) * 0.5, ns(t0))
		place(x, inst_horn(m - 12, d, r, 0.6, release=0.3, scoop=0.2, bright=0.25, attack=0.08) * 0.25, ns(t0))
	chords = [(0.0, 0.9, [57, 60, 64]), (0.9, 0.45, [53, 57, 60]), (1.35, 0.6, [52, 56, 59]),
			(1.95, 1.0, [45, 52, 57, 60])]
	for t0, d, ms in chords:
		pad = inst_pad(ms, d, r, attack=0.15, release=0.5, cutoff=1500, detune=6)
		place(x, (pad[0] + pad[1]) * 0.35, ns(t0))
	for t0, d, m in ((0.0, 0.85, 45), (0.9, 0.4, 41), (1.35, 0.55, 40), (1.95, 1.0, 33)):
		place(x, inst_bass(m, d, r, 0.9) * 0.3, ns(t0))
	place(x, dr_timp(r, 33, 0.7, 1.0) * 0.45, ns(1.95))
	x = small_reverb(x, "defeat", 1.6, 0.22)
	return x * env_note(n, 0.0, 2.75, 0.45)


def sfx_click():
	r = rng_for("click")
	n = ns(0.06)
	t = tvec(n)
	blip = np.sin(TAU * 1650.0 * t) * env_perc(n, 0.0006, 0.009)
	tick = fnoise(n, r, band(2000, 6000, 1)) * env_perc(n, 0.0002, 0.0018)
	low = np.sin(TAU * 420.0 * t) * env_perc(n, 0.001, 0.012)
	return 0.8 * blip + 0.35 * tick + 0.35 * low


def sfx_error():
	n = ns(0.36)
	x = np.zeros(n)
	for t0, f in ((0.0, 140.0), (0.17, 125.0)):
		m = ns(0.16)
		amps = saw_amps(f, 6000.0, 2200.0, 2, slope=0.75)
		amps[0] *= 0.45
		amps[1::2] *= 0.4
		s = table_read(harmonic_table(amps), phase_of(f, m)) * env_note(m, 0.008, 0.11, 0.035, sustain=0.85, settle=0.05)
		place(x, s, ns(t0))
	return x


SFX = {
	"arrow": sfx_arrow, "cannon": sfx_cannon, "explosion": sfx_explosion, "frost": sfx_frost,
	"tesla": sfx_tesla, "laser": sfx_laser, "hit": sfx_hit, "death": sfx_death, "coin": sfx_coin,
	"build": sfx_build, "upgrade": sfx_upgrade, "sell": sfx_sell, "wave": sfx_wave, "boss": sfx_boss,
	"leak": sfx_leak, "victory": sfx_victory, "defeat": sfx_defeat, "click": sfx_click, "error": sfx_error,
}
# loudness (LUFS) of looped SFX; audio.gd plays the laser at -9 dB on the SFX bus, which puts the
# hum a few dB under the music on headphones and roughly level with it on a phone speaker
LOOPED_SFX = {"laser": -14.0}
# fade-out length (s) for sounds whose tails are still ringing at the end
SFX_FADE_OUT = {"upgrade": 0.15, "sell": 0.12, "frost": 0.12, "boss": 0.12, "victory": 0.3, "defeat": 0.3}
MUSIC = {"menu": music_menu, "meadow": music_meadow, "canyon": music_canyon, "frost": music_frost}


# =========================================================================
# Output
# =========================================================================

def finalize_sfx(x, peak_db=-3.0, fade_out=0.03):
	x = dc_block(np.asarray(x, dtype=np.float64))
	x = fades(x, 0.001, min(fade_out, len(x) / SR * 0.25))
	return x * (dbg(peak_db) / (np.max(np.abs(x)) + 1e-12))


def finalize_loop(x, lufs, max_peak_db=-3.0):
	"""Level a looping sound by loudness, not peak: it plays continuously under the music."""
	x = sfilt(x - np.mean(x), hp(25.0, 2), circular=True)
	x = x * dbg(lufs - loudness(x))
	peak = 20.0 * np.log10(np.max(np.abs(x)) + 1e-12)
	assert peak <= max_peak_db, "loop peaks at %.1f dBFS at %.1f LUFS" % (peak, lufs)
	return x


def write_wav(path, x):
	pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())


def write_ogg(path, data, quality):
	data = np.atleast_2d(data)
	pcm = np.ascontiguousarray(data.T.astype("<f4"))
	cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
			"-f", "f32le", "-ar", str(SR), "-ac", str(data.shape[0]), "-i", "pipe:0",
			"-c:a", "libvorbis", "-q:a", str(quality), "-map_metadata", "-1",
			"-fflags", "+bitexact", "-flags:a", "+bitexact", path]
	subprocess.run(cmd, input=pcm.tobytes(), check=True)


def decoded_frames(path, channels):
	cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", str(channels), "pipe:1"]
	raw = subprocess.run(cmd, capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype="<f4").reshape(-1, channels).T


def loop_click_metric(x):
	"""Jump across the loop seam relative to typical sample-to-sample motion."""
	x = np.atleast_2d(x)
	seam = np.max(np.abs(x[:, 0] - x[:, -1]))
	typical = np.percentile(np.abs(np.diff(x, axis=1)), 99)
	return seam / (typical + 1e-12)


def main(argv):
	only = set(argv)
	unknown = only - set(SFX) - set(MUSIC)
	if unknown:
		sys.exit("unknown names: %s" % ", ".join(sorted(unknown)))
	os.makedirs(SFX_DIR, exist_ok=True)
	os.makedirs(MUSIC_DIR, exist_ok=True)
	total = 0
	for name, fn in SFX.items():
		if only and name not in only:
			continue
		t0 = time.time()
		raw = fn()
		if name in LOOPED_SFX:
			x = finalize_loop(raw, LOOPED_SFX[name])
			path = os.path.join(SFX_DIR, name + ".ogg")
			write_ogg(path, x, 6)
			dec = decoded_frames(path, 1)
			info = "%.1f LUFS, peak %.1f dBFS, loop frames %d (decoded %d), seam %.2f" % (
					loudness(x), 20 * np.log10(np.max(np.abs(x))), len(x), dec.shape[1], loop_click_metric(dec))
		else:
			x = finalize_sfx(raw, fade_out=SFX_FADE_OUT.get(name, 0.03))
			path = os.path.join(SFX_DIR, name + ".wav")
			write_wav(path, x)
			info = "rms %.1f dBFS" % (20 * np.log10(rms(x)))
		size = os.path.getsize(path)
		total += size
		print("sfx   %-10s %5.2fs %7.1f KB  %s  (%.1fs)" % (name, len(x) / SR, size / 1024, info, time.time() - t0))
	for name, fn in MUSIC.items():
		if only and name not in only:
			continue
		t0 = time.time()
		print("music %s" % name)
		x = fn()
		path = os.path.join(MUSIC_DIR, name + ".ogg")
		write_ogg(path, x, 3)
		dec = decoded_frames(path, 2)
		size = os.path.getsize(path)
		total += size
		print("music %-10s %5.2fs %7.1f KB  %.1f LUFS, peak %.1f dBFS, frames %d (decoded %d), seam %.2f  (%.1fs)" % (
				name, x.shape[1] / SR, size / 1024, loudness(x),
				20 * np.log10(np.max(np.abs(x))),
				x.shape[1], dec.shape[1], loop_click_metric(dec), time.time() - t0))
	print("total written: %.2f MB" % (total / 1048576.0))


if __name__ == "__main__":
	main(sys.argv[1:])
