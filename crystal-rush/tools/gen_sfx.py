#!/usr/bin/env python3
"""Procedural sound effects for Crystal Rush 2.0 (Etap 1).

Writes the new one-shots that scripts/autoload/audio.gd registers in SFX_NAMES to
assets/audio/sfx/<name>.wav (16-bit mono 44.1 kHz, peak-normalised to -1 dBFS):

  crate_hit crate_open weapon_get ballista plasma laser_loop rocket drone blade spikes
  recruit stairs_step stairs_top geode_break turret_shot volley brawl whoosh_gate

House style follows crystal-bastion/tools/gen_audio.py: plain numpy DSP (additive / modal /
FM synthesis, zero-phase FFT filters, filtered and swept noise), deterministic seeds, raised
cosine fades so nothing clicks. The palette is "orbital crystal": glassy bell partials,
white-silver metal, soft sub weight, no harsh top end (everything above ~9 kHz is rolled off).

laser_loop is exactly 1.0 s and every component is periodic in 1 s (integer-Hz partials,
integer-Hz modulation, circularly filtered noise), so it loops without a seam. The WAV also
carries a RIFF "smpl" loop chunk, so Godot's importer (edit/loop_mode = Detect) loops it.

Usage:
  python3 tools/gen_sfx.py              # everything
  python3 tools/gen_sfx.py plasma drone # only these names
"""

import os
import struct
import sys
import wave
import zlib

import numpy as np
from scipy.signal import lfilter

SR = 44100
TAU = 2.0 * np.pi
HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
SFX_DIR = os.path.join(PROJECT, "assets", "audio", "sfx")
PEAK_DB = -1.0


# =========================================================================
# Helpers
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
	"""Raised-cosine attack, optional hold, exponential decay (time constant `decay`)."""
	t = tvec(n)
	env = np.exp(-np.maximum(t - attack - hold, 0.0) / decay)
	a = min(ns(attack), n)
	if a > 0:
		env[:a] *= ramp(a)
	return env


def env_swell(n, rise, peak_t, decay):
	"""Smooth swell up to `peak_t`, then exponential decay."""
	t = tvec(n)
	up = np.clip(t / max(peak_t, 1e-4), 0.0, 1.0) ** rise
	down = np.exp(-np.maximum(t - peak_t, 0.0) / decay)
	return up * down


def place(buf, sig, start):
	start = int(start)
	if start >= buf.shape[-1]:
		return
	n = min(sig.shape[-1], buf.shape[-1] - start)
	buf[..., start:start + n] += sig[..., :n]


def next_pow2(n):
	return 1 << int(np.ceil(np.log2(max(n, 2))))


def phase_of(freq, n, start=0.0):
	if np.ndim(freq) == 0:
		return start + float(freq) * np.arange(n) / SR
	return start + np.cumsum(freq) / SR


# ---- filters (FFT domain, zero phase) ----

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
	n = x.shape[-1]
	size = n if circular else next_pow2(n + min(n, 16384) + 256)
	spec = np.fft.rfft(x, size)
	f = np.fft.rfftfreq(size, 1.0 / SR)
	return np.fft.irfft(spec * resp(f), size)[..., :n]


def fnoise(n, r, resp, circular=False):
	"""RMS-normalised filtered white noise."""
	y = sfilt(r.standard_normal(n), resp, circular)
	return y / (rms(y) + 1e-12)


def band_partition(f, centers):
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


def swept_noise(n, r, fc, mode="bp", q=1.5, order=2, nb=24, fmin=60.0, fmax=14000.0):
	"""Noise through a time-varying filter (morphs a bank of log-spaced bands)."""
	w = r.standard_normal(n)
	size = next_pow2(n + 4096)
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
	"""Causal one-pole DC blocker (no pre-ringing on attacks)."""
	a = np.exp(-TAU * fc / SR)
	return lfilter([1.0, -1.0], [1.0, -a], x)


# ---- oscillators / voices ----

TABLE = 4096


def harmonic_table(amps):
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


