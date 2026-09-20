import WidgetKit
import SwiftUI

// MARK: - App Group Configuration
let appGroupId = "group.watch.circle.kalkan"

// MARK: - Biometric Entry Model
struct BiometricEntry: TimelineEntry {
    let date: Date
    let recoveryScore: Int
    let recoveryZone: String // "optimal", "moderate", "reduced"
    let currentStrain: Double
    let targetStrainMax: Double
    let heartRate: Int
    let restingHeartRate: Int
    let hrv: Int
    let sleepHours: Int
    let sleepMinutes: Int
    let sleepScore: Int
}

// MARK: - Timeline Provider
struct BiometricProvider: TimelineProvider {
    func placeholder(in context: Context) -> BiometricEntry {
        BiometricEntry(
            date: Date(),
            recoveryScore: 94,
            recoveryZone: "optimal",
            currentStrain: 12.4,
            targetStrainMax: 13.8,
            heartRate: 72,
            restingHeartRate: 52,
            hrv: 64,
            sleepHours: 7,
            sleepMinutes: 48,
            sleepScore: 88
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BiometricEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BiometricEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> BiometricEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let score = defaults?.integer(forKey: "recovery_score") ?? 94
        let zone = defaults?.string(forKey: "recovery_zone") ?? "optimal"
        let strain = defaults?.double(forKey: "current_strain") ?? 12.4
        let targetMax = defaults?.double(forKey: "target_strain_max") ?? 13.8
        let bpm = defaults?.integer(forKey: "heart_rate") ?? 72
        let rhr = defaults?.integer(forKey: "resting_heart_rate") ?? 52
        let hrvVal = defaults?.integer(forKey: "hrv") ?? 64
        let sHours = defaults?.integer(forKey: "sleep_hours") ?? 7
        let sMins = defaults?.integer(forKey: "sleep_minutes") ?? 48
        let sScore = defaults?.integer(forKey: "sleep_score") ?? 88

        return BiometricEntry(
            date: Date(),
            recoveryScore: score == 0 ? 94 : score,
            recoveryZone: zone,
            currentStrain: strain == 0.0 ? 12.4 : strain,
            targetStrainMax: targetMax == 0.0 ? 13.8 : targetMax,
            heartRate: bpm == 0 ? 72 : bpm,
            restingHeartRate: rhr == 0 ? 52 : rhr,
            hrv: hrvVal == 0 ? 64 : hrvVal,
            sleepHours: sHours == 0 ? 7 : sHours,
            sleepMinutes: sMins == 0 ? 48 : sMins,
            sleepScore: sScore == 0 ? 88 : sScore
        )
    }
}

// MARK: - Color Palette Tokens (Precision Obsidian)
struct KalkanColors {
    static let obsidian = Color(red: 0x08 / 255.0, green: 0x09 / 255.0, blue: 0x0C / 255.0)
    static let surface = Color(red: 0x0E / 255.0, green: 0x10 / 255.0, blue: 0x15 / 255.0)
    static let hairline = Color(red: 0x1C / 255.0, green: 0x20 / 255.0, blue: 0x29 / 255.0)
    static let raised = Color(red: 0x16 / 255.0, green: 0x19 / 255.0, blue: 0x22 / 255.0)
    static let textNearWhite = Color(red: 0xED / 255.0, green: 0xED / 255.0, blue: 0xED / 255.0)
    static let textSecondary = Color(red: 0x8A / 255.0, green: 0x90 / 255.0, blue: 0x9D / 255.0)
    static let textMuted = Color(red: 0x45 / 255.0, green: 0x4B / 255.0, blue: 0x59 / 255.0)

    static let sage = Color(red: 0x52 / 255.0, green: 0xB7 / 255.0, blue: 0x88 / 255.0)
    static let amber = Color(red: 0xDE / 255.0, green: 0x8A / 255.0, blue: 0x36 / 255.0)
    static let rose = Color(red: 0xD1 / 255.0, green: 0x49 / 255.0, blue: 0x49 / 255.0)
}

// MARK: - Widget Views
struct KalkanRecoveryWidgetEntryView: View {
    var entry: BiometricProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallRecoveryView(entry: entry)
        case .systemMedium:
            MediumDashboardView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        default:
            SmallRecoveryView(entry: entry)
        }
    }
}

// MARK: - Small Widget (System Small)
struct SmallRecoveryView: View {
    let entry: BiometricEntry

    var zoneColor: Color {
        if entry.recoveryScore >= 66 { return KalkanColors.sage }
        if entry.recoveryScore >= 33 { return KalkanColors.amber }
        return KalkanColors.rose
    }

