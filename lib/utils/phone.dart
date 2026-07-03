/// Cleans a user-entered phone number so it can be placed in a `tel:` or
/// `sms:` URI without the dialer rejecting it. Strips spaces, dashes and
/// parentheses, keeping a single leading `+` (international prefix) and digits.
String sanitizePhoneNumber(String raw) {
  final trimmed = raw.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}
