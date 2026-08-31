import { DecimalPipe } from '@angular/common';
import { AfterViewInit, Component, ElementRef, OnDestroy, ViewChild, effect, inject } from '@angular/core';
import * as maplibregl from 'maplibre-gl';
import { MapboxOverlay } from '@deck.gl/mapbox';
import { HexagonLayer } from '@deck.gl/aggregation-layers';
import type { PickingInfo } from '@deck.gl/core';
import { VizStateService, Basemap } from '../../services/viz-state.service';
import { Dataset, GeoPoint } from '../../core/datasets';
import { Palette } from '../../core/palettes';
import { divergingColorDomain, interpolatorToColorRange } from '../../core/color-utils';

const BASEMAP_STYLES: Record<Basemap, string> = {
  dark: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
  light: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
};

@Component({
  selector: 'app-map-view',
  standalone: true,
  imports: [DecimalPipe],
  template: `
    <div class="map-root" #mapContainer></div>
    @if (state.hoverInfo(); as hover) {
      <div class="hex-tooltip" [style.left.px]="hover.x + 14" [style.top.px]="hover.y + 14">
        <div class="hex-tooltip-title">{{ state.selectedDataset().valueLabel }}</div>
        <div class="hex-tooltip-row">
          <span>Mean {{ state.selectedDataset().unit }}</span>
          <strong>{{ hover.aggregatedValue | number: '1.0-2' }}</strong>
        </div>
        <div class="hex-tooltip-row">
          <span>Points in bin</span>
          <strong>{{ hover.count }}</strong>
        </div>
      </div>
    }
  `,
  styleUrl: './map-view.component.css',
})
export class MapViewComponent implements AfterViewInit, OnDestroy {
  @ViewChild('mapContainer', { static: true }) mapContainerRef!: ElementRef<HTMLDivElement>;

  readonly state = inject(VizStateService);

  private map?: maplibregl.Map;
  private overlay?: MapboxOverlay;
  private appliedBasemap: Basemap | null = null;

  constructor() {
    effect(() => {
      const dataset = this.state.selectedDataset();
      const palette = this.state.selectedPalette();
      const radiusKm = this.state.radiusKm();
      const opacity = this.state.opacity();
      const coverage = this.state.coverage();
      const extruded = this.state.extruded();
      const elevationScale = this.state.elevationScale();
      const lowerPercentile = this.state.lowerPercentile();
      const upperPercentile = this.state.upperPercentile();
      const paletteType = this.state.paletteType();

      this.rebuildLayer(
        dataset,
        palette,
        paletteType,
        radiusKm,
        opacity,
        coverage,
        extruded,
        elevationScale,
        lowerPercentile,
        upperPercentile
      );
    });

    effect(() => {
      this.applyBasemap(this.state.basemap());
    });

    effect(() => {
      this.flyTo(this.state.selectedDataset());
    });
  }

  ngAfterViewInit(): void {
    const initialDataset = this.state.selectedDataset();
    this.appliedBasemap = this.state.basemap();

    this.map = new maplibregl.Map({
      container: this.mapContainerRef.nativeElement,
      style: BASEMAP_STYLES[this.appliedBasemap],
      center: initialDataset.center,
      zoom: initialDataset.zoom,
      pitch: initialDataset.pitch,
      bearing: -12,
    });

    this.map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), 'top-right');

    this.overlay = new MapboxOverlay({ interleaved: false, layers: [] });
    this.map.addControl(this.overlay as unknown as maplibregl.IControl);

    this.map.on('load', () => {
      this.rebuildLayer(
        this.state.selectedDataset(),
        this.state.selectedPalette(),
        this.state.paletteType(),
        this.state.radiusKm(),
        this.state.opacity(),
        this.state.coverage(),
        this.state.extruded(),
        this.state.elevationScale(),
        this.state.lowerPercentile(),
        this.state.upperPercentile()
      );
    });
  }

  ngOnDestroy(): void {
    this.map?.remove();
  }

  private rebuildLayer(
    dataset: Dataset,
    palette: Palette,
    paletteType: 'sequential' | 'diverging',
    radiusKm: number,
    opacity: number,
    coverage: number,
    extruded: boolean,
    elevationScale: number,
    lowerPercentile: number,
    upperPercentile: number
  ): void {
    if (!this.overlay) return;

    const colorRange = interpolatorToColorRange(palette.interpolator, 7);
    const colorDomain =
      paletteType === 'diverging' ? divergingColorDomain(dataset.valueMin, dataset.valueMax) : undefined;

    const layer = new HexagonLayer<GeoPoint>({
      id: 'geo-hexagon-layer',
      data: dataset.points,
      pickable: true,
      autoHighlight: true,
      gpuAggregation: false,
      extruded,
      radius: radiusKm * 1000,
      elevationScale,
      coverage,
      opacity,
      lowerPercentile,
      upperPercentile,
      colorRange,
      colorDomain,
      getPosition: (d: GeoPoint) => [d.lng, d.lat],
      getColorWeight: (d: GeoPoint) => d.value,
      colorAggregation: 'MEAN',
      getElevationWeight: (d: GeoPoint) => d.value,
      elevationAggregation: 'MEAN',
      material: { ambient: 0.4, diffuse: 0.6, shininess: 32, specularColor: [60, 64, 70] },
      transitions: { elevationScale: 300 },
      onHover: (info: PickingInfo): boolean => {
        if (info.object) {
          this.state.hoverInfo.set({
            x: info.x,
            y: info.y,
            count: info.object.count ?? 0,
            aggregatedValue: info.object.colorValue ?? 0,
          });
        } else {
          this.state.hoverInfo.set(null);
        }
        return false;
      },
    });

    this.overlay.setProps({ layers: [layer] });
  }

  private applyBasemap(basemap: Basemap): void {
    if (!this.map || this.appliedBasemap === basemap) return;
    this.appliedBasemap = basemap;
    this.map.setStyle(BASEMAP_STYLES[basemap]);
  }

  private flyTo(dataset: Dataset): void {
    if (!this.map) return;
    this.map.flyTo({ center: dataset.center, zoom: dataset.zoom, pitch: dataset.pitch, duration: 1200 });
  }
}