def bl_saw(freq, n, fmax=8000.0, slope=1.0, cutoff=None, start=0.0):
	"""Band-limited saw-ish wave for a (possibly swept) frequency; harmonics sized for the top pitch."""
	ftop = float(np.max(freq)) if np.ndim(freq) else float(freq)
	kmax = max(1, int(fmax / max(ftop, 1.0)))
	k = np.arange(1, kmax + 1)
	a = 1.0 / k ** slope
	if cutoff:
		a = a * lp(cutoff, 2)(k * ftop)
	return table_read(harmonic_table(a), phase_of(freq, n, start))


def modal(n, freqs, amps, decays, r, attack=0.001):
	"""Sum of exponentially decaying sine partials (bells, bars, plates, bodies)."""
	t = tvec(n)
	out = np.zeros(n)
	for f, a, d in zip(freqs, amps, decays):
		if f >= SR * 0.42 or a == 0.0:
			continue
		out += a * np.sin(TAU * f * t + r.uniform(0, TAU)) * np.exp(-t / d)
	a_n = min(ns(attack), n)
	if a_n > 0:
		out[:a_n] *= ramp(a_n)
	return fades(out, 0.0, min(0.04, n / SR * 0.3))


def bell(freq, dur, r, decay=0.6, bright=1.0, attack=0.0015):
	"""Glassy crystal bell: fundamental + bell partials (2.0, 2.76, 4.07, 5.4) + a beating twin."""
	n = ns(dur)
	ratios = [1.0, 1.0035, 2.0, 2.76, 4.07, 5.4]
	amps = [1.0, 0.45, 0.32 * bright, 0.22 * bright, 0.1 * bright, 0.05 * bright]
	decs = [decay, decay * 0.9, decay * 0.5, decay * 0.32, decay * 0.2, decay * 0.14]
	return modal(n, [freq * q for q in ratios], amps, decs, r, attack)


def marimba(freq, dur, r, decay=0.3):
	"""Warm mallet bar: fundamental, tuned 4th partial and a quick woody knock."""
	n = ns(dur)
	s = modal(n, [freq, freq * 3.93, freq * 9.2, freq * 1.002],
			[1.0, 0.28, 0.05, 0.25], [decay, decay * 0.22, decay * 0.08, decay * 0.8], r, attack=0.001)
	s += fnoise(n, r, band(freq * 1.5, min(freq * 6.0, 9000.0), 1)) * env_perc(n, 0.0004, 0.006) * 0.12
	return s


def small_reverb(x, name, rt60=0.9, wet=0.16, lowcut=300.0, highcut=8000.0, tail=0.0):
	"""Short noise-IR room/space reverb; `tail` extends the buffer so the tail is not cut."""
	r = rng_for(name + "/ir")
	n = ns(rt60 * 1.1)
	t = tvec(n)
	ir = r.standard_normal(n) * np.exp(-6.9078 * t / rt60)
	ir = sfilt(ir, band(lowcut, highcut, 2))
	ir[:ns(0.01)] *= ramp(ns(0.01))
	ir = np.concatenate([np.zeros(ns(0.012)), ir])
	ir /= np.sqrt(np.sum(ir * ir))
	if tail > 0.0:
		x = np.concatenate([x, np.zeros(ns(tail))])
	size = next_pow2(len(x) + len(ir))
	y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x)]
	return x + wet * y * (rms(x) / (rms(y) + 1e-12))


def soft_clip(x, drive=1.5):
	x = x / (np.max(np.abs(x)) + 1e-12)
	return np.tanh(drive * x) / np.tanh(drive)


# =========================================================================
# Sound effects
# =========================================================================

def sfx_crate_hit():
	"""Bolt strikes the weapon capsule: silver plate ping over a padded thump."""
	r = rng_for("crate_hit")
	n = ns(0.32)
	t = tvec(n)
	thump = np.sin(TAU * phase_of(130.0 + 120.0 * np.exp(-t / 0.012), n)) * env_perc(n, 0.001, 0.045)
	plate = modal(n, [710.0, 1185.0, 1630.0, 2390.0, 3310.0], [0.7, 0.55, 0.42, 0.3, 0.16],
			[0.11, 0.08, 0.06, 0.045, 0.03], r, attack=0.0006)
	click = fnoise(n, r, band(1500, 6500, 1)) * env_perc(n, 0.0003, 0.004)
	glint = modal(n, [2960.0, 2973.0], [0.18, 0.12], [0.12, 0.1], r)
	return soft_clip(0.9 * thump + 0.75 * plate + 0.3 * click + glint, 1.3)


