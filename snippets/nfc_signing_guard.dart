// Excerpt from NFC Crypto (apps/nfc_crypto/lib/core/nfc/nfc_signing_guard.dart). Shown for illustration only.
// The full source code is available at https://store.mikodes.com/p/nfccrypto/
//
// The last line of the card requirement. Every function that produces a signature calls
// ensureAuthorized() first, so a payment path that forgot the card prompt fails instead of
// signing. A passed card check grants a short window, long enough for approve-then-swap.

import 'package:flutter/foundation.dart';

import 'nfc_card_gate.dart';

/// Thrown by a signer when the NFC Crypto card is required for transactions
/// and was not just confirmed.
class NfcCardRequiredException implements Exception {
  const NfcCardRequiredException();

  @override
  String toString() =>
      'Confirm with your NFC Crypto card first (Settings → NFC Crypto Card).';
}

/// The last line of the card requirement, inside every signer.
///
/// The UI asks for the card where the user starts a payment, swap or dApp
/// transaction ([confirmTransactionWithCard]) and a passed check grants a
/// short window here. Every function that produces a signature calls
/// [ensureAuthorized] synchronously first, so a payment path that forgot the
/// prompt fails instead of signing without the card.
class NfcSigningGuard {
  NfcSigningGuard._();

  /// Long enough for one flow that signs more than once (approve, then swap).
  static const Duration window = Duration(seconds: 90);

  static DateTime? _grantedUntil;

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static bool get required {
    final s = NfcCardGateSettings.instance;
    return s.requireForTransactions && s.hasPairedCards;
  }

  static bool get authorized {
    final until = _grantedUntil;
    return !required || (until != null && now().isBefore(until));
  }

  /// Called after a paired card was read for a transaction.
  static void grant() => _grantedUntil = now().add(window);

  /// Called when the wallet locks.
  static void revoke() => _grantedUntil = null;

  static void ensureAuthorized() {
    if (!authorized) throw const NfcCardRequiredException();
  }
}
