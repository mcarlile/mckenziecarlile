import { DecimalPipe } from '@angular/common';
import { Component, computed, inject } from '@angular/core';
import { VizStateService } from '../../services/viz-state.service';
import { divergingColorDomain, interpolatorToGradientCss } from '../../core/color-utils';

@Component({
  selector: 'app-legend',
  standalone: true,
  imports: [DecimalPipe],
  template: `
    <div class="legend">
      <div class="legend-title">{{ state.selectedDataset().valueLabel }} ({{ state.selectedDataset().unit }})</div>
      <div class="legend-bar" [style.background]="gradient()"></div>
      <div class="legend-scale">
        <span>{{ domain()[0] | number: '1.0-1' }}</span>
        <span>{{ domain()[1] | number: '1.0-1' }}</span>
      </div>
    </div>
  `,
  styleUrl: './legend.component.css',
})
export class LegendComponent {
  readonly state = inject(VizStateService);

  readonly gradient = computed(() => interpolatorToGradientCss(this.state.selectedPalette().interpolator));

  readonly domain = computed<[number, number]>(() => {
    const dataset = this.state.selectedDataset();
    return this.state.paletteType() === 'diverging'
      ? divergingColorDomain(dataset.valueMin, dataset.valueMax)
      : [dataset.valueMin, dataset.valueMax];
  });
}
