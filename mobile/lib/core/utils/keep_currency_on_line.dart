/// An amount inside a sentence: «ر.ي» never wraps alone to the next line.
String keepCurrencyOnLine(String amount) {
  final beforeCurrency = amount.lastIndexOf(' ');
  if (beforeCurrency < 0) return amount;
  return amount.replaceRange(
    beforeCurrency,
    beforeCurrency + 1,
    String.fromCharCode(0x00A0),
  );
}
