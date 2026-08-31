import { Component, inject } from '@angular/core';
import { VizStateService } from '../../services/viz-state.service';
import { PaletteType } from '../../core/palettes';
import { interpolatorToGradientCss } from '../../core/color-utils';

@Component({
  selector: 'app-palette-picker',
  standalone: true,
  template: `
    <div class="type-toggle" role="tablist" aria-label="Palette type">
      @for (type of paletteTypes; track type) {
        <button
          type="button"
          role="tab"
          class="type-btn"
          [class.active]="state.paletteType() === type"
          [attr.aria-selected]="state.paletteType() === type"
          (click)="state.setPaletteType(type)"
        >
          {{ type === 'sequential' ? 'Sequential' : 'Diverging' }}
        </button>
      }
    </div>

    <div class="swatch-grid">
      @for (palette of state.availablePalettes(); track palette.id) {
        <button
          type="button"
          class="swatch"
          [class.active]="state.paletteId() === palette.id"
          [style.background]="gradientFor(palette.interpolator)"
          [attr.aria-pressed]="state.paletteId() === palette.id"
          (click)="state.setPaletteId(palette.id)"
          title="{{ palette.name }}"
        >
          <span class="swatch-label">{{ palette.name }}</span>
        </button>
      }
    </div>
  `,
  styleUrl: './palette-picker.component.css',
})
export class PalettePickerComponent {
  readonly state = inject(VizStateService);
  readonly paletteTypes: PaletteType[] = ['sequential', 'diverging'];

  gradientFor(interpolator: (t: number) => string): string {
    return interpolatorToGradientCss(interpolator);
  }
}
