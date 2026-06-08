import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../providers/task_timeline_provider.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  String _status = 'TODO';
  String _priority = 'MEDIUM';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مهمة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'عنوان المهمة',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'عنوان المهمة مطلوب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'الوصف (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DateSelector(
                    dueDate: _dueDate,
                    onPick: _pickDueDate,
                    onClear: () => setState(() => _dueDate = null),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'TODO', child: Text('جديدة')),
                      DropdownMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text('قيد العمل'),
                      ),
                      DropdownMenuItem(value: 'DONE', child: Text('منجزة')),
                      DropdownMenuItem(
                        value: 'CANCELLED',
                        child: Text('ملغاة'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'الأولوية'),
                    items: const [
                      DropdownMenuItem(value: 'LOW', child: Text('منخفضة')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('متوسطة')),
                      DropdownMenuItem(value: 'HIGH', child: Text('عالية')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _priority = value);
                      }
                    },
                  ),
                  if (provider.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: provider.isSubmitting ? null : _submit,
                    child: provider.isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('حفظ المهمة'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<TaskTimelineProvider>();
    final created = await provider.createTask(
      weddingPlanId: widget.weddingPlanId,
      title: _titleController.text,
      description: _descriptionController.text,
      dueDate: _dueDate,
      status: _status,
      priority: _priority,
    );

    if (!mounted) {
      return;
    }

    if (created) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.tasks(widget.weddingPlanId));
      }
    }
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.dueDate,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? dueDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (dueDate != null)
              TextButton(onPressed: onClear, child: const Text('مسح')),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'تاريخ الاستحقاق',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(dueDate == null ? 'اختياري' : _formatDate(dueDate!)),
              ],
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'اختيار التاريخ',
              onPressed: onPick,
              icon: const Icon(Icons.calendar_month),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
