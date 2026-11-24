import 'package:flutter/material.dart';

import '../models/draw_result_model.dart';
import '../services/auth_service.dart';
import '../services/draw_reminder_service.dart';

Future<void> showDrawReminderDialog(BuildContext context, AccountStorage account, DrawResult draw) => showDialog<void>(
  context: context,
  builder: (_) => _DrawReminderDialog(account: account, draw: draw),
);

class _DrawReminderDialog extends StatefulWidget {
  const _DrawReminderDialog({required this.account, required this.draw});

  final AccountStorage account;
  final DrawResult draw;

  @override
  State<_DrawReminderDialog> createState() => _DrawReminderDialogState();
}

class _DrawReminderDialogState extends State<_DrawReminderDialog> {
  final _reminders = DrawReminderService();
  ReminderResult? _result;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _update(_reminders.status(widget.account, widget.draw));
  }

  Future<void> _update(Future<ReminderResult> operation) async {
    final result = await operation;
    if (!mounted || !AuthService.canUseStorage(widget.account)) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  void _run(Future<ReminderResult> Function() operation) {
    if (_busy || !AuthService.canUseStorage(widget.account)) return;
    setState(() => _busy = true);
    _update(operation());
  }

  void _schedule({ReminderMode? mode}) => _run(() => _reminders.schedule(widget.account, widget.draw, mode: mode));

  void _openSettings(bool exactAlarms) => _run(() async {
    try {
      await _reminders.openSettings(widget.account, exactAlarms: exactAlarms);
      // Returning from system settings can revoke the session. A fresh dialog or
      // a manual retry will check the current permission again.
      return _result ?? const ReminderResult(ReminderStatus.none);
    } catch (_) {
      return ReminderResult(ReminderStatus.failed, mode: _result?.mode);
    }
  });

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final status = result?.status;
    final actions = <Widget>[
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      if (result?.mode != null && status != ReminderStatus.cancelled)
        TextButton(
          onPressed: _busy ? null : () => _run(() => _reminders.cancel(widget.account, widget.draw)),
          child: Text(result!.cancellationPending ? 'Retry cancellation' : 'Cancel reminder'),
        ),
    ];
    if (status == ReminderStatus.permissionDenied || status == ReminderStatus.channelUnavailable) {
      actions.add(
        TextButton(onPressed: _busy ? null : () => _openSettings(false), child: const Text('Notification settings')),
      );
    }
    if (status == ReminderStatus.exactUnavailable) {
      actions.addAll([
        TextButton(onPressed: _busy ? null : () => _openSettings(true), child: const Text('Alarm settings')),
        FilledButton(
          onPressed: _busy ? null : () => _schedule(mode: ReminderMode.approximate),
          child: const Text('Schedule approximate reminder'),
        ),
      ]);
    }
    if (result != null &&
        !result.cancellationPending &&
        status != ReminderStatus.muted &&
        status != ReminderStatus.expired &&
        status != ReminderStatus.invalidDraw) {
      actions.add(
        FilledButton(
          onPressed: _busy ? null : () => _schedule(),
          child: Text(switch (status) {
            ReminderStatus.none || ReminderStatus.cancelled => 'Set reminder',
            ReminderStatus.scheduled || ReminderStatus.alreadyScheduled => 'Reschedule',
            _ => 'Retry',
          }),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Draw reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.draw.denomination} • ${widget.draw.drawDate}'),
            const SizedBox(height: 8),
            if (_busy) const LinearProgressIndicator(),
            Text(result?.message ?? 'Checking reminder status…'),
            if (result?.mode == ReminderMode.approximate &&
                status != ReminderStatus.scheduled &&
                status != ReminderStatus.alreadyScheduled)
              const Text('Saved timing preference: approximate.'),
          ],
        ),
      ),
      actions: actions,
    );
  }
}