def sfx_crate_open():
	"""Capsule cracks open: latch clack, pneumatic hiss and a rising crystal shimmer."""
	r = rng_for("crate_open")
	n = ns(0.95)
	t = tvec(n)
	x = np.zeros(n)
	clack = modal(ns(0.2), [420.0, 980.0, 1720.0, 2600.0], [0.8, 0.6, 0.4, 0.2], [0.05, 0.035, 0.025, 0.02], r, 0.0005)
	clack += np.sin(TAU * phase_of(95.0 + 80.0 * np.exp(-tvec(ns(0.2)) / 0.01), ns(0.2))) * env_perc(ns(0.2), 0.001, 0.05)
	place(x, clack, 0)
	place(x, clack * 0.55, ns(0.045))
	hiss = swept_noise(n, r, 6500.0 * 2.0 ** (-2.2 * np.clip(t / 0.5, 0, 1)), mode="bp", q=1.1)
	x += 0.2 * sfilt(hiss, lp(7000.0, 2)) * env_swell(n, 0.6, 0.05, 0.14)
	for i, m in enumerate((79, 83, 86, 91)):
		place(x, bell(mtof(m), 0.7, r, 0.35, 0.8) * (0.32 + 0.05 * i), ns(0.1 + 0.055 * i))
	return small_reverb(x, "crate_open", 0.8, 0.2)


def sfx_weapon_get():
	"""Reward sting: sub whomp, rising major arpeggio of crystal bells, shimmering pad."""
	r = rng_for("weapon_get")
	n = ns(1.35)
	t = tvec(n)
	x = np.zeros(n)
	whomp = np.sin(TAU * phase_of(55.0 + 90.0 * np.exp(-t / 0.05), n)) * env_perc(n, 0.004, 0.18)
	x += 0.55 * whomp
	notes = [72, 76, 79, 84, 88]
	for i, m in enumerate(notes):
		last = i == len(notes) - 1
		place(x, bell(mtof(m), 1.1 if last else 0.6, r, 0.45 if last else 0.28, 0.9) * (0.36 + 0.04 * i),
				ns(0.05 + 0.07 * i))
		place(x, marimba(mtof(m - 12), 0.5, r, 0.2) * 0.2, ns(0.05 + 0.07 * i))
	pad = np.zeros(n)
	for m in (72, 76, 79, 84):
		f = mtof(m)
		pad += np.sin(TAU * f * t + r.uniform(0, TAU)) + 0.5 * np.sin(TAU * f * 1.006 * t)
	pad *= env_swell(n, 1.5, 0.42, 0.35) * 0.06 * (0.8 + 0.2 * np.sin(TAU * 9.0 * t))
	x += pad
	sweep = swept_noise(n, r, 1200.0 * 2.0 ** (3.0 * np.clip(t / 0.45, 0, 1)), mode="bp", q=2.0)
	x += 0.07 * sweep * env_swell(n, 2.0, 0.38, 0.12)
	return small_reverb(x, "weapon_get", 1.2, 0.24)


def sfx_ballista():
	"""Heavy bolt release: taut string thwack, frame knock and the bolt's whoosh."""
	r = rng_for("ballista")
	n = ns(0.5)
	t = tvec(n)
	f = 82.0 * (1.0 + 0.35 * np.exp(-t / 0.02))
	string = np.zeros(n)
	cyc = phase_of(f, n)
	for k in range(1, 14):
		a = (abs(np.sin(np.pi * k * 0.17)) + 0.05) / k ** 0.85
		string += a * np.sin(TAU * k * cyc + r.uniform(0, TAU)) * np.exp(-t / (0.14 / (1 + 0.4 * (k - 1))))
	string = string / np.max(np.abs(string))
	knock = modal(n, [240.0, 560.0, 905.0], [0.8, 0.5, 0.3], [0.05, 0.03, 0.02], r, 0.0005)
	slap = fnoise(n, r, band(700, 4000, 1)) * env_perc(n, 0.0004, 0.006)
	wh = swept_noise(n, r, 600.0 + 2400.0 * np.exp(-t / 0.15), mode="bp", q=1.4)
	wenv = np.clip(t / 0.05, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 0.06, 0) / 0.11)
	return soft_clip(0.95 * string + 0.5 * knock + 0.3 * slap + 0.3 * wh * wenv, 1.4)


