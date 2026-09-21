import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Workout Activity Attributes & Content State
struct KalkanWorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentHeartRate: Int
        var heartRateZone: Int // 1 (Recovery), 2 (Aerobic), 3 (Tempo), 4 (Threshold), 5 (Anaerobic)
        var currentStrain: Double
        var activeCalories: Int
        var workoutType: String
    }
    
    var workoutName: String
    var startTime: Date
}

// MARK: - Dynamic Island & Lock Screen Live Activity
struct KalkanWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KalkanWorkoutAttributes.self) { context in
            // MARK: Lock Screen / Banner Live Activity View
            LockScreenWorkoutBanner(context: context)
                .activityBackgroundTint(Color(red: 0x08/255.0, green: 0x09/255.0, blue: 0x0C/255.0))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            // MARK: Dynamic Island Configuration
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(zoneColor(for: context.state.heartRateZone))
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(context.state.currentHeartRate)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("ZONE \(context.state.heartRateZone)")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(zoneColor(for: context.state.heartRateZone))
                        }
                    }
                    .padding(.leading, 8)
                }

                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 2) {
                            Text(String(format: "%.1f", context.state.currentStrain))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0xDE/255.0, green: 0x8A/255.0, blue: 0x36/255.0))
                            Text("STR")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        Text("\(context.state.activeCalories) KCAL")
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }

                // Expanded Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Timer
                        HStack {
                            Text(context.state.workoutType.uppercased())
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(timerInterval: context.attributes.startTime...Date.distantFuture, countsDown: false)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }

                        // 5-Zone Bar
                        GeometryReader { geo in
                            HStack(spacing: 3) {
                                ForEach(1...5, id: \.self) { zone in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(zone <= context.state.heartRateZone ? zoneColor(for: zone) : Color(white: 0.18))
                                        .frame(height: 5)
                                }
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                // Dynamic Island Compact Leading
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(zoneColor(for: context.state.heartRateZone))
                        .font(.system(size: 10))
                    Text("\(context.state.currentHeartRate)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                // Dynamic Island Compact Trailing
                Text(String(format: "%.1f", context.state.currentStrain))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0xDE/255.0, green: 0x8A/255.0, blue: 0x36/255.0))
            } minimal: {
                Image(systemName: "heart.fill")
                    .foregroundColor(zoneColor(for: context.state.heartRateZone))
                    .font(.system(size: 11))
            }
        }
    }

    private func zoneColor(for zone: Int) -> Color {
        switch zone {
        case 1: return Color(red: 0x8A/255.0, green: 0x90/255.0, blue: 0x9D/255.0)
        case 2: return Color(red: 0x52/255.0, green: 0xB7/255.0, blue: 0x88/255.0) // Sage
        case 3: return Color(red: 0xDE/255.0, green: 0x8A/255.0, blue: 0x36/255.0) // Amber
        case 4: return Color(red: 0xD1/255.0, green: 0x49/255.0, blue: 0x49/255.0) // Rose
        default: return Color(red: 0xFF/255.0, green: 0x3B/255.0, blue: 0x30/255.0) // Deep red
        }
    }
}

// MARK: - Lock Screen Banner View
struct LockScreenWorkoutBanner: View {
    let context: ActivityViewContext<KalkanWorkoutAttributes>

    var body: some View {
        HStack(spacing: 14) {
            // Heart Rate & Zone
            VStack(alignment: .leading, spacing: 2) {
                Text("HEART RATE")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(white: 0.6))
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(context.state.currentHeartRate)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0xD1/255.0, green: 0x49/255.0, blue: 0x49/255.0))
                    Text("BPM")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                }
                Text("ZONE \(context.state.heartRateZone)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0x52/255.0, green: 0xB7/255.0, blue: 0x88/255.0))
            }
            .frame(width: 85, alignment: .leading)

            Rectangle()
                .fill(Color(white: 0.2))
                .frame(width: 1, height: 38)

            // Elapsed Timer & Strain
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(context.state.workoutType.uppercased())
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                    Spacer()
                    Text(timerInterval: context.attributes.startTime...Date.distantFuture, countsDown: false)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                HStack {
                    Text("DAY STRAIN: \(String(format: "%.1f", context.state.currentStrain))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0xDE/255.0, green: 0x8A/255.0, blue: 0x36/255.0))
                    Spacer()
                    Text("\(context.state.activeCalories) KCAL")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(white: 0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
