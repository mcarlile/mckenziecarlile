import { Injectable, computed, signal } from '@angular/core';
import { DATASETS, Dataset, findDataset } from '../core/datasets';
import { PALETTES, Palette, PaletteType, findPalette } from '../core/palettes';

export type Basemap = 'dark' | 'light';

export interface HoverInfo {
  x: number;
  y: number;
  count: number;
  aggregatedValue: number;
}

@Injectable({ providedIn: 'root' })
export class VizStateService {
  readonly datasets = DATASETS;

  readonly selectedDatasetId = signal<string>(DATASETS[0].id);
  readonly selectedDataset = computed<Dataset>(() => findDataset(this.selectedDatasetId()));

  readonly paletteType = signal<PaletteType>(DATASETS[0].suggestedPaletteType);
  readonly paletteId = signal<string>(DATASETS[0].suggestedPaletteId);
  readonly selectedPalette = computed<Palette>(() => findPalette(this.paletteId()));
  readonly availablePalettes = computed<Palette[]>(() =>
    PALETTES.filter((p) => p.type === this.paletteType())
  );

  readonly radiusKm = signal(DATASETS[0].defaultRadiusKm);
  readonly opacity = signal(0.8);
  readonly coverage = signal(0.9);
  readonly extruded = signal(true);
  readonly elevationScale = signal(20);
  readonly lowerPercentile = signal(0);
  readonly upperPercentile = signal(100);
  readonly basemap = signal<Basemap>('dark');

  readonly hoverInfo = signal<HoverInfo | null>(null);

  selectDataset(id: string): void {
    const dataset = findDataset(id);
    this.selectedDatasetId.set(id);
    this.paletteType.set(dataset.suggestedPaletteType);
    this.paletteId.set(dataset.suggestedPaletteId);
    this.radiusKm.set(dataset.defaultRadiusKm);
    this.lowerPercentile.set(0);
    this.upperPercentile.set(100);
  }

  setPaletteType(type: PaletteType): void {
    if (type === this.paletteType()) return;
    this.paletteType.set(type);
    const first = PALETTES.find((p) => p.type === type);
    if (first) this.paletteId.set(first.id);
  }

  setPaletteId(id: string): void {
    this.paletteId.set(id);
  }

  setLowerPercentile(value: number): void {
    this.lowerPercentile.set(Math.min(value, this.upperPercentile()));
  }

  setUpperPercentile(value: number): void {
    this.upperPercentile.set(Math.max(value, this.lowerPercentile()));
  }

  toggleBasemap(): void {
    this.basemap.set(this.basemap() === 'dark' ? 'light' : 'dark');
  }
}
