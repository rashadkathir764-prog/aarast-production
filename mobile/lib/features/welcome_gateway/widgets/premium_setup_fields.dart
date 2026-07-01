import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_number_formatter.dart';

class PremiumTextField extends StatelessWidget {
  const PremiumTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.isNumber = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final bool isNumber;
  final Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))]
          : null,
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.ink,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppTheme.muted,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: AppTheme.surfaceElevated,
        prefixIcon: icon != null
            ? Icon(icon, color: AppTheme.gold, size: 22)
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppTheme.border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppTheme.burgundy, width: 1.6),
        ),
      ),
    );
  }
}

class PremiumDateField extends StatelessWidget {
  const PremiumDateField({
    super.key,
    required this.selectedDate,
    required this.onTap,
  });

  final DateTime? selectedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 1.0),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: AppTheme.gold,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedDate == null
                            ? 'لم أحدد بعد'
                            : '${selectedDate!.year}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: selectedDate == null
                              ? AppTheme.muted
                              : AppTheme.ink,
                          fontSize: 16,
                          fontWeight: selectedDate == null
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_calendar_rounded,
                color: AppTheme.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumBudgetField extends StatefulWidget {
  const PremiumBudgetField({
    super.key,
    required this.controller,
    required this.initialCurrency,
    required this.onCurrencyChanged,
    this.onChanged,
  });

  final TextEditingController controller;
  final String initialCurrency;
  final Function(String) onCurrencyChanged;
  final ValueChanged<String>? onChanged;

  @override
  State<PremiumBudgetField> createState() => _PremiumBudgetFieldState();
}

class _PremiumBudgetFieldState extends State<PremiumBudgetField> {
  late String _currency;
  String _budgetWords = '';

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency;
    widget.controller.addListener(_updateWords);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateWords);
    super.dispose();
  }

  String _getCurrencyName(String code) {
    switch (code) {
      case 'YER':
        return 'ريال يمني';
      case 'SAR':
        return 'ريال سعودي';
      case 'USD':
        return 'دولار';
      default:
        return code;
    }
  }

  String _formatWithCommas(int value) {
    final str = value.toString();
    var result = '';
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result += ',';
      }
      result += str[i];
    }
    return result;
  }

  void _updateWords() {
    final val = widget.controller.text;
    final clean = val.replaceAll(',', '');
    final num = int.tryParse(clean);

    if (num != null) {
      final formatted = _formatWithCommas(num);
      if (formatted != val) {
        widget.controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
      setState(() {
        _budgetWords =
            '${ArabicNumberFormatter.toArabicWords(num)} ${_getCurrencyName(_currency)}';
      });
    } else {
      setState(() {
        _budgetWords = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 0,
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border, width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currency,
                  icon: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6.0),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.muted,
                    ),
                  ),
                  style: const TextStyle(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.textFontFamily,
                    fontSize: 16,
                  ),
                  dropdownColor: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _currency = value);
                      widget.onCurrencyChanged(value);
                      _updateWords(); // Re-trigger text update for new currency name
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'YER', child: Text('ر.ي')),
                    DropdownMenuItem(value: 'SAR', child: Text('ر.س')),
                    DropdownMenuItem(value: 'USD', child: Text('\$')),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumTextField(
                  controller: widget.controller,
                  hintText: 'مثال: 3000000',
                  isNumber: true,
                  icon: Icons.account_balance_wallet_rounded,
                  onChanged: widget.onChanged,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    key: ValueKey(_budgetWords),
                    padding: const EdgeInsetsDirectional.only(
                      top: 10,
                      start: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _budgetWords.isEmpty
                              ? Icons.info_outline_rounded
                              : Icons.check_circle_rounded,
                          color: AppTheme.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _budgetWords.isEmpty
                                ? 'يمكن ترك الميزانية فارغة الآن'
                                : _budgetWords,
                            textAlign: TextAlign.start,
                            softWrap: true,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumLocationCard extends StatelessWidget {
  const PremiumLocationCard({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1.0),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(
                Icons.location_on_rounded,
                color: AppTheme.gold,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: controller,
                    onChanged: onChanged,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.start,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: 'المحافظة / المدينة',
                      hintStyle: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.normal,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تحديد الموقع على الخريطة قريبًا',
                    style: TextStyle(
                      color: AppTheme.gold.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.map_rounded, color: AppTheme.disabled, size: 28),
          ],
        ),
      ),
    );
  }
}
