import { IsIn } from 'class-validator';

/**
 * RA-BE-149 (D124): the currencies the product offers. They are the phone's
 * plan and budget choices (`weddingCurrencyOptions`: ريال يمني، ريال سعودي،
 * دولار أمريكي); a provider's offer is in its plan's currency, and his prices
 * in one of the same. YER is the default everywhere.
 */
export const SUPPORTED_CURRENCIES = ['YER', 'SAR', 'USD'] as const;

/** The code a refused currency is named by in the 400's message. */
export const UNSUPPORTED_CURRENCY = 'UNSUPPORTED_CURRENCY';

/** A request's currency is one of SUPPORTED_CURRENCIES, exactly as listed. */
export function SupportedCurrency(): PropertyDecorator {
  return IsIn(SUPPORTED_CURRENCIES, {
    message: `${UNSUPPORTED_CURRENCY}: currency must be one of ${SUPPORTED_CURRENCIES.join(', ')}`,
  });
}