def sfx_plasma():
	"""Plasma cannon: FM zap falling into a soft sub thoom, with an ionised sizzle."""
	r = rng_for("plasma")
	n = ns(0.7)
	t = tvec(n)
	fc = 160.0 + 1100.0 * np.exp(-t / 0.06)
	mod = np.sin(TAU * phase_of(fc * 1.5, n)) * (2.2 * np.exp(-t / 0.08) + 0.3)
	zap = np.sin(TAU * phase_of(fc, n) + mod) * env_perc(n, 0.002, 0.13)
	zap = sfilt(zap, lp(5500, 2))
	sub = np.sin(TAU * phase_of(48.0 + 70.0 * np.exp(-t / 0.05), n)) * env_perc(n, 0.004, 0.2)
	sizzle = swept_noise(n, r, 3500.0 * 2.0 ** (-1.5 * np.clip(t / 0.3, 0, 1)), mode="bp", q=1.8)
	sizzle *= env_perc(n, 0.003, 0.09) * (0.7 + 0.3 * np.sin(TAU * 43.0 * t))
	glow = modal(n, [mtof(76), mtof(83)], [0.2, 0.12], [0.18, 0.12], r, 0.004)
	x = 0.8 * zap + 0.75 * sub + 0.22 * sizzle + glow
	return small_reverb(soft_clip(x, 1.6), "plasma", 0.6, 0.12)


def sfx_laser_loop():
	"""Seamless 1.0 s crystal beam: integer-Hz partials, integer-Hz modulation, circular noise."""
	r = rng_for("laser_loop")
	n = SR
	t = np.arange(n) / SR
	hum = np.zeros(n)
	for f0, g in ((110, 1.0), (111, 0.55)):
		for k in range(1, 40):
			fk = float(f0 * k)
			if fk > 6000.0:
				break
			form = 0.25 + 1.0 / np.sqrt(1.0 + (1.2 * (fk / 880.0 - 880.0 / fk)) ** 2)
			form += 0.5 / np.sqrt(1.0 + (1.6 * (fk / 2200.0 - 2200.0 / fk)) ** 2)
			hum += g * np.sin(TAU * fk * t + r.uniform(0, TAU)) * form / k ** 0.9 * lp(3200.0, 2)(fk)
	hum *= 1.0 + 0.14 * np.sin(TAU * 6 * t)
	hum += 0.25 * np.sin(TAU * 55 * t)
	shimmer = np.zeros(n)
	for f, ph in ((1320, 0.0), (1323, 1.3), (1980, 2.1), (1984, 0.4)):
		shimmer += np.sin(TAU * f * t + ph)
	shimmer *= 0.07 * (0.6 + 0.4 * np.sin(TAU * 4 * t))
	sizzle = fnoise(n, r, band(1800, 6000, 2), circular=True) * 0.05 * (0.7 + 0.3 * np.sin(TAU * 12 * t))
	return hum / np.max(np.abs(hum)) + shimmer + sizzle


