// Numbers typed on an Arabic keyboard (RA-AD-16). The server reads Latin
// digits only, as the mobile app sends them (money_input_formatter.dart);
// the desk reads what the administrator typed the same way before sending.

/** Arabic-Indic (٠-٩) and Persian (۰-۹) digits as Latin ones. */
export function latinDigits(value: string): string {
  return value.replace(/[٠-٩۰-۹]/g, (digit) => {
    const code = digit.charCodeAt(0);
    return String.fromCharCode(0x30 + code - (code >= 0x06f0 ? 0x06f0 : 0x0660));
  });
}

/** The server's money rule (shared-kernel/money/money.ts). */
const MONEY_AMOUNT = /^\d{1,12}(\.\d{1,2})?$/;

/**
 * A typed amount as the server takes it: its digits Latin, its thousands
 * marks («,» «٬» and spaces) dropped, «٫» read as the decimal point.
 * `''` when nothing was typed, `null` when what was typed is no amount.
 */
export function moneyAmount(typed: string): string | null {
  const plain = latinDigits(typed).replace(/[\s,٬]/g, '').replace('٫', '.');
  if (plain === '') return '';
  return MONEY_AMOUNT.test(plain) ? plain : null;
}
