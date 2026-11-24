// Excerpt from NFC Crypto (apps/nfc_crypto/lib/core/nfc/nfc_spend_policy.dart). Shown for illustration only. The full source code is available at https://store.mikodes.com/p/nfccrypto/
//
// Spender cards get a daily limit per network. This sums what a card approved
// in the last 24 hours (a rolling window, not a calendar day) and refuses any
// payment that would go over, so a lost spending card has a capped loss.
// Types such as PairedNfcCard, NfcSpendRecord and NfcSpendDecision are cut.


/// Daily limits of Spender cards: a rolling 24-hour window per card and
/// network, enforced by this app on this phone.
///
/// The amount sent counts, not the network fee. Payments an Owner or Backup
/// card approved do not use a Spender's limit. A payment counts from the
/// moment the card approves it, even if it later fails to send: the limit
/// errs on the side of the owner.
abstract final class NfcSpendPolicy {
  static const Duration window = Duration(hours: 24);

  /// Approved by [cardId] on [chainKey] within [window] before [now].
  static BigInt spentInWindow(
    List<NfcSpendRecord> records, {
    required String cardId,
    required String chainKey,
    required DateTime now,
  }) {
    final since = now.subtract(window);
    var total = BigInt.zero;
    for (final r in records) {
      if (r.cardId == cardId &&
          r.chainKey == chainKey &&
          r.at.isAfter(since) &&
          !r.at.isAfter(now)) {
        total += r.amount;
      }
    }
    return total;
  }

  /// Whether [card] may approve [request] (null: a transaction that is not a
  /// plain coin payment — a token, swap, dApp or approval change).
  static NfcSpendDecision check({
    required PairedNfcCard card,
    required NfcSpendRequest? request,
    required List<NfcSpendRecord> records,
    required DateTime now,
  }) {
    final role = card.role;
    if (role.canApprove) {
      return NfcSpendDecision._(allowed: true, role: role);
    }
    if (request == null) {
      return NfcSpendDecision._(
        allowed: false,
        role: role,
        reason: 'A Spender card approves coin payments only. Hold an Owner '
            'or Backup card.',
      );
    }
    final chain = request.chain;
    final limit = card.limitFor(chain.key);
    final spent = spentInWindow(
      records,
      cardId: card.id,
      chainKey: chain.key,
      now: now,
    );
    final allowed = request.amount > BigInt.zero &&
        limit > BigInt.zero &&
        spent + request.amount <= limit;
    String? reason;
    if (!allowed) {
      reason = limit == BigInt.zero
          ? '${card.label} has no daily limit on ${chain.name}. Hold an '
              'Owner or Backup card.'
          : 'Over the daily limit of ${card.label}: '
              '${chain.format(limit)} ${chain.symbol} a day, '
              '${chain.format(spent)} ${chain.symbol} used in the last 24 '
              'hours. Hold an Owner or Backup card.';
    }
    return NfcSpendDecision._(
      allowed: allowed,
      role: role,
      limit: limit,
      spent: spent,
      reason: reason,
    );
  }

  /// [records] without the ones older than [window] before [now].
  static List<NfcSpendRecord> prune(List<NfcSpendRecord> records, DateTime now) {
    final since = now.subtract(window);
    return records.where((r) => r.at.isAfter(since)).toList();
  }
}
