import { BadRequestException } from "@nestjs/common";
import {
  type AddressForm,
  gendered,
  textFor,
} from "../shared-kernel/voice/address-form";

// G19: a plan keeps one currency, and an offer must be in it. The refusal
// says so in words both sides read, instead of an English detail the phone
// can only turn into «راجع البيانات».
const CURRENCY_NAMES: Readonly<Record<string, string>> = {
  YER: "الريال اليمني",
  SAR: "الريال السعودي",
  USD: "الدولار",
};

export function currencyNameAr(currency: string): string {
  const code = currency.trim().toUpperCase();
  return CURRENCY_NAMES[code] ?? code;
}

/** Who reads the refusal: the provider sending the offer, or the customer accepting it. */
export type QuoteOfferCurrencyReader = "provider" | "customer";

export function quoteOfferCurrencyMismatch(
  planCurrency: string,
  reader: QuoteOfferCurrencyReader,
  /** The customer's form (B5); the provider is spoken to as the business. */
  form: AddressForm = "MASCULINE",
): BadRequestException {
  const name = currencyNameAr(planCurrency);
  return new BadRequestException({
    code: "QUOTE_OFFER_CURRENCY_MISMATCH",
    message:
      reader === "provider"
        ? `خطة هذا العرس بـ${name}، فأرسل عرضك بـ${name}.`
        : textFor(
            form,
            gendered(
              `هذا العرض بعملة غير عملة خطتك (${name}). اطلب من المزود يرسله بـ${name}.`,
              `هذا العرض بعملة غير عملة خطتك (${name}). اطلبي من المزود يرسله بـ${name}.`,
            ),
          ),
    planCurrency: planCurrency.trim().toUpperCase(),
  });
}
