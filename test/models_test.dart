import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/domain/models/user_profile.dart';
import 'package:barys_biotracker/domain/models/workout_session.dart';
import 'package:barys_biotracker/presentation/widgets/circa_share_card_widget.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('Default profile has expected values and BMI calculation', () {
      const profile = UserProfile();
      expect(profile.name, 'Алихан');
      expect(profile.heightCm, 178);
      expect(profile.weightKg, 74.5);
      expect(profile.birthYear, 1992);
      expect(profile.bmi, closeTo(23.51, 0.1));
      expect(profile.age, greaterThanOrEqualTo(30));
      expect(profile.stepGoal, 10000);
      expect(profile.calorieGoal, 650);
    });

    test('UserProfile JSON serialization roundtrip', () {
      const profile = UserProfile(
        id: 'test_user_02',
        name: 'Динара Т.',
        email: 'dinara@circa.ai',
        heightCm: 165,
        weightKg: 58.0,
        birthYear: 1996,
        gender: Gender.female,
        cyclePhase: HormonalCyclePhase.luteal,
        stepGoal: 12000,
        calorieGoal: 500,
        is24HourFormat: false,
        isMetric: true,
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.id, 'test_user_02');
      expect(restored.name, 'Динара Т.');
      expect(restored.email, 'dinara@circa.ai');
      expect(restored.heightCm, 165);
      expect(restored.weightKg, 58.0);
      expect(restored.gender, Gender.female);
      expect(restored.cyclePhase, HormonalCyclePhase.luteal);
      expect(restored.stepGoal, 12000);
      expect(restored.calorieGoal, 500);
      expect(restored.is24HourFormat, false);
      expect(restored.isMetric, true);
    });
  });

  group('WorkoutSession Model Tests', () {
    test('CompletedWorkout JSON serialization and formatting', () {
      final workout = CompletedWorkout(
        id: 'test-123',
        sport: SportType.strength,
        startedAt: DateTime(2026, 9, 20, 10, 30),
        durationSeconds: 3665, // 1h 1m 5s
        calories: 480,
        distanceKm: 0.0,
        avgHr: 138,
        maxHr: 165,
        strain: 12.4,
        xpEarned: 120,
      );

      expect(workout.durationFormatted, '1ч 1м');

      final json = workout.toJson();
      final restored = CompletedWorkout.fromJson(json);

      expect(restored.id, 'test-123');
      expect(restored.sport, SportType.strength);
      expect(restored.strain, 12.4);
      expect(restored.avgHr, 138);
      expect(restored.maxHr, 165);
      expect(restored.calories, 480);
      expect(restored.xpEarned, 120);
    });
  });

  group('Avatar Visual States and Ritual Quotes', () {
    test('All 6 states have valid assets and badge texts', () {
      for (final state in AvatarVisualState.values) {
        expect(state.title.isNotEmpty, isTrue);
        expect(state.badgeText.isNotEmpty, isTrue);
        expect(state.assetPath.isNotEmpty, isTrue);
        expect(state.description.isNotEmpty, isTrue);
        expect(state.xpBonusMultiplier, greaterThan(0.0));
      }
    });

    test('Ritual quotes generate specific directives for all states', () {
      final sleepQuote = AvatarManager.getRitualQuote(AvatarVisualState.sleep);
      expect(sleepQuote, contains('ночного отбоя'));

      final workoutQuote = AvatarManager.getRitualQuote(AvatarVisualState.postWorkout);
      expect(workoutQuote, contains('водный баланс'));

      final tiredQuote = AvatarManager.getRitualQuote(AvatarVisualState.tired);
      expect(tiredQuote, contains('22:40'));

      final chargedQuote = AvatarManager.getRitualQuote(AvatarVisualState.charged);
      expect(chargedQuote, contains('Strain'));
    });
  });

  group('Quiet Luxury Share Card Tests', () {
    test('All 3 share card themes have valid labels and uppercase codes', () {
      expect(ShareCardTheme.values.length, equals(3));
      for (final theme in ShareCardTheme.values) {
        expect(theme.label.isNotEmpty, isTrue);
        expect(theme.code.isNotEmpty, isTrue);
        expect(theme.code, equals(theme.code.toUpperCase()));
      }
    });
  });
}
