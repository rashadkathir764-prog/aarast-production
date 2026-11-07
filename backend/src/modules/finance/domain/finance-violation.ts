/**
 * A money rule a request would break: `invalid` input, or a `conflict` with
 * the ledger's current state. The domain only names the violation; the
 * application maps it to its transport error. `message` is the rule in
 * English for logs and tests; `code` and `userMessage` are what the person
 * reads (G22): a stable code and the reason in the app's Arabic.
 */
export interface FinanceViolation {
  readonly kind: 'invalid' | 'conflict';
  readonly message: string;
  readonly code: string;
  readonly userMessage: string;
}

interface Wording {
  code: string;
  ar: string;
}

const WORDING: Readonly<Record<string, Wording>> = {
  'initialPaymentAmount cannot exceed totalAmount': {
    code: 'FINANCE_INITIAL_PAYMENT_EXCEEDS_TOTAL',
    ar: 'الدفعة الأولى أكبر من مبلغ الاتفاق.',
  },
  'totalAmount cannot be less than paidAmount': {
    code: 'FINANCE_TOTAL_BELOW_PAID',
    ar: 'ما يصير مبلغ الاتفاق أقل من اللي انْدفع منه.',
  },
  'Payment amount cannot exceed the remaining cost': {
    code: 'FINANCE_PAYMENT_EXCEEDS_REMAINING',
    ar: 'الدفعة أكبر من الباقي على الاتفاق.',
  },
  'Cancelled costs cannot receive payments': {
    code: 'FINANCE_COST_CANCELLED',
    ar: 'الاتفاق ملغي، ما ينسجّل عليه دفع.',
  },
  'Cost is already fully paid': {
    code: 'FINANCE_COST_FULLY_PAID',
    ar: 'الاتفاق مدفوع كامل.',
  },
  'A reversal entry cannot be reversed': {
    code: 'FINANCE_REVERSAL_NOT_REVERSIBLE',
    ar: 'هذا تراجع عن دفعة، وما يتراجع عنه.',
  },
  'Payment has already been reversed': {
    code: 'FINANCE_PAYMENT_ALREADY_REVERSED',
    ar: 'الدفعة متراجع عنها من قبل.',
  },
  'Payment ledger is inconsistent': {
    code: 'FINANCE_LEDGER_INCONSISTENT',
    ar: 'سجل الدفعات ما يسمح بهذا التراجع. حدّث الصفحة.',
  },
  'A cost with payment history cannot be deleted': {
    code: 'FINANCE_COST_HAS_PAYMENTS',
    ar: 'الاتفاق عليه دفعات، ما ينحذف. ألغه بعد التراجع عن دفعاته.',
  },
  'Reverse the active payments before cancelling this cost': {
    code: 'FINANCE_COST_CANCEL_NEEDS_REVERSAL',
    ar: 'تراجع عن دفعات الاتفاق أول، بعدين ألغه.',
  },
  'The mahr must be greater than zero': {
    code: 'FINANCE_MAHR_NOT_POSITIVE',
    ar: 'المهر لازم يكون أكبر من صفر.',
  },
  'The handed-over part cannot be negative': {
    code: 'FINANCE_MAHR_SETTLED_NEGATIVE',
    ar: 'المسلَّم من المهر ما يكون بالسالب.',
  },
  'The handed-over part cannot exceed the mahr': {
    code: 'FINANCE_MAHR_SETTLED_EXCEEDS',
    ar: 'المسلَّم أكبر من المهر.',
  },
  'An agreement cannot move between the mahr and the wedding items': {
    code: 'FINANCE_MAHR_ITEM_MOVE',
    ar: 'ما ينتقل اتفاق بين المهر وبنود العرس. سجّله من جديد في البند الصح.',
  },
  "The mahr is money coming in only on the bride's plan": {
    code: 'FINANCE_MAHR_FUNDING_BRIDE_ONLY',
    ar: 'المهر كفلوس تدخل يكون في خطة العروسة بس.',
  },
  'A funding source cannot change to or from the mahr': {
    code: 'FINANCE_MAHR_FUNDING_KIND',
    ar: 'ما يتحول مصدر فلوس إلى مهر أو من مهر.',
  },
  'Repayments can only be added to a loan': {
    code: 'FINANCE_REPAYMENT_LOAN_ONLY',
    ar: 'السداد يكون للسلفة بس.',
  },
  'Repayments cannot exceed the loan amount': {
    code: 'FINANCE_REPAYMENTS_EXCEED_LOAN',
    ar: 'مجموع السداد أكبر من مبلغ السلفة.',
  },
  'A loan with repayments cannot change its kind': {
    code: 'FINANCE_LOAN_KIND_LOCKED',
    ar: 'السلفة عليها سداد، ما يتغير نوعها.',
  },
  'amount cannot be less than the scheduled repayments': {
    code: 'FINANCE_LOAN_BELOW_REPAYMENTS',
    ar: 'مبلغ السلفة أقل من السداد المسجّل عليها.',
  },
  'A paid repayment cannot be edited; mark it unpaid first': {
    code: 'FINANCE_REPAYMENT_PAID_LOCKED',
    ar: 'الدفعة مسدّدة. رجّعها «غير مدفوعة» أول ثم عدّلها.',
  },
  'A paid repayment cannot be deleted; mark it unpaid first': {
    code: 'FINANCE_REPAYMENT_PAID_LOCKED',
    ar: 'الدفعة مسدّدة. رجّعها «غير مدفوعة» أول ثم احذفها.',
  },
  'A paid repayment cannot be cancelled; mark it unpaid first': {
    code: 'FINANCE_REPAYMENT_PAID_LOCKED',
    ar: 'الدفعة مسدّدة. رجّعها «غير مدفوعة» أول ثم ألغها.',
  },
  'A cancelled repayment cannot be paid': {
    code: 'FINANCE_REPAYMENT_CANCELLED',
    ar: 'الدفعة ملغية، ما تنسجّل مدفوعة.',
  },
  'A funding source with paid repayments cannot be deleted': {
    code: 'FINANCE_FUNDING_HAS_PAID_REPAYMENTS',
    ar: 'السلفة عليها سداد مدفوع، ما تنحذف. رجّع الدفعات «غير مدفوعة» أول.',
  },
  'Payment schedule amount cannot exceed the remaining cost': {
    code: 'FINANCE_SCHEDULE_EXCEEDS_REMAINING',
    ar: 'مبلغ الموعد أكبر من الباقي على الاتفاق.',
  },
  'Scheduled payment exceeds the remaining cost': {
    code: 'FINANCE_SCHEDULE_EXCEEDS_REMAINING',
    ar: 'الدفعة المجدولة أكبر من الباقي على الاتفاق.',
  },
  'Category allocations cannot exceed the general budget': {
    code: 'FINANCE_ALLOCATIONS_EXCEED_BUDGET',
    ar: 'مجموع المخصص للبنود أكبر من الميزانية العامة.',
  },
  'Set the general budget before allocating money to categories': {
    code: 'FINANCE_BUDGET_REQUIRED',
    ar: 'حدّد الميزانية العامة أول، بعدين وزّعها على البنود.',
  },
  'Cancelled costs cannot be edited': {
    code: 'FINANCE_COST_CANCELLED',
    ar: 'الاتفاق ملغي، ما يتعدل.',
  },
  'Only pending payment schedules can be edited': {
    code: 'FINANCE_SCHEDULE_NOT_PENDING',
    ar: 'الموعد مدفوع أو ملغي، ما يتعدل.',
  },
  'The amount of a payment schedule with ledger history cannot be changed': {
    code: 'FINANCE_SCHEDULE_HAS_PAYMENTS',
    ar: 'الموعد عليه دفعة مسجّلة، ما يتغير مبلغه.',
  },
  'Only pending payment schedules can be deleted': {
    code: 'FINANCE_SCHEDULE_NOT_PENDING',
    ar: 'الموعد مدفوع أو ملغي، ما ينحذف.',
  },
  'A payment schedule with ledger history cannot be deleted': {
    code: 'FINANCE_SCHEDULE_HAS_PAYMENTS',
    ar: 'الموعد عليه دفعة مسجّلة، ما ينحذف.',
  },
  'Reverse the payment before cancelling this payment schedule': {
    code: 'FINANCE_SCHEDULE_CANCEL_NEEDS_REVERSAL',
    ar: 'تراجع عن دفعة الموعد أول، بعدين ألغه.',
  },
  'Cancelled payment schedules cannot be paid': {
    code: 'FINANCE_SCHEDULE_NOT_PENDING',
    ar: 'الموعد مدفوع أو ملغي من قبل.',
  },
  'Payment schedule already has an active payment': {
    code: 'FINANCE_SCHEDULE_ALREADY_PAID',
    ar: 'الموعد مدفوع من قبل.',
  },
  'Currency cannot be changed after the first cost is created': {
    code: 'FINANCE_CURRENCY_LOCKED',
    // RA-BE-23: any money recorded fixes it (an agreement or a source).
    ar: 'ما تتغير عملة الخطة بعد ما يتسجّل فيها مال.',
  },
  'Category names must be unique in the plan': {
    code: 'FINANCE_CATEGORY_NAME_TAKEN',
    ar: 'فيه بند بنفس الاسم في الخطة.',
  },
  'A category still has dependent records': {
    code: 'FINANCE_CATEGORY_IN_USE',
    ar: 'البند عليه اتفاقات، ما ينشال.',
  },
};

const POSITIVE = / must be greater than zero$/;
const OMITTED = /^Category ".*" has costs and cannot be omitted$/;

function word(message: string): Wording {
  const known = WORDING[message];
  if (known) return known;
  if (POSITIVE.test(message)) {
    return { code: 'FINANCE_AMOUNT_NOT_POSITIVE', ar: 'المبلغ لازم يكون أكبر من صفر.' };
  }
  if (OMITTED.test(message)) {
    return { code: 'FINANCE_CATEGORY_IN_USE', ar: 'البند عليه اتفاقات، ما ينشال.' };
  }
  return { code: 'FINANCE_RULE', ar: 'ما ينحفظ: المبلغ أو الحالة ما تسمح بهذا.' };
}

function violation(kind: FinanceViolation['kind'], message: string): FinanceViolation {
  const wording = word(message);
  return { kind, message, code: wording.code, userMessage: wording.ar };
}

export function invalid(message: string): FinanceViolation {
  return violation('invalid', message);
}

export function conflict(message: string): FinanceViolation {
  return violation('conflict', message);
}
