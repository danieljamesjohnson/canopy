import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Opens a Hive box, surviving incompatible/corrupt persisted data.
///
/// A non-lazy [Box] eagerly deserializes every stored frame when it opens.
/// A browser/profile that still holds Canopy data written by an **older app
/// version** can contain a record whose binary shape the current adapters
/// cannot read (e.g. an unknown typeId or a removed field). That throws an
/// uncaught error during startup and blanks the whole app
/// (see .planning/debug/stale-hive-data-startup-crash.md).
///
/// This helper converts that fatal error into a graceful reset: if [open]
/// throws, the box's on-disk data is discarded via [deleteFromDisk] and the
/// box is reopened empty. The user loses only the unreadable box's contents
/// (which the engine regenerates) instead of facing a blank screen.
///
/// [open] and [deleteFromDisk] are injected so the recovery flow can be unit
/// tested without real Hive I/O; production callers pass the real
/// `Hive.openBox` / `Hive.deleteBoxFromDisk`.
Future<Box<T>> openBoxResilient<T>(
  String name,
  Future<Box<T>> Function(String name) open,
  Future<void> Function(String name) deleteFromDisk,
) async {
  try {
    return await open(name);
  } catch (error, stackTrace) {
    // Discard the incompatible/corrupt data and reopen clean.
    debugPrint(
      'Hive box "$name" failed to open and is being reset — incompatible or '
      'corrupt data from an older app version was discarded: $error\n'
      '$stackTrace',
    );
    try {
      await deleteFromDisk(name);
    } catch (deleteError) {
      // Best-effort cleanup. The on-disk data file is removed before the lock
      // file, so a trailing lock-file error (a known VM-backend race) does not
      // mean the bad data survived — the reopen below is the real recovery
      // signal, and it will rethrow if the box is genuinely unrecoverable.
      debugPrint(
        'Reset of box "$name" reported an error (continuing): '
        '$deleteError',
      );
    }
    return await open(name);
  }
}
