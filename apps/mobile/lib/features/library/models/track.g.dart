// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Track _$TrackFromJson(Map<String, dynamic> json) => _Track(
  id: json['id'] as String,
  spotifyId: json['spotify_id'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String,
  album: json['album'] as String?,
  addedAt: DateTime.parse(json['added_at'] as String),
);

Map<String, dynamic> _$TrackToJson(_Track instance) => <String, dynamic>{
  'id': instance.id,
  'spotify_id': instance.spotifyId,
  'title': instance.title,
  'artist': instance.artist,
  'album': instance.album,
  'added_at': instance.addedAt.toIso8601String(),
};
