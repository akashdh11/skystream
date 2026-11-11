// The Import confirmation must tell an empty backup apart from a restore
// that found nothing new: a backup exported from an empty app holds no
// history at all, so the toast says so plainly instead of the vague
// "Nothing new to restore" — otherwise the user cannot tell an empty
// backup from a broken restore. And it must start with
// "Import successful": the viewer asked whether the import worked, and the
// toast answers that before the detail.

import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/backup/data/app_backup.dart';

void main() {
  test('empty backup says it has no watch history', () {
    const report = AppRestoreReport(historyInBackup: 0);
    expect(
      report.summary,
      'Import successful — this backup has no watch history.',
    );
  });

  test('backup with history already on device says nothing new', () {
    const report = AppRestoreReport(
      historyInBackup: 3,
      historySkipped: 3,
    );
    expect(report.summary, 'Import successful — nothing new to restore.');
  });

  test('restored history is counted', () {
    const report = AppRestoreReport(
      historyRestored: 2,
      historyInBackup: 2,
    );
    expect(report.summary, 'Import successful — restored 2 history items.');
  });

  test('a real restore is not hidden by an empty history', () {
    const report = AppRestoreReport(
      historyInBackup: 0,
      skystreamPluginsRestored: 2,
    );
    expect(report.summary, 'Import successful — restored 2 plugins.');
  });
}