def sfx_rocket():
	"""Rocket launch: ignition pop, rushing exhaust that rises and flies away, crackle."""
	r = rng_for("rocket")
	n = ns(0.85)
	t = tvec(n)
	pop = np.sin(TAU * phase_of(90.0 + 160.0 * np.exp(-t / 0.015), n)) * env_perc(n, 0.001, 0.05)
	pop += fnoise(n, r, band(400, 3000, 1)) * env_perc(n, 0.0005, 0.012) * 0.6
	rush = swept_noise(n, r, 450.0 * 2.0 ** (2.0 * np.clip(t / 0.55, 0, 1)), mode="bp", q=1.3)
	rush = sfilt(rush, lp(5000.0, 2))
	renv = env_swell(n, 0.7, 0.07, 0.22)
	roar = fnoise(n, r, band(80, 600, 2)) * env_swell(n, 0.8, 0.04, 0.16)
	crackle = np.zeros(n)
	for tc in np.sort(r.uniform(0.02, 0.45, 26)):
		m = ns(0.015)
		tt = tvec(m)
		c = np.sin(TAU * r.uniform(1200, 4200) * tt) * np.exp(-tt / 0.003) * r.uniform(0.3, 1.0)
		place(crackle, c * np.exp(-tc / 0.25), ns(tc))
	x = 0.8 * pop + 0.55 * rush * renv + 0.45 * roar + 0.18 * crackle
	return soft_clip(x, 1.3)


def sfx_drone():
	"""Drone blaster: small, bright, friendly pip (fires twice a second, must not tire)."""
	r = rng_for("drone")
	n = ns(0.2)
	t = tvec(n)
	f = 1350.0 * 2.0 ** (-1.1 * np.clip(t / 0.06, 0, 1))
	pip = (np.sin(TAU * phase_of(f, n)) + 0.25 * np.sin(2 * TAU * phase_of(f, n))) * env_perc(n, 0.001, 0.035)
	body = np.sin(TAU * phase_of(420.0 * 2.0 ** (-0.8 * np.clip(t / 0.05, 0, 1)), n)) * env_perc(n, 0.001, 0.025)
	air = fnoise(n, r, band(2500, 7000, 1)) * env_perc(n, 0.0005, 0.01)
	return 0.8 * pip + 0.35 * body + 0.12 * air


def sfx_blade():
	"""Rotor blade pass: a doppler-ish swish with a faint metallic ring."""
	r = rng_for("blade")
	n = ns(0.46)
	t = tvec(n)
	fc = 700.0 * 2.0 ** (1.6 * np.sin(np.pi * np.clip(t / 0.38, 0, 1)))
	sw = swept_noise(n, r, fc, mode="bp", q=2.2)
	env = np.sin(np.pi * np.clip(t / 0.38, 0, 1)) ** 2
	ring = modal(n, [1870.0, 1877.0, 3020.0], [0.2, 0.15, 0.08], [0.18, 0.16, 0.1], r, 0.03)
	ring *= np.clip(t / 0.15, 0, 1)
	low = fnoise(n, r, band(90, 400, 2)) * env * 0.3
	return 0.85 * sw * env + ring + low


def sfx_spikes():
	"""Soldier impaled on a spike: metal shink and a soft body thud (frequent, so not gory)."""
	r = rng_for("spikes")
	n = ns(0.3)
	t = tvec(n)
	shink = modal(n, [2350.0, 3140.0, 4410.0, 5230.0], [0.5, 0.4, 0.25, 0.12], [0.06, 0.045, 0.03, 0.02], r, 0.0008)
	scrape = swept_noise(n, r, 5200.0 * 2.0 ** (-1.2 * np.clip(t / 0.08, 0, 1)), mode="bp", q=3.0)
	scrape *= env_perc(n, 0.001, 0.025)
	thud = np.sin(TAU * phase_of(110.0 + 90.0 * np.exp(-t / 0.012), n)) * env_perc(n, 0.002, 0.05)
	thud += fnoise(n, r, band(200, 1100, 1)) * env_perc(n, 0.001, 0.02) * 0.4
	return soft_clip(0.6 * shink + 0.25 * scrape + 0.85 * thud, 1.4)


def sfx_recruit():
	"""Grey recruits join: a round bloop and two rising marimba notes."""
	r = rng_for("recruit")
	n = ns(0.42)
	t = tvec(n)
	x = np.zeros(n)
	bloop = np.sin(TAU * phase_of(260.0 * 2.0 ** (1.3 * np.clip(t / 0.06, 0, 1)), n)) * env_perc(n, 0.002, 0.05)
	x += 0.55 * bloop
	place(x, marimba(mtof(79), 0.38, r, 0.16) * 0.55, ns(0.03))
	place(x, marimba(mtof(86), 0.34, r, 0.18) * 0.6, ns(0.1))
	place(x, bell(mtof(98), 0.3, r, 0.12, 0.5) * 0.1, ns(0.1))
	return x


