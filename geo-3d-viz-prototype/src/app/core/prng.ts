/** Deterministic PRNG so sample datasets are stable across reloads/builds. */
export function mulberry32(seed: number): () => number {
  let s = seed;
  return function random() {
    s |= 0;
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Standard-normal sample via Box-Muller, driven by the given PRNG. */
export function gaussian(random: () => number, mean = 0, stdDev = 1): number {
  const u1 = Math.max(random(), 1e-9);
  const u2 = random();
  const z0 = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
  return mean + z0 * stdDev;
}
