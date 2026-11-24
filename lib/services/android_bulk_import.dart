import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class AndroidBulkImportReceipt {
  AndroidBulkImportReceipt._(Map<Object?, Object?> values)
    : request = values['request'] as int,
      status = values['status'] as String,
      paste = values['paste'] as String? ?? '',
      fileName = values['fileName'] as String?,
      fileContent = values['fileContent'] as String?,
      selectedName = values['selectedName'] as String?,
      selectedBytes = values['selectedBytes'] as Uint8List?,
      error = values['error'] as String?;

  final int request;
  final String status;
  final String paste;
  final String? fileName;
  final String? fileContent;
  final String? selectedName;
  final Uint8List? selectedBytes;
  final String? error;
}

class AndroidBulkImport {
  AndroidBulkImport._() {
    _channel.setMethodCallHandler((call) async {
      final request = call.arguments;
      if (call.method == 'changed' && request is int) _changes.add(request);
    });
  }

  static final instance = AndroidBulkImport._();
  static const _channel = MethodChannel('prize_bond/android_bulk_import');
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final _changes = StreamController<int>.broadcast();
  Stream<int> get changes => _changes.stream;

  Future<String?> pendingDenomination(AccountStorage account) async {
    if (!supported || !AuthService.canUseStorage(account)) return null;
    try {
      final value = await _channel.invokeMethod<String>('denomination', {'owner': account.accountId});
      return AuthService.canUseStorage(account) && AppConfig.denominations.contains(value) ? value : null;
    } catch (error) {
      debugPrint('Could not restore bulk import (${error.runtimeType}).');
      return null;
    }
  }

  Future<int?> open(
    AccountStorage account, {
    required String denomination,
    required String paste,
    required String? fileName,
    required String? fileContent,
  }) async {
    if (!AuthService.canUseStorage(account)) return null;
    return _channel.invokeMethod<int>('open', {
      'owner': account.accountId,
      'draft': {'denomination': denomination, 'paste': paste, 'fileName': fileName, 'fileContent': fileContent},
    });
  }

  Future<AndroidBulkImportReceipt?> load(AccountStorage account) async {
    if (!AuthService.canUseStorage(account)) return null;
    final values = await _channel.invokeMapMethod<Object?, Object?>('load', {'owner': account.accountId});
    if (!AuthService.canUseStorage(account) || values == null) return null;
    return AndroidBulkImportReceipt._(values);
  }

  Future<void> clear(AccountStorage account, int request) async {
    if (!AuthService.canUseStorage(account)) return;
    await _channel.invokeMethod<void>('clear', {'owner': account.accountId, 'request': request});
  }
}