def sfx_stairs_step():
	"""One multiplier step: hollow crystal block knock with a bell; pitched up per step in code."""
	r = rng_for("stairs_step")
	n = ns(0.4)
	t = tvec(n)
	knock = modal(n, [330.0, 805.0, 1290.0], [0.8, 0.45, 0.25], [0.09, 0.05, 0.03], r, 0.0006)
	knock += np.sin(TAU * phase_of(140.0 + 80.0 * np.exp(-t / 0.01), n)) * env_perc(n, 0.001, 0.04) * 0.6
	ding = bell(mtof(84), 0.4, r, 0.2, 0.8)
	return 0.8 * knock + 0.5 * ding


def sfx_stairs_top():
	"""Top step reached: a big crystal chord bloom over a timpani-like boom, with glitter."""
	r = rng_for("stairs_top")
	n = ns(1.6)
	t = tvec(n)
	x = np.zeros(n)
	boom = np.sin(TAU * phase_of(52.0 + 60.0 * np.exp(-t / 0.05), n)) * env_perc(n, 0.003, 0.35)
	boom += fnoise(n, r, band(150, 900, 1)) * env_perc(n, 0.001, 0.03) * 0.4
	x += 0.7 * boom
	for i, m in enumerate((72, 76, 79, 84, 88, 91)):
		place(x, bell(mtof(m), 1.4, r, 0.7, 0.9) * (0.28 - 0.015 * i), ns(0.012 * i))
	for m in (60, 67):
		place(x, marimba(mtof(m), 1.0, r, 0.45) * 0.3, 0)
	glitter = rng_for("stairs_top/glitter")
	for i in range(12):
		m = int(glitter.choice([96, 100, 103, 108]))
		place(x, bell(mtof(m), 0.4, glitter, 0.12, 0.4) * glitter.uniform(0.04, 0.09),
				ns(0.15 + i * 0.06 + glitter.uniform(0, 0.03)))
	return small_reverb(x, "stairs_top", 1.4, 0.26)


def sfx_geode_break():
	"""Crystal geode shatters: low crunch, a burst of glassy shards, settling tinkles."""
	r = rng_for("geode_break")
	n = ns(1.0)
	t = tvec(n)
	x = np.zeros(n)
	thud = np.sin(TAU * phase_of(70.0 + 110.0 * np.exp(-t / 0.02), n)) * env_perc(n, 0.002, 0.11)
	crunch = swept_noise(n, r, 300.0 + 4500.0 * np.exp(-t / 0.05), mode="lp")
	x += 0.75 * thud + 0.5 * crunch * env_perc(n, 0.001, 0.06)
	times = np.concatenate([r.uniform(0.0, 0.06, 10), 0.06 + r.exponential(0.12, 18)])
	for tc in np.sort(times):
		if tc > 0.7:
			continue
		f = r.uniform(2200.0, 6200.0)
		m = ns(0.25)
		s = modal(m, [f, f * 1.47, f * 2.09], [1.0, 0.5, 0.25], [0.06, 0.04, 0.025], r, 0.0004)
		place(x, s * r.uniform(0.12, 0.3) * np.exp(-tc / 0.35), ns(tc))
	for m in (81, 88):
		place(x, bell(mtof(m), 0.8, r, 0.35, 0.7) * 0.18, ns(0.02))
	return small_reverb(soft_clip(x, 2.2), "geode_break", 0.9, 0.2)


