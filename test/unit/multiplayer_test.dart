import 'package:flutter_test/flutter_test.dart';
import 'package:xobattle/helpers/constant.dart';

int computeScoreDelta(String result) {
  switch (result) {
    case 'win':
      return winScore;
    case 'lose':
      return -loseScore;
    case 'tie':
      return tieScore;
    default:
      return 0;
  }
}

void main() {
  group('score deltas', () {
    test('win adds winScore', () {
      expect(computeScoreDelta('win'), winScore);
    });

    test('lose subtracts loseScore', () {
      expect(computeScoreDelta('lose'), -loseScore);
    });

    test('tie adds tieScore', () {
      expect(computeScoreDelta('tie'), tieScore);
    });

    test('unknown result returns 0', () {
      expect(computeScoreDelta('unknown'), 0);
    });
  });
}
