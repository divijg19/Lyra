import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyra/core/network/base_url.dart';
import 'package:lyra/core/network/dio_provider.dart';
import 'package:lyra/features/library/library_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setUpAll(registerTestFallbacks);

  test(
    'LibraryNotifier transitions from IDLE to IN_PROGRESS to IDLE',
    () async {
      final mockDio = MockDio();
      final syncStatusPayloads = <Map<String, dynamic>>[
        {'sync_status': 'IDLE', 'last_synced_at': null},
        {'sync_status': 'IN_PROGRESS', 'last_synced_at': null},
        {'sync_status': 'IDLE', 'last_synced_at': '2026-04-17T12:00:00Z'},
      ];
      var syncStatusCallCount = 0;

      when(
        () => mockDio.post(
          'http://test/library/sync',
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onSendProgress: any(named: 'onSendProgress'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer(
        (_) async => buildResponse(
          path: '/library/sync',
          data: {'status': 'sync_started'},
          statusCode: 202,
        ),
      );

      when(
        () => mockDio.get(
          'http://test/library/sync/status',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((_) async {
        final index = syncStatusCallCount < syncStatusPayloads.length
            ? syncStatusCallCount
            : syncStatusPayloads.length - 1;
        syncStatusCallCount += 1;
        return buildResponse(
          path: '/library/sync/status',
          data: syncStatusPayloads[index],
        );
      });

      when(
        () => mockDio.get(
          '/library/tracks',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer(
        (_) async => buildResponse(
          path: '/library/tracks',
          data: const <Map<String, dynamic>>[],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          lyraApiBaseUrlProvider.overrideWithValue('http://test'),
          librarySyncPollIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);

      final seenStates = <String>[];
      final subscription = container.listen<LibrarySyncState>(
        libraryNotifierProvider,
        (previous, next) => seenStates.add(next.syncStatus),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(libraryNotifierProvider.notifier).syncLibrary();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(seenStates, contains('IN_PROGRESS'));
      expect(container.read(libraryNotifierProvider).syncStatus, 'IDLE');
      expect(container.read(libraryNotifierProvider).lastSyncedAt, isNotNull);
    },
  );
}