def sfx_turret_shot():
	"""Enemy turret: darker, buzzier pew (reads as hostile next to the hero's bright shots)."""
	r = rng_for("turret_shot")
	n = ns(0.32)
	t = tvec(n)
	f = 260.0 + 620.0 * np.exp(-t / 0.035)
	buzz = bl_saw(f, n, fmax=5000.0, slope=1.1, cutoff=3200.0) * env_perc(n, 0.001, 0.07)
	sub = np.sin(TAU * phase_of(90.0 + 60.0 * np.exp(-t / 0.02), n)) * env_perc(n, 0.002, 0.06)
	click = fnoise(n, r, band(800, 4000, 1)) * env_perc(n, 0.0004, 0.005)
	return soft_clip(0.65 * buzz + 0.6 * sub + 0.25 * click, 1.5)


def sfx_volley():
	"""Army crossbow volley: a cluster of string twangs and arrow swishes."""
	r = rng_for("volley")
	n = ns(0.55)
	x = np.zeros(n)
	for i in range(7):
		t0 = r.uniform(0.0, 0.07)
		m = ns(0.4)
		tt = tvec(m)
		f0 = r.uniform(170.0, 260.0)
		cyc = phase_of(f0 * (1.0 + 0.08 * np.exp(-tt / 0.02)), m)
		tw = np.zeros(m)
		for k in range(1, 10):
			a = (abs(np.sin(np.pi * k * 0.15)) + 0.05) / k
			tw += a * np.sin(TAU * k * cyc + r.uniform(0, TAU)) * np.exp(-tt / (0.06 / (1 + 0.4 * (k - 1))))
		tw /= np.max(np.abs(tw))
		place(x, tw * r.uniform(0.25, 0.4), ns(t0))
	t = tvec(n)
	sw = swept_noise(n, r, 900.0 + 3000.0 * np.exp(-t / 0.14), mode="bp", q=1.3)
	x += 0.4 * sfilt(sw, lp(6000.0, 2)) * env_swell(n, 1.2, 0.07, 0.1)
	x += fnoise(n, r, band(1000, 5000, 1)) * env_perc(n, 0.0005, 0.008) * 0.3
	return soft_clip(x, 1.4)


def sfx_brawl():
	"""Short scuffle: muffled punches, armour clinks and cloth rustle."""
	r = rng_for("brawl")
	n = ns(0.45)
	x = np.zeros(n)
	for t0, g in ((0.0, 1.0), (0.09, 0.7), (0.16, 0.85), (0.27, 0.6)):
		m = ns(0.12)
		tt = tvec(m)
		f = r.uniform(85.0, 120.0)
		p = np.sin(TAU * phase_of(f * (1.0 + 0.8 * np.exp(-tt / 0.008)), m)) * env_perc(m, 0.001, 0.03)
		p += fnoise(m, r, band(250, 1600, 1)) * env_perc(m, 0.0006, 0.012) * 0.6
		place(x, p * g, ns(t0 + r.uniform(0, 0.015)))
	for t0 in (0.05, 0.2):
		f = r.uniform(2400.0, 3400.0)
		c = modal(ns(0.15), [f, f * 1.41, f * 2.2], [0.5, 0.35, 0.15], [0.04, 0.03, 0.02], r, 0.0005)
		place(x, c * 0.35, ns(t0))
	t = tvec(n)
	rustle = fnoise(n, r, band(1200, 5000, 1)) * (0.6 + 0.4 * np.sin(TAU * 23.0 * t)) * env_swell(n, 0.5, 0.05, 0.15)
	x += 0.12 * rustle
	return soft_clip(x, 1.6)


def sfx_whoosh_gate():
	"""Passing through an energy gate: airy rising-then-falling whoosh with a field shimmer."""
	r = rng_for("whoosh_gate")
	n = ns(0.5)
	t = tvec(n)
	p = np.clip(t / 0.42, 0, 1)
	fc = 500.0 * 2.0 ** (2.5 * np.sin(np.pi * p * 0.8))
	sw = swept_noise(n, r, fc, mode="bp", q=1.4)
	env = np.sin(np.pi * p) ** 1.6
	shimmer = np.zeros(n)
	for f in (mtof(91), mtof(91) * 1.006, mtof(98)):
		shimmer += np.sin(TAU * phase_of(f * (1.0 + 0.03 * p), n) + r.uniform(0, TAU))
	shimmer *= env_swell(n, 1.5, 0.2, 0.15) * 0.05 * (0.7 + 0.3 * np.sin(TAU * 18.0 * t))
	sub = np.sin(TAU * phase_of(65.0 + 30.0 * p, n)) * env * 0.25
	return 0.85 * sw * env + shimmer + sub


