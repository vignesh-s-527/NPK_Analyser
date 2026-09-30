import 'package:flutter_test/flutter_test.dart';
import 'package:npk_farmer/models/domain.dart';

void main() {
  group('NpkResult validation', () {
    test('accepts finite non-negative mg/kg values', () {
      expect(const NpkResult(0, 18, 95).isValid, isTrue);
    });

    test('rejects negative, non-finite, and unsupported-unit readings', () {
      expect(const NpkResult(-1, 18, 95).isValid, isFalse);
      expect(const NpkResult(double.nan, 18, 95).isValid, isFalse);
      expect(const NpkResult(1, 2, 3, unit: 'ppm').isValid, isFalse);
    });

    test('keeps simulator provenance explicit', () {
      expect(const NpkResult(1, 2, 3, source: 'simulated').source, 'simulated');
    });
  });

  test('calendar task retains local identity and completion state', () {
    final when = DateTime.utc(2026, 10, 2, 9);
    final event = CalendarEvent('Watering', 'Water seedlings', when,
        id: 18, farmId: 4, completed: true);
    expect(event.id, 18);
    expect(event.farmId, 4);
    expect(event.date, when);
    expect(event.completed, isTrue);
  });
}
