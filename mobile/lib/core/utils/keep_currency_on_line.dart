/// An amount on one line (D118): every space inside it is a no-break space,
/// so a line never breaks inside an amount: not before «ر.ي», not between a
/// number and «مليون». («ر.ي» itself never breaks at its dot: a line break
/// never falls between a dot and the letter after it, Unicode UAX #14 LB29.)
/// The one implementation; every reading of the money formatter goes
/// through it.
String keepCurrencyOnLine(String amount) => amount.replaceAll(' ', '\u00a0');
