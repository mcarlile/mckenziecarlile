export type RgbColor = [number, number, number];

const RGB_PATTERN = /rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i;
const HEX_PATTERN = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i;

/**
 * d3-scale-chromatic interpolators return either CSS "rgb(r, g, b)" strings (the diverging /
 * multi-hue ramps) or "#rrggbb" hex strings (viridis-family ramps) — parse either to a triplet.
 */
export function cssRgbToTuple(css: string): RgbColor {
  const hexMatch = HEX_PATTERN.exec(css);
  if (hexMatch) {
    let hex = hexMatch[1];
    if (hex.length === 3) {
      hex = hex
        .split('')
        .map((c) => c + c)
        .join('');
    }
    return [parseInt(hex.slice(0, 2), 16), parseInt(hex.slice(2, 4), 16), parseInt(hex.slice(4, 6), 16)];
  }
  const rgbMatch = RGB_PATTERN.exec(css);
  if (rgbMatch) {
    return [Math.round(+rgbMatch[1]), Math.round(+rgbMatch[2]), Math.round(+rgbMatch[3])];
  }
  return [128, 128, 128];
}

/** Sample a d3 interpolator into a fixed-length discrete color range for deck.gl aggregation layers. */
export function interpolatorToColorRange(
  interpolator: (t: number) => string,
  steps = 7
): RgbColor[] {
  const colors: RgbColor[] = [];
  for (let i = 0; i < steps; i++) {
    const t = steps === 1 ? 0.5 : i / (steps - 1);
    colors.push(cssRgbToTuple(interpolator(t)));
  }
  return colors;
}

/**
 * For diverging palettes, center the domain on 0 when the data actually straddles zero,
 * otherwise center on the data's own midpoint so the palette's neutral color still means something.
 */
export function divergingColorDomain(min: number, max: number): [number, number] {
  const center = min < 0 && max > 0 ? 0 : (min + max) / 2;
  const halfSpan = Math.max(Math.abs(max - center), Math.abs(min - center)) || 1;
  return [center - halfSpan, center + halfSpan];
}

export function rgbToCss([r, g, b]: RgbColor): string {
  return `rgb(${r}, ${g}, ${b})`;
}

/** CSS gradient string for swatches / legends, sampled across the full domain of the interpolator. */
export function interpolatorToGradientCss(interpolator: (t: number) => string, stops = 10): string {
  const parts: string[] = [];
  for (let i = 0; i < stops; i++) {
    const t = i / (stops - 1);
    parts.push(`${interpolator(t)} ${Math.round((t * 100 + Number.EPSILON) * 100) / 100}%`);
  }
  return `linear-gradient(90deg, ${parts.join(', ')})`;
}
