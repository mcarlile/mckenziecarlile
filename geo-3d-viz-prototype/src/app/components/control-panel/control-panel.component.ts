import { DecimalPipe } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { VizStateService } from '../../services/viz-state.service';
import { PalettePickerComponent } from '../palette-picker/palette-picker.component';

@Component({
  selector: 'app-control-panel',
  standalone: true,
  imports: [FormsModule, DecimalPipe, PalettePickerComponent],
  templateUrl: './control-panel.component.html',
  styleUrl: './control-panel.component.css',
})
export class ControlPanelComponent {
  readonly state = inject(VizStateService);

  onDatasetChange(id: string): void {
    this.state.selectDataset(id);
  }

  onRadiusChange(value: number): void {
    this.state.radiusKm.set(value);
  }

  onOpacityChange(value: number): void {
    this.state.opacity.set(value);
  }

  onCoverageChange(value: number): void {
    this.state.coverage.set(value);
  }

  onElevationScaleChange(value: number): void {
    this.state.elevationScale.set(value);
  }

  onLowerPercentileChange(value: number): void {
    this.state.setLowerPercentile(value);
  }

  onUpperPercentileChange(value: number): void {
    this.state.setUpperPercentile(value);
  }
}
