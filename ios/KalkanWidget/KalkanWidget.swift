import WidgetKit
import SwiftUI

struct KalkanEntry: TimelineEntry {
    let date: Date
    let data: KalkanData
}

struct KalkanData {
    let recoveryScore: Int
    let recoveryZone: String
    let currentStrain: Double
    let targetStrainMax: Double
    let heartRate: Int
    let restingHeartRate: Int
    let hrv: Int
    let sleepHours: Int
    let sleepMinutes: Int
    let sleepScore: Int
    let morningLine: String
    let calibrationDay: Int
    let hasNightData: Bool

    static func load() -> KalkanData {
        let groupDefaults = UserDefaults(suiteName: "group.watch.circle.kalkan")
        let defaults = groupDefaults ?? UserDefaults.standard

        let score = defaults.object(forKey: "recovery_score") as? Int ?? 84
        let zone = defaults.string(forKey: "recovery_zone") ?? "optimal"
        let strain = defaults.double(forKey: "current_strain") > 0 ? defaults.double(forKey: "current_strain") : 11.4
        let targetStrain = defaults.double(forKey: "target_strain_max") > 0 ? defaults.double(forKey: "target_strain_max") : 14.0
        let hr = defaults.object(forKey: "heart_rate") as? Int ?? 68
        let rhr = defaults.object(forKey: "resting_heart_rate") as? Int ?? 52
        let hrvVal = defaults.object(forKey: "hrv") as? Int ?? 64
        let sHours = defaults.object(forKey: "sleep_hours") as? Int ?? 7
        let sMins = defaults.object(forKey: "sleep_minutes") as? Int ?? 35
        let sScore = defaults.object(forKey: "sleep_score") as? Int ?? 88
        let line = defaults.string(forKey: "morning_line") ?? "Тело готово к нагрузке"
        let calDay = defaults.object(forKey: "calibration_day") as? Int ?? 14
        let hasNight = defaults.bool(forKey: "has_night_data")

        return KalkanData(
            recoveryScore: score,
            recoveryZone: zone,
            currentStrain: strain,
            targetStrainMax: targetStrain,
            heartRate: hr > 0 ? hr : 68,
            restingHeartRate: rhr > 0 ? rhr : 52,
            hrv: hrvVal > 0 ? hrvVal : 64,
            sleepHours: sHours,
            sleepMinutes: sMins,
            sleepScore: sScore,
            morningLine: line,
            calibrationDay: calDay,
            hasNightData: hasNight
        )
    }

    static var preview: KalkanData {
        KalkanData(
            recoveryScore: 84,
            recoveryZone: "optimal",
            currentStrain: 11.4,
            targetStrainMax: 14.2,
            heartRate: 64,
            restingHeartRate: 52,
            hrv: 68,
            sleepHours: 7,
            sleepMinutes: 45,
            sleepScore: 91,
            morningLine: "Пиковая готовность к нагрузке",
            calibrationDay: 14,
            hasNightData: true
        )
    }
}

