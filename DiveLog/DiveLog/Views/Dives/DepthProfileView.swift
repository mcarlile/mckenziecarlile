import SwiftUI
import Charts

struct DepthProfileView: View {
    let dive: Dive
    var compact: Bool = false

    private var samples: [DepthSample] { dive.profile }

    private var maxDepth: Double { samples.map(\.depth).max() ?? 1 }
    private var totalSeconds: Double { samples.last?.elapsedSeconds ?? dive.duration }

    var body: some View {
        if samples.isEmpty {
            emptyState
        } else {
            chart
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 10) {
            if !compact {
                chartLegend
            }
            Chart(samples) { sample in
                AreaMark(
                    x: .value("Time", sample.elapsedSeconds),
                    yStart: .value("Surface", 0),
                    yEnd: .value("Depth", sample.depth)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.7, blue: 1.0).opacity(0.8),
                            Color(red: 0.0, green: 0.2, blue: 0.7).opacity(0.9),
                            Color(red: 0.0, green: 0.05, blue: 0.4),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", sample.elapsedSeconds),
                    y: .value("Depth", sample.depth)
                )
                .foregroundStyle(Color.cyan.opacity(0.9))
                .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: maxDepth * 1.12 ... 0)  // Inverted: deeper = down
            .chartXScale(domain: 0 ... totalSeconds)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: compact ? 3 : 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(String(format: "%.0fm", d))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: compact ? 3 : 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel {
                        if let s = value.as(Double.self) {
                            Text(formatMinutes(s))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(height: compact ? 80 : 200)
        }
    }

    private var chartLegend: some View {
        HStack(spacing: 16) {
            legendItem(color: .cyan, label: "Depth Profile")
            Spacer()
            statBadge(value: dive.maxDepthFormatted, label: "MAX DEPTH")
            statBadge(value: String(format: "%.1fm", dive.avgDepth), label: "AVG DEPTH")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.cyan)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .kerning(0.5)
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.white.opacity(0.2))
                    .font(.title2)
                Text("No depth data")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(height: compact ? 80 : 200)
            Spacer()
        }
    }

    private func formatMinutes(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        return "\(m)m"
    }
}
