class PhotoCropData {
  final double offsetX; // Horizontal pan offset
  final double offsetY; // Vertical pan offset
  final double scale; // Zoom level (1.0 = no zoom)

  PhotoCropData({
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.scale = 1.0,
  });

  factory PhotoCropData.fromMap(Map<String, dynamic> map) {
    return PhotoCropData(
      offsetX: (map['offsetX'] ?? 0.0).toDouble(),
      offsetY: (map['offsetY'] ?? 0.0).toDouble(),
      scale: (map['scale'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'offsetX': offsetX,
      'offsetY': offsetY,
      'scale': scale,
    };
  }

  // Copy with modifications
  PhotoCropData copyWith({
    double? offsetX,
    double? offsetY,
    double? scale,
  }) {
    return PhotoCropData(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
    );
  }
}