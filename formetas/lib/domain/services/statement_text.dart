abstract final class StatementText {
  static String shorten(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = RegExp(
      r'^transfer[eê]ncia\s+(?:recebida|enviada)(?:\s+pelo)?(?:\s+pix)?\s*-\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return text;

    final party = match.group(1)!.split(RegExp(r'\s+-\s+')).first.trim();
    if (party.isEmpty) return text;
    final isPix = RegExp(r'\bpix\b', caseSensitive: false).hasMatch(text);
    return isPix ? 'Pix - $party' : 'Transferência - $party';
  }
}