struct KalkanTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> KalkanEntry {
        KalkanEntry(date: Date(), data: KalkanData.preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (KalkanEntry) -> Void) {
        completion(KalkanEntry(date: Date(), data: KalkanData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KalkanEntry>) -> Void) {
        let entry = KalkanEntry(date: Date(), data: KalkanData.load())
        // Обновлять каждые 15 минут
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// Цвета KALKAN
private let colorBg = Color(red: 11/255, green: 12/255, blue: 14/255)
private let colorCard = Color(red: 18/255, green: 20/255, blue: 25/255)
private let colorBorder = Color(red: 35/255, green: 40/255, blue: 48/255)
private let colorSage = Color(red: 127/255, green: 160/255, blue: 136/255)
private let colorAmber = Color(red: 229/255, green: 169/255, blue: 60/255)
private let colorCoral = Color(red: 224/255, green: 90/255, blue: 71/255)
private let colorMuted = Color(red: 145/255, green: 152/255, blue: 165/255)

struct KalkanRecoveryWidget: Widget {
    let kind: String = "KalkanRecoveryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KalkanTimelineProvider()) { entry in
            KalkanWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("KALKAN Восстановление")
        .description("Готовность тела, пульс, HRV и нагрузка от датчика СААТ-1.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct KalkanWidgetEntryView: View {
    var entry: KalkanEntry
    @Environment(\.widgetFamily) var family

    var zoneColor: Color {
        if entry.data.recoveryScore >= 67 { return colorSage }
        if entry.data.recoveryScore >= 34 { return colorAmber }
        return colorCoral
    }

    var zoneTitle: String {
        if entry.data.recoveryScore >= 67 { return "ОПТИМАЛЬНО" }
        if entry.data.recoveryScore >= 34 { return "В НОРМЕ" }
        return "НИЗКОЕ"
    }

    var body: some View {
        ZStack {
            colorBg.ignoresSafeArea()

            switch family {
            case .systemSmall:
                smallView
            default:
                mediumView
            }
        }
    }

    // --- МАЛЫЙ ВИДЖЕТ (Small) ---
    var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("KALKAN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(colorMuted)
                    .tracking(1.2)
                Spacer()
                Circle()
                    .fill(zoneColor)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            HStack(spacing: 8) {
                // Кольцо готовности
                ZStack {
                    Circle()
                        .stroke(colorBorder, lineWidth: 5)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(Double(entry.data.recoveryScore) / 100.0, 0.05), 1.0)))
                        .stroke(zoneColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                    Text("\(entry.data.recoveryScore)%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(zoneTitle)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(zoneColor)
                        .tracking(0.5)

                    Text("STRAIN")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(colorMuted)
                    Text(String(format: "%.1f", entry.data.currentStrain))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundColor(colorCoral)
                    Text("\(entry.data.heartRate)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                HStack(spacing: 2) {
                    Text("HRV")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(colorMuted)
                    Text("\(entry.data.hrv)мс")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(colorCard)
            .cornerRadius(6)
        }
        .padding(12)
    }

    // --- СРЕДНИЙ ВИДЖЕТ (Medium) ---
    var mediumView: some View {
        HStack(spacing: 14) {
            // Левый блок: Восстановление
            VStack(spacing: 6) {
                HStack {
                    Text("KALKAN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(colorMuted)
                        .tracking(1.2)
                    Spacer()
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(colorBorder, lineWidth: 6)
                        .frame(width: 68, height: 68)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(Double(entry.data.recoveryScore) / 100.0, 0.05), 1.0)))
                        .stroke(zoneColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 68, height: 68)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(entry.data.recoveryScore)%")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("RECOVERY")
                            .font(.system(size: 6, weight: .bold, design: .monospaced))
                            .foregroundColor(colorMuted)
                    }
                }

                Spacer()

                Text(zoneTitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(zoneColor)
                    .tracking(0.8)
            }
            .frame(width: 90)

            // Разделитель
            Rectangle()
                .fill(colorBorder)
                .frame(width: 1)
                .padding(.vertical, 4)

            // Правый блок: Метрики
            VStack(alignment: .leading, spacing: 8) {
                // Нагрузка (Strain)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("ДНЕВНАЯ НАГРУЗКА")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(colorMuted)
                            .tracking(0.6)
                        Spacer()
                        Text("\(String(format: "%.1f", entry.data.currentStrain)) / \(String(format: "%.1f", entry.data.targetStrainMax))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorCard)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorAmber)
                                .frame(width: geo.size.width * CGFloat(min(entry.data.currentStrain / max(entry.data.targetStrainMax, 1.0), 1.0)), height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                // Сон
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("СОН")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(colorMuted)
                        Text("\(entry.data.sleepHours)ч \(entry.data.sleepMinutes)м")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("КАЧЕСТВО")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(colorMuted)
                        Text("\(entry.data.sleepScore)%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(colorSage)
                    }
                }
                .padding(6)
                .background(colorCard)
                .cornerRadius(6)

                // Пульс и HRV
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundColor(colorCoral)
                        Text("\(entry.data.heartRate) bpm")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 9))
                            .foregroundColor(colorSage)
                        Text("\(entry.data.hrv) ms")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(14)
    }
}
