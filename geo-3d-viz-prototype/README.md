# GeoViz 3D

A prototype Angular app for exploring geospatial datasets in 3D, inspired by kepler.gl. Built with:

- **[MapLibre GL JS](https://maplibre.org/)** — open-source (BSD) basemap renderer, no API key required (basemaps come from [CARTO's free vector tiles](https://carto.com/basemaps)).
- **[deck.gl](https://deck.gl/)** — WebGL layer engine, used here for the `HexagonLayer` that bins raw points into extruded 3D hexagons.
- **[d3-scale-chromatic](https://github.com/d3/d3-scale-chromatic)** — the sequential and diverging color ramps in the palette picker.

## What it does

The sidebar mirrors a kepler.gl-style layer panel: pick one of three synthetic sample datasets (rideshare trip density, a temperature anomaly grid, seismic magnitudes along the Pacific Ring of Fire), then explore how sequential vs. diverging palettes read against that data — swap ramps, adjust hex radius/coverage/opacity, toggle 3D extrusion and its height scale, and filter by aggregation percentile. The legend and hover tooltip stay in sync with whatever's selected.

Each dataset ships with a *suggested* palette type (sequential for one-directional counts/magnitudes, diverging for signed anomalies around a meaningful zero), but nothing stops you from picking the "wrong" one — seeing a diverging ramp mis-center on skewed data is part of the point.

All datasets are synthetic (deterministically generated, no external data fetch) so the app runs fully offline aside from the basemap tiles.

## Development

```bash
npm install
npm start        # ng serve, http://localhost:4200
```

```bash
npm run build     # production build to dist/geo-3d-viz-prototype
```

## Project layout

```
src/app/
├── core/                 Pure data/logic: sample datasets, palette definitions, color-space helpers
├── services/
│   └── viz-state.service.ts   Signal-based shared state (selected dataset, palette, layer params)
└── components/
    ├── map-view/         MapLibre + deck.gl HexagonLayer, hover tooltip
    ├── control-panel/    Sidebar: dataset picker, layer controls, sliders
    ├── palette-picker/   Sequential/diverging toggle + swatch grid
    └── legend/           Bottom-left color scale legend
```

## Notes / next steps

- Swap in real datasets by conforming to the `Dataset`/`GeoPoint` shape in `src/app/core/datasets.ts`.
- The `HexagonLayer` runs CPU-side aggregation (`gpuAggregation: false`); GPU aggregation hit a WebGL state bug on some MapLibre GL 6.x + deck.gl 9.3 combinations and CPU aggregation is plenty fast for a few thousand points.
- No basemap API key is needed, but the CARTO basemap URLs are a public convenience service — swap `BASEMAP_STYLES` in `map-view.component.ts` for a self-hosted style if you need an SLA.
