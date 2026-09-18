import { gaussian, mulberry32 } from './prng';
import type { PaletteType } from './palettes';

export interface GeoPoint {
  lng: number;
  lat: number;
  value: number;
}

export interface Dataset {
  id: string;
  name: string;
  description: string;
  valueLabel: string;
  unit: string;
  center: [number, number];
  zoom: number;
  pitch: number;
  suggestedPaletteType: PaletteType;
  suggestedPaletteId: string;
  /** Sensible starting hex radius for this dataset's geographic extent — a 2km hex is invisible at continental zoom. */
  defaultRadiusKm: number;
  points: GeoPoint[];
  valueMin: number;
  valueMax: number;
}

function valueRange(points: GeoPoint[]): { valueMin: number; valueMax: number } {
  let valueMin = Infinity;
  let valueMax = -Infinity;
  for (const p of points) {
    if (p.value < valueMin) valueMin = p.value;
    if (p.value > valueMax) valueMax = p.value;
  }
  return { valueMin, valueMax };
}

function ridesharePoints(): GeoPoint[] {
  const random = mulberry32(42);
  const hubs: Array<{ lng: number; lat: number; weight: number; spread: number }> = [
    { lng: -122.4, lat: 37.79, weight: 60, spread: 0.012 }, // Financial District
    { lng: -122.419, lat: 37.775, weight: 45, spread: 0.01 }, // Downtown / Union Sq
    { lng: -122.42, lat: 37.762, weight: 30, spread: 0.014 }, // Mission
    { lng: -122.431, lat: 37.802, weight: 25, spread: 0.01 }, // Marina
    { lng: -122.401, lat: 37.734, weight: 15, spread: 0.016 }, // Bayview
    { lng: -122.445, lat: 37.77, weight: 20, spread: 0.014 }, // Haight / Castro
    { lng: -122.389, lat: 37.615, weight: 18, spread: 0.01 }, // SFO
  ];
  const points: GeoPoint[] = [];
  for (const hub of hubs) {
    const count = Math.round(hub.weight * 12);
    for (let i = 0; i < count; i++) {
      const lng = gaussian(random, hub.lng, hub.spread);
      const lat = gaussian(random, hub.lat, hub.spread);
      const value = Math.max(1, Math.round(gaussian(random, hub.weight / 3, hub.weight / 6)));
      points.push({ lng, lat, value });
    }
  }
  return points;
}

function temperatureAnomalyPoints(): GeoPoint[] {
  const random = mulberry32(7);
  const points: GeoPoint[] = [];
  const latMin = 25,
    latMax = 49,
    lngMin = -124,
    lngMax = -67;
  const step = 0.6;
  for (let lat = latMin; lat <= latMax; lat += step) {
    for (let lng = lngMin; lng <= lngMax; lng += step) {
      // Smooth west-warmer / east-cooler gradient plus a few anomaly hot/cold spots and noise.
      const gradient = ((lng - lngMin) / (lngMax - lngMin) - 0.5) * -6;
      const spot1 = 4 * Math.exp(-((lng + 111) ** 2 + (lat - 40) ** 2) / 30); // Rockies warm anomaly
      const spot2 = -3.5 * Math.exp(-((lng + 90) ** 2 + (lat - 44) ** 2) / 25); // Upper Midwest cold anomaly
      const spot3 = 3 * Math.exp(-((lng + 81) ** 2 + (lat - 27) ** 2) / 15); // Florida warm anomaly
      const noise = gaussian(random, 0, 0.9);
      const value = gradient + spot1 + spot2 + spot3 + noise;
      points.push({ lng: lng + gaussian(random, 0, 0.08), lat: lat + gaussian(random, 0, 0.08), value });
    }
  }
  return points;
}

function seismicPoints(): GeoPoint[] {
  const random = mulberry32(1337);
  // Rough polyline tracing the Pacific Ring of Fire.
  const ring: Array<[number, number]> = [
    [-124, 40],
    [-122, 45],
    [-130, 55],
    [-150, 60],
    [-170, 55],
    [178, 52],
    [155, 45],
    [143, 38],
    [135, 33],
    [125, 15],
    [122, 5],
    [120, -8],
    [130, -20],
    [150, -25],
    [170, -20],
    [-178, -18],
    [-172, 0],
    [-170, 15],
    [-100, 15],
    [-92, 15],
    [-84, 10],
    [-78, 0],
    [-75, -10],
    [-72, -25],
    [-70, -35],
    [-72, -45],
  ];
  const points: GeoPoint[] = [];
  for (let i = 0; i < ring.length - 1; i++) {
    const [lng1, lat1] = ring[i];
    const [lng2, lat2] = ring[i + 1];
    const segments = 24;
    for (let s = 0; s < segments; s++) {
      const t = s / segments;
      const lng = lng1 + (lng2 - lng1) * t;
      const lat = lat1 + (lat2 - lat1) * t;
      const jitterCount = 1 + Math.floor(random() * 3);
      for (let j = 0; j < jitterCount; j++) {
        const jLng = lng + gaussian(random, 0, 2.2);
        const jLat = lat + gaussian(random, 0, 2.2);
        const value = Math.max(2, Math.min(8.5, gaussian(random, 4.2, 1.1)));
        points.push({ lng: jLng, lat: jLat, value });
      }
    }
  }
  return points;
}

const ridershare = ridesharePoints();
const temperatureAnomaly = temperatureAnomalyPoints();
const seismic = seismicPoints();

export const DATASETS: Dataset[] = [
  {
    id: 'rideshare-sf',
    name: 'Rideshare Trip Density — San Francisco',
    description:
      'Synthetic pickup density across SF hubs (Financial District, Mission, Marina, SFO). One-directional counts — a sequential palette reads best.',
    valueLabel: 'Trips',
    unit: 'trips',
    center: [-122.4194, 37.7749],
    zoom: 11.2,
    pitch: 45,
    suggestedPaletteType: 'sequential',
    suggestedPaletteId: 'viridis',
    defaultRadiusKm: 1.5,
    points: ridershare,
    ...valueRange(ridershare),
  },
  {
    id: 'temp-anomaly-us',
    name: 'Temperature Anomaly — Continental US',
    description:
      'Synthetic anomaly grid (°C vs. baseline) with a warm Rockies pocket, a cold Upper-Midwest pocket, and a Florida hot spot. Signed values around a zero midpoint — try a diverging palette.',
    valueLabel: 'Anomaly',
    unit: '°C',
    center: [-97, 38],
    zoom: 3.6,
    pitch: 40,
    suggestedPaletteType: 'diverging',
    suggestedPaletteId: 'rdbu',
    defaultRadiusKm: 55,
    points: temperatureAnomaly,
    ...valueRange(temperatureAnomaly),
  },
  {
    id: 'seismic-ring-of-fire',
    name: 'Seismic Magnitude — Pacific Ring of Fire',
    description:
      'Synthetic event magnitudes scattered along the Pacific Rim subduction zones. One-directional magnitude scale — sequential works, though a diverging scale can help isolate the strongest events.',
    valueLabel: 'Magnitude',
    unit: 'Mw',
    center: [180, 20],
    zoom: 1.6,
    pitch: 40,
    suggestedPaletteType: 'sequential',
    suggestedPaletteId: 'inferno',
    defaultRadiusKm: 120,
    points: seismic,
    ...valueRange(seismic),
  },
];

export function findDataset(id: string): Dataset {
  const found = DATASETS.find((d) => d.id === id);
  if (!found) throw new Error(`Unknown dataset: ${id}`);
  return found;
}