    var body: some View {
        ZStack {
            KalkanColors.obsidian.edgesIgnoringSafeArea(.all)

            VStack(spacing: 6) {
                HStack {
                    Text("RECOVERY")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(KalkanColors.textSecondary)
                    Spacer()
                    Circle()
                        .fill(zoneColor)
                        .frame(width: 5, height: 5)
                }

                // Precision Ring
                ZStack {
                    Circle()
                        .stroke(KalkanColors.raised, lineWidth: 6)
                        .frame(width: 76, height: 76)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(entry.recoveryScore) / 100.0)
                        .stroke(zoneColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 76, height: 76)

                    VStack(spacing: 0) {
                        Text("\(entry.recoveryScore)")
                            .font(.system(size: 26, weight: .semibold, design: .default))
                            .foregroundColor(KalkanColors.textNearWhite)
                        Text("%")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(KalkanColors.textMuted)
                    }
                }

                HStack(spacing: 12) {
                    VStack(spacing: 1) {
                        Text("HRV")
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(KalkanColors.textMuted)
                        Text("\(entry.hrv) ms")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(KalkanColors.textNearWhite)
                    }

                    Rectangle()
                        .fill(KalkanColors.hairline)
                        .frame(width: 1, height: 16)

                    VStack(spacing: 1) {
                        Text("RHR")
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(KalkanColors.textMuted)
                        Text("\(entry.restingHeartRate) bpm")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(KalkanColors.textNearWhite)
                    }
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Medium Widget (System Medium)
struct MediumDashboardView: View {
    let entry: BiometricEntry

    var zoneColor: Color {
        if entry.recoveryScore >= 66 { return KalkanColors.sage }
        if entry.recoveryScore >= 33 { return KalkanColors.amber }
        return KalkanColors.rose
    }

    var body: some View {
        ZStack {
            KalkanColors.obsidian.edgesIgnoringSafeArea(.all)

            HStack(spacing: 14) {
                // Left: Recovery Ring
                VStack(spacing: 4) {
                    Text("RECOVERY")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(KalkanColors.textSecondary)

                    ZStack {
                        Circle()
                            .stroke(KalkanColors.raised, lineWidth: 6)
                            .frame(width: 74, height: 74)

                        Circle()
                            .trim(from: 0.0, to: CGFloat(entry.recoveryScore) / 100.0)
                            .stroke(zoneColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 74, height: 74)

                        Text("\(entry.recoveryScore)%")
                            .font(.system(size: 20, weight: .semibold, design: .default))
                            .foregroundColor(KalkanColors.textNearWhite)
                    }

                    Text("OPTIMAL")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(zoneColor)
                }
                .frame(width: 100)

                Rectangle()
                    .fill(KalkanColors.hairline)
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Right: 3 Biometric Rows
                VStack(alignment: .leading, spacing: 10) {
                    // Day Strain
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("DAY STRAIN")
                                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(KalkanColors.textSecondary)
                            Spacer()
                            Text(String(format: "%.1f", entry.currentStrain))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(KalkanColors.amber)
                            Text("/ 21.0")
                                .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                                .foregroundColor(KalkanColors.textMuted)
                        }

                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(KalkanColors.raised)
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(KalkanColors.amber)
                                    .frame(width: geo.size.width * CGFloat(entry.currentStrain / 21.0), height: 5)
                            }
                        }
                        .frame(height: 5)
                    }

                    // Live Heart Rate
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("HEART RATE")
                                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(KalkanColors.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(entry.heartRate)")
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                    .foregroundColor(KalkanColors.rose)
                                Text("BPM")
                                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                                    .foregroundColor(KalkanColors.textMuted)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("SLEEP DURATION")
                                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(KalkanColors.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(entry.sleepHours)H \(entry.sleepMinutes)M")
                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                    .foregroundColor(KalkanColors.textNearWhite)
                                Text("(\(entry.sleepScore)%)")
                                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                                    .foregroundColor(KalkanColors.sage)
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Lock Screen Circular Widget (iOS 16+)
struct LockScreenCircularView: View {
    let entry: BiometricEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.recoveryScore)")
                    .font(.system(size: 20, weight: .bold))
                Text("RECOVERY")
                    .font(.system(size: 6, weight: .bold))
            }
        }
    }
}

// MARK: - Lock Screen Rectangular Widget (iOS 16+)
struct LockScreenRectangularView: View {
    let entry: BiometricEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("KALKAN")
                    .font(.system(size: 9, weight: .bold))
                Spacer()
                Text("\(entry.recoveryScore)% RECOVERY")
                    .font(.system(size: 9, weight: .bold))
            }
            Text("Strain: \(String(format: "%.1f", entry.currentStrain)) · HR: \(entry.heartRate) bpm")
                .font(.system(size: 11))
            Text("Sleep: \(entry.sleepHours)h \(entry.sleepMinutes)m · \(entry.sleepScore)%")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Main Widget Declaration
struct KalkanRecoveryWidget: Widget {
    let kind: String = "KalkanRecoveryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BiometricProvider()) { entry in
            KalkanRecoveryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("KALKAN Recovery")
        .description("Отслеживайте готовность к тренировкам, нагрузку и сон в реальном времени.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}
