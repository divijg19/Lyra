import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.freezed.dart';
part 'track.g.dart';

@freezed
abstract class Track with _$Track {
  const factory Track({
    required String id,
    @JsonKey(name: 'spotify_id') required String spotifyId,
    required String title,
    required String artist,
    String? album,
    @JsonKey(name: 'added_at') required DateTime addedAt,
  }) = _Track;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
}
