import { Component } from '@angular/core';
import { ControlPanelComponent } from './components/control-panel/control-panel.component';
import { MapViewComponent } from './components/map-view/map-view.component';
import { LegendComponent } from './components/legend/legend.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [ControlPanelComponent, MapViewComponent, LegendComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
})
export class AppComponent {}
