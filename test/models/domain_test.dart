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
}