SFX = {
	"crate_hit": sfx_crate_hit, "crate_open": sfx_crate_open, "weapon_get": sfx_weapon_get,
	"ballista": sfx_ballista, "plasma": sfx_plasma, "laser_loop": sfx_laser_loop, "rocket": sfx_rocket,
	"drone": sfx_drone, "blade": sfx_blade, "spikes": sfx_spikes, "recruit": sfx_recruit,
	"stairs_step": sfx_stairs_step, "stairs_top": sfx_stairs_top, "geode_break": sfx_geode_break,
	"turret_shot": sfx_turret_shot, "volley": sfx_volley, "brawl": sfx_brawl, "whoosh_gate": sfx_whoosh_gate,
}
LOOPED = {"laser_loop"}
# fade-out (s) for sounds whose tails still ring at the end of the buffer
FADE_OUT = {"crate_open": 0.15, "weapon_get": 0.25, "stairs_top": 0.3, "geode_break": 0.2, "plasma": 0.1}
# gentle top-end roll-off applied to everything (keeps phone speakers from sounding harsh)
AIR_CUT = 11000.0


# =========================================================================
# Output
# =========================================================================

def finalize_sfx(x, name):
	x = sfilt(np.asarray(x, dtype=np.float64), lp(AIR_CUT, 2))
	x = dc_block(x)
	x = fades(x, 0.001, min(FADE_OUT.get(name, 0.03), len(x) / SR * 0.25))
	return x * (dbg(PEAK_DB) / (np.max(np.abs(x)) + 1e-12))


def finalize_loop(x):
	x = sfilt(x - np.mean(x), hp(25.0, 2), circular=True)
	x = sfilt(x, lp(AIR_CUT, 2), circular=True)
	return x * (dbg(PEAK_DB) / (np.max(np.abs(x)) + 1e-12))


def write_wav(path, x, loop=False):
	pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())
	if loop:
		_append_smpl_loop(path, len(pcm))


def _append_smpl_loop(path, frames):
	"""Adds a RIFF 'smpl' chunk with one forward loop over the whole file."""
	period_ns = int(round(1e9 / SR))
	chunk = struct.pack("<9I", 0, 0, period_ns, 60, 0, 0, 0, 1, 0)
	chunk += struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
	data = b"smpl" + struct.pack("<I", len(chunk)) + chunk
	with open(path, "r+b") as f:
		f.seek(0, 2)
		f.write(data)
		size = f.tell() - 8
		f.seek(4)
		f.write(struct.pack("<I", size))


def seam_metric(x):
	"""Step across the loop seam (last sample -> first) relative to the median step; <= ~3 is seamless."""
	seam = abs(x[0] - x[-1])
	typical = np.median(np.abs(np.diff(x)))
	return seam / (typical + 1e-12)


def main(argv):
	only = set(argv)
	unknown = only - set(SFX)
	if unknown:
		sys.exit("unknown names: %s" % ", ".join(sorted(unknown)))
	os.makedirs(SFX_DIR, exist_ok=True)
	total = 0
	for name, fn in SFX.items():
		if only and name not in only:
			continue
		raw = fn()
		loop = name in LOOPED
		x = finalize_loop(raw) if loop else finalize_sfx(raw, name)
		path = os.path.join(SFX_DIR, name + ".wav")
		write_wav(path, x, loop)
		size = os.path.getsize(path)
		total += size
		info = "peak %.2f dBFS  rms %.1f dBFS" % (20 * np.log10(np.max(np.abs(x))), 20 * np.log10(rms(x)))
		if loop:
			info += "  seam %.2f" % seam_metric(x)
		print("sfx %-12s %5.2fs %7.1f KB  %s" % (name, len(x) / SR, size / 1024, info))
	print("total written: %.2f MB" % (total / 1048576.0))


if __name__ == "__main__":
	main(sys.argv[1:])
