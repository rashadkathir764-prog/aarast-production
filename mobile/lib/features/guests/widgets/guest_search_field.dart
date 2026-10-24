import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';

/// «دوّر باسم أو رقم»: owns its text and reports each change.
class GuestSearchField extends StatefulWidget {
  const GuestSearchField({
    required this.onChanged,
    this.autofocus = true,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  State<GuestSearchField> createState() => _GuestSearchFieldState();
}

class _GuestSearchFieldState extends State<GuestSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JourneyTextField(
      key: const ValueKey('guests-search-field'),
      label: context.say('دوّر باسم أو رقم', 'دوّري باسم أو رقم'),
      controller: _controller,
      icon: LucideIcons.search,
      autofocus: widget.autofocus,
      onChanged: (value) => widget.onChanged(value.trim()),
    );
  }
}
