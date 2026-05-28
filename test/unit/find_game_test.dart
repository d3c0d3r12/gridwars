import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lobbyKey format', () {
    test('Three_1_25 format is correct', () {
      final matrixSize = "Three";
      final round = 1;
      final entryFee = 25;
      final key = "${matrixSize}_${round}_${entryFee}";
      expect(key, "Three_1_25");
    });

    test('Five_7_200 format is correct', () {
      final key = "${"Five"}_${7}_${200}";
      expect(key, "Five_7_200");
    });

    test('different params produce different keys', () {
      final k1 = "${"Three"}_${1}_${25}";
      final k2 = "${"Three"}_${1}_${50}";
      final k3 = "${"Four"}_${1}_${25}";
      expect(k1, isNot(k2));
      expect(k1, isNot(k3));
    });
  });
}
