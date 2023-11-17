import '../codemod_core.dart';

class Collision {
  Collision({required this.applying, required this.overlapping});

  /// The patch we were attempting to apply when an over
  /// lapping patch was discovered.
  /// This patch will not have been applied.
  Patch applying;

  /// The overlapping patch.
  /// This patch will have already been applied.
  Patch overlapping;

  /// A human readable explaination of what occured.
  String get description => 'Previous patch:\n'
      '  $overlapping\n'
      '  Updated text: ${overlapping.updatedText}\n'
      'Overlapping patch:\n'
      '  $applying\n'
      '  Updated text: ${applying.updatedText}\n';
}
