// Vented-box (bass reflex) low-frequency model, as in my BSc thesis.
//
// Pure maths, no DOM or Web Audio, so it can be tested on its own:
//   node -e 'import("./assets/js/vented-box.js").then(m => console.log(m.ventTuning(4.9, m.DESIGN)))'
//
// Thesis sources (MATLAB): cabinetparam.m, findVb.m, helmholtzf.m, ventlength.m,
// ventedresponse.m. Two fixes against that code: dB uses log10 (the MATLAB used
// natural log, which stretched the dB axis by ln 10), and the response is
// computed from the transfer function, not only its magnitude, so it can drive
// a real filter.

// Eminence Alpha-6A, published Thiele/Small parameters, and the box as built.
export const DESIGN = {
  fs: 118,        // driver resonance (Hz)
  Qts: 0.54,      // total Q
  Vas: 5.8,       // equivalent compliance volume (L)
  QL: 7,          // box losses, as in the thesis model
  ventRadiusCm: 3.5,
};
// Box volume after Weems (1997): Vb = 15 Qts^2.87 Vas  -> 14.84 L
DESIGN.Vb = 15 * DESIGN.Qts ** 2.87 * DESIGN.Vas;

const CM_PER_INCH = 2.54;
const CUBIC_INCH_PER_LITRE = 61.016949;

// Tuning frequency for a vent length, inverting the thesis vent formula
//   Lv = 1.463e7 R^2 / (fb^2 Vb) - 1.463 R      (inches, cubic inches)
// where 1.463 R is the end correction.
export function ventTuning(lengthCm, p = DESIGN) {
  const R = p.ventRadiusCm / CM_PER_INCH;
  const L = lengthCm / CM_PER_INCH;
  const Vb = p.Vb * CUBIC_INCH_PER_LITRE;
  return Math.sqrt((1.463e7 * R * R) / (Vb * (L + 1.463 * R)));
}

// Small's vented-box response, normalised to the driver resonance (s' = s/ws):
//   G(s') = s'^4 / (s'^4 + D s'^3 + C s'^2 + B s' + A)
// Same A..D as the thesis code. fb = 0 gives the sealed-box response.
export function coefficients(fb, p = DESIGN) {
  const h = fb / p.fs;
  const alpha = p.Vas / p.Vb;
  const A = h * h;
  const B = A / p.Qts + h / p.QL;
  const C = 1 + A + alpha + h / (p.QL * p.Qts);
  const D = 1 / p.Qts + h / p.QL;
  return { A, B, C, D };
}

// |G| in dB at frequency f (Hz): the thesis formula, with log10.
export function responseDb(f, fb, p = DESIGN) {
  const { A, B, C, D } = coefficients(fb, p);
  const x = f / p.fs, x2 = x * x, x4 = x2 * x2;
  const den = (x4 - C * x2 + A) ** 2 + x2 * (D * x2 - B) ** 2;
  return 10 * Math.log10((x4 * x4) / den);
}

// -3 dB point, scanning up from 5 Hz.
export function f3(fb, p = DESIGN) {
  for (let f = 5; f < 1000; f *= 1.001) if (responseDb(f, fb, p) >= -3) return f;
  return NaN;
}

// Roots of a monic polynomial (coefficients highest power first, leading 1),
// by Durand-Kerner. Quartic here, so a few dozen iterations is plenty.
function roots(c) {
  const n = c.length - 1;
  let z = Array.from({ length: n }, (_, k) => {
    const a = (2 * Math.PI * k) / n + 0.4;
    return [0.9 * Math.cos(a), 0.9 * Math.sin(a)];
  });
  const mul = (a, b) => [a[0] * b[0] - a[1] * b[1], a[0] * b[1] + a[1] * b[0]];
  const div = (a, b) => {
    const d = b[0] * b[0] + b[1] * b[1];
    return [(a[0] * b[0] + a[1] * b[1]) / d, (a[1] * b[0] - a[0] * b[1]) / d];
  };
  const evalAt = (x) => c.reduce((acc, ck) => { const m = mul(acc, x); return [m[0] + ck, m[1]]; }, [0, 0]);
  for (let it = 0; it < 200; it++) {
    let moved = 0;
    z = z.map((zi, i) => {
      let den = [1, 0];
      z.forEach((zj, j) => { if (j !== i) den = mul(den, [zi[0] - zj[0], zi[1] - zj[1]]); });
      const step = div(evalAt(zi), den);
      moved = Math.max(moved, Math.hypot(step[0], step[1]));
      return [zi[0] - step[0], zi[1] - step[1]];
    });
    if (moved < 1e-14) break;
  }
  return z;
}

// Split the denominator into two quadratics s'^2 + p s' + q (conjugate pairs
// together, real roots paired), so the filter runs as two 2nd-order sections.
// A single 4th-order direct-form IIR is numerically fragile with poles this
// close to z = 1 (118 Hz at 48 kHz).
function analogSections(fb, p) {
  const { A, B, C, D } = coefficients(fb, p);
  const r = roots([1, D, C, B, A]);
  const cplx = r.filter((x) => Math.abs(x[1]) > 1e-9 * (1 + Math.abs(x[0])));
  const real = r.filter((x) => !cplx.includes(x)).map((x) => x[0]).sort((a, b) => a - b);
  const sections = [];
  const upper = cplx.filter((x) => x[1] > 0);
  upper.forEach((x) => sections.push({ p: -2 * x[0], q: x[0] * x[0] + x[1] * x[1] }));
  for (let i = 0; i + 1 < real.length; i += 2) {
    sections.push({ p: -(real[i] + real[i + 1]), q: real[i] * real[i + 1] });
  }
  return sections;   // each section's numerator is s'^2
}

// Digital filter: two 2nd-order IIR sections {feedforward, feedback} for Web
// Audio's IIRFilterNode, by the bilinear transform pre-warped at fs. For
// fb = 0 the s'^2 roots at zero cancel against the numerator and the sealed
// response is a single section.
export function filterSections(fb, sampleRate, p = DESIGN) {
  const c = 1 / Math.tan((Math.PI * p.fs) / sampleRate);   // s' = c (1 - z^-1)/(1 + z^-1)
  const c2 = c * c;
  const analog = fb > 0
    ? analogSections(fb, p)
    : (() => {
        const { C, D } = coefficients(0, p);
        return [{ p: D, q: C }];
      })();
  return analog.map(({ p: ps, q }) => {
    const a0 = c2 + ps * c + q;
    return {
      feedforward: [c2 / a0, (-2 * c2) / a0, c2 / a0],
      feedback: [1, (2 * q - 2 * c2) / a0, (c2 - ps * c + q) / a0],
    };
  });
}

// Magnitude (dB) of those digital sections at f, for checking the filter
// against responseDb().
export function sectionsDb(sections, f, sampleRate) {
  const w = (2 * Math.PI * f) / sampleRate;
  let mag = 1;
  for (const { feedforward: b, feedback: a } of sections) {
    const re = (k) => k.reduce((s, v, i) => s + v * Math.cos(-w * i), 0);
    const im = (k) => k.reduce((s, v, i) => s + v * Math.sin(-w * i), 0);
    mag *= Math.hypot(re(b), im(b)) / Math.hypot(re(a), im(a));
  }
  return 20 * Math.log10(mag);
}
