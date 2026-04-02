class TrackFilters {
  const TrackFilters({
    this.minBpm,
    this.maxBpm,
    this.minEnergy,
    this.maxEnergy,
    this.minValence,
    this.maxValence,
  });

  final double? minBpm;
  final double? maxBpm;
  final double? minEnergy;
  final double? maxEnergy;
  final double? minValence;
  final double? maxValence;

  static const TrackFilters empty = TrackFilters();

  bool get hasAnyFilter {
    return minBpm != null ||
        maxBpm != null ||
        minEnergy != null ||
        maxEnergy != null ||
        minValence != null ||
        maxValence != null;
  }

  TrackFilters copyWith({
    double? minBpm,
    double? maxBpm,
    double? minEnergy,
    double? maxEnergy,
    double? minValence,
    double? maxValence,
    bool clear = false,
  }) {
    if (clear) {
      return empty;
    }

    return TrackFilters(
      minBpm: minBpm ?? this.minBpm,
      maxBpm: maxBpm ?? this.maxBpm,
      minEnergy: minEnergy ?? this.minEnergy,
      maxEnergy: maxEnergy ?? this.maxEnergy,
      minValence: minValence ?? this.minValence,
      maxValence: maxValence ?? this.maxValence,
    );
  }
}
