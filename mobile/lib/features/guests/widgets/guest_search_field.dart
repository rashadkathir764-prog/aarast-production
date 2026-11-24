import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';

/// «دوّر باسم أو رقم»: owns its text and reports it once the typing pauses
/// for [debounce] (RA-MO-363): every letter rebuilt and searched the whole
/// list, so a fast hand on a list of thousands queued one search per letter.
class GuestSearchField extends StatefulWidget {
  const GuestSearchField({
    required this.onChanged,
    this.autofocus = true,
    this.debounce = guestSearchDebounce,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final bool autofocus;
  final Duration debounce;

  @override
  State<GuestSearchField> createState() => _GuestSearchFieldState();
}

/// How long the typing pauses before the list is searched.
const guestSearchDebounce = Duration(milliseconds: 150);

class _GuestSearchFieldState extends State<GuestSearchField> {
  final _controller = TextEditingController();
  Timer? _pending;

  @override
  void dispose() {
    _pending?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _pending?.cancel();
    final query = value.trim();
    _pending = Timer(widget.debounce, () {
      if (mounted) widget.onChanged(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return JourneyTextField(
      key: const ValueKey('guests-search-field'),
      label: context.say('دوّر باسم أو رقم', 'دوّري باسم أو رقم'),
      controller: _controller,
      icon: LucideIcons.search,
      autofocus: widget.autofocus,
      onChanged: _changed,
    );
  }
}
