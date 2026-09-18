import {
  interpolateViridis,
  interpolateInferno,
  interpolateMagma,
  interpolatePlasma,
  interpolateCividis,
  interpolateTurbo,
  interpolateBlues,
  interpolateGreens,
  interpolateYlOrRd,
  interpolateBuGn,
  interpolateRdBu,
  interpolatePiYG,
  interpolatePRGn,
  interpolateBrBG,
  interpolatePuOr,
  interpolateSpectral,
  interpolateRdYlBu,
} from 'd3-scale-chromatic';

export type PaletteType = 'sequential' | 'diverging';

export interface Palette {
  id: string;
  name: string;
  type: PaletteType;
  /** Maps t in [0, 1] to a CSS color string, same contract as d3-scale-chromatic interpolators. */
  interpolator: (t: number) => string;
}

export const PALETTES: Palette[] = [
  // Sequential — one direction, low to high. Good for counts, density, magnitude.
  { id: 'viridis', name: 'Viridis', type: 'sequential', interpolator: interpolateViridis },
  { id: 'inferno', name: 'Inferno', type: 'sequential', interpolator: interpolateInferno },
  { id: 'magma', name: 'Magma', type: 'sequential', interpolator: interpolateMagma },
  { id: 'plasma', name: 'Plasma', type: 'sequential', interpolator: interpolatePlasma },
  { id: 'cividis', name: 'Cividis', type: 'sequential', interpolator: interpolateCividis },
  { id: 'turbo', name: 'Turbo', type: 'sequential', interpolator: interpolateTurbo },
  { id: 'blues', name: 'Blues', type: 'sequential', interpolator: interpolateBlues },
  { id: 'greens', name: 'Greens', type: 'sequential', interpolator: interpolateGreens },
  { id: 'ylorrd', name: 'Yellow-Orange-Red', type: 'sequential', interpolator: interpolateYlOrRd },
  { id: 'bugn', name: 'Blue-Green', type: 'sequential', interpolator: interpolateBuGn },

  // Diverging — two directions from a meaningful midpoint. Good for anomalies, deltas, balance.
  { id: 'rdbu', name: 'Red-Blue', type: 'diverging', interpolator: interpolateRdBu },
  { id: 'piyg', name: 'Pink-Yellow-Green', type: 'diverging', interpolator: interpolatePiYG },
  { id: 'prgn', name: 'Purple-Green', type: 'diverging', interpolator: interpolatePRGn },
  { id: 'brbg', name: 'Brown-Teal', type: 'diverging', interpolator: interpolateBrBG },
  { id: 'puor', name: 'Purple-Orange', type: 'diverging', interpolator: interpolatePuOr },
  { id: 'spectral', name: 'Spectral', type: 'diverging', interpolator: interpolateSpectral },
  { id: 'rdylbu', name: 'Red-Yellow-Blue', type: 'diverging', interpolator: interpolateRdYlBu },
];

export function findPalette(id: string): Palette {
  const found = PALETTES.find((p) => p.id === id);
  if (!found) throw new Error(`Unknown palette: ${id}`);
  return found;
}
