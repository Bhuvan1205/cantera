import 'package:canteen_app/wallet/services/wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletService validation tests', () {
    test('validates deposit amount correctly within ₹20 - ₹500 limits', () {
      expect(WalletService.validateDepositAmount(''), equals('Please enter an amount.'));
      expect(WalletService.validateDepositAmount('abc'), equals('Enter a valid number.'));
      expect(WalletService.validateDepositAmount('10'), equals('Minimum deposit is ₹20.'));
      expect(WalletService.validateDepositAmount('1000'), equals('Maximum deposit is ₹500.'));
      expect(WalletService.validateDepositAmount('20'), isNull);
      expect(WalletService.validateDepositAmount('100'), isNull);
      expect(WalletService.validateDepositAmount('500'), isNull);
    });

    test('verifies deposit constraints constants', () {
      expect(WalletService.minDepositAmount, equals(20.0));
      expect(WalletService.maxDepositAmount, equals(500.0));
    });
  });
}
