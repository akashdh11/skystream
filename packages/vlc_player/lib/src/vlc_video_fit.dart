/// How video should be fitted inside the `VlcPlayer` widget bounds.
///
/// Lives in its own file so both the widget and the controller can reference
/// it: the widget imports the controller, so the controller cannot import the
/// widget back.
enum VlcVideoFit {
  /// Preserve the video aspect ratio and show the full frame.
  contain,

  /// Preserve the video aspect ratio and cover the full widget bounds.
  cover,

  /// Stretch the video to fill the widget bounds.
  fill,

  /// Render the video at its natural decoded size when available.
  none,
}
