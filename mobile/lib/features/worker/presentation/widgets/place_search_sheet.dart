import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuno/features/auth/presentation/providers/auth_providers.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'place_search_sheet.g.dart';

/// A place somebody searched for.
class SearchedPlace {
  const SearchedPlace({
    required this.name,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    this.street,
    this.locality,
    this.city,
    this.state,
    this.postalCode,
  });

  factory SearchedPlace.fromJson(Map<String, dynamic> json) => SearchedPlace(
    name: json['name'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    street: json['street'] as String?,
    locality: json['locality'] as String?,
    city: json['city'] as String?,
    state: json['state'] as String?,
    postalCode: json['postalCode'] as String?,
  );

  final String name;

  /// The whole address, for telling two places with the same name apart.
  final String fullName;
  final double latitude;
  final double longitude;

  /// The address split into the fields a form has, when the provider knows them. Used to fill an
  /// address in from a pin rather than making somebody type what the map already says.
  final String? street;
  final String? locality;
  final String? city;
  final String? state;
  final String? postalCode;
}

/// Looks a place up through our own server.
///
/// Never straight to the map provider: the search is proxied so one identifiable client makes the
/// calls, results are cached in one place, and a paid provider's key could be introduced later
/// without shipping it inside the app.
@Riverpod(keepAlive: true)
PlaceSearchClient placeSearchClient(Ref ref) =>
    PlaceSearchClient(ref.watch(dioClientProvider));

class PlaceSearchClient {
  PlaceSearchClient(this._dio);

  final Dio _dio;

  Future<List<SearchedPlace>> search(String query) async {
    final response = await _dio.get<List<dynamic>>(
      ApiConstants.placeSearchPath,
      queryParameters: {'q': query},
    );

    return (response.data ?? [])
        .map((e) => SearchedPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// What the place at these coordinates is called, or null if it cannot be named.
  ///
  /// Never throws for the caller to handle: a position that cannot be named is still a usable
  /// position, so failure here degrades to showing the coordinates' generic label.
  ///
  /// [precise] asks for the street rather than the suburb — for pinning the exact house of a job.
  Future<SearchedPlace?> reverse({
    required double latitude,
    required double longitude,
    bool precise = false,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.placeReversePath,
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          if (precise) 'precise': true,
        },
      );
      final data = response.data;
      return data == null ? null : SearchedPlace.fromJson(data);
    } on Exception {
      return null;
    }
  }

  /// The road route between two points, or null when there is none.
  ///
  /// Never throws: a map without a route still shows both ends and the straight line between them.
  Future<TravelRoute?> route({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.placeRoutePath,
        queryParameters: {
          'fromLatitude': fromLatitude,
          'fromLongitude': fromLongitude,
          'toLatitude': toLatitude,
          'toLongitude': toLongitude,
        },
      );
      final data = response.data;
      return data == null ? null : TravelRoute.fromJson(data);
    } on Exception {
      return null;
    }
  }
}

/// What the location sheet came back with.
///
/// One sheet answering for both ways of saying where you are, so the filter bar carries a single
/// location control rather than a typed-place button competing with a GPS button — which is what
/// overflowed the row at phone width.
class PlaceChoice {
  const PlaceChoice.searched(SearchedPlace this.place)
    : useCurrentLocation = false,
      clearLocation = false;

  const PlaceChoice.currentLocation()
    : place = null,
      useCurrentLocation = true,
      clearLocation = false;

  /// Forget the location entirely and go back to the prompt.
  const PlaceChoice.cleared()
    : place = null,
      useCurrentLocation = false,
      clearLocation = true;

  final SearchedPlace? place;
  final bool useCurrentLocation;
  final bool clearLocation;
}

/// Lets somebody type where they are, instead of relying on GPS.
///
/// Search-on-submit rather than as-you-type: the provider behind it asks clients not to fire a
/// request per keystroke, and a worker typing a place name they already know does not need
/// suggestions after three letters.
Future<PlaceChoice?> showPlaceSearchSheet(
  BuildContext context, {
  bool hasLocation = false,
}) {
  return showModalBottomSheet<PlaceChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PlaceSearchSheet(hasLocation: hasLocation),
  );
}

class _PlaceSearchSheet extends ConsumerStatefulWidget {
  const _PlaceSearchSheet({required this.hasLocation});

  /// Whether there is a location set, and so something worth offering to clear.
  final bool hasLocation;

  @override
  ConsumerState<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<_PlaceSearchSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  List<SearchedPlace>? _results;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Warm the district list so the very first keystroke has something to match against.
    ref.read(allDistrictsProvider);
    // Straight into the field: the sheet exists to be typed into.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Waits for typing to stop before searching.
  ///
  /// Suggestions appear as you type, but a request is not sent per keystroke. The provider behind
  /// this asks clients not to drive autocomplete and limits use to roughly one call a second, so the
  /// pause below turns "K-a-z-h-a-k" into one request for the finished word rather than six. Results
  /// are also cached server side, so a place typed twice costs nothing the second time.
  ///
  /// For heavy traffic the honest answer is a provider built for autocomplete; this keeps the free
  /// one inside its terms.
  static const _typingPause = Duration(milliseconds: 650);

  Timer? _debounce;

  /// Rises with each search so a slow earlier response cannot overwrite a newer one.
  int _searchGeneration = 0;

  /// Districts whose name starts with what has been typed, straight from the cached list.
  ///
  /// This is what makes suggestions appear as you type. The geocoder behind the wider search does no
  /// prefix matching whatsoever — "Thiruvan" returns nothing from it — so partial words are answered
  /// locally, instantly, and without a request. Starts-with rather than contains, so typing "kol"
  /// offers Kollam rather than every district with those letters buried in it.
  List<SearchedPlace> _localMatches(String query) {
    if (query.length < 2) return const [];

    final districts = ref.read(allDistrictsProvider).value ?? const <District>[];
    final needle = query.toLowerCase();

    return districts
        .where((d) => d.hasCentre && d.name.toLowerCase().startsWith(needle))
        .take(6)
        .map(
          (d) => SearchedPlace(
            name: d.name,
            fullName: '${d.name}, ${d.stateName}',
            latitude: d.centreLatitude!,
            longitude: d.centreLongitude!,
          ),
        )
        .toList();
  }

  void _onTyped(String value) {
    _debounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _isSearching = false;
      });
      return;
    }

    // Local matches first, with no wait at all. This is the part that feels like suggestions: the
    // list fills from the second letter while the wider lookup is still a pause away.
    setState(() {
      _results = _localMatches(query);
      _error = null;
    });

    // Then the geocoder, for the places a district list cannot know — a landmark, or a small town.
    // Only worth asking once there is a plausible word, since it cannot match a prefix.
    if (query.length >= 3) {
      _debounce = Timer(_typingPause, _search);
    }
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 3) {
      setState(() => _error = 'Type at least three letters.');
      return;
    }

    final generation = ++_searchGeneration;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final found = await ref.read(placeSearchClientProvider).search(query);
      if (!mounted) return;

      // A slower earlier request must not land on top of a newer one. Typing "Kollam" after
      // "Kazhakoottam" would otherwise show Kazhakoottam's results under Kollam's text whenever the
      // first response came back second.
      if (generation != _searchGeneration) return;

      // Merged, not replaced. The local district matches are already on screen and are often the
      // right answer; dropping them the moment the geocoder replies would make the list jump and
      // could remove the very row somebody was reaching for.
      final local = _localMatches(query);
      final seen = local.map((p) => p.name.toLowerCase()).toSet();

      setState(() {
        _results = [
          ...local,
          ...found.where((p) => seen.add(p.name.toLowerCase())),
        ];
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isSearching = false;
        _error = 'Could not search just now. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where are you?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Type a town or landmark. Suggestions appear as you type.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // GPS first, because it is one tap and right most of the time. Typing is for
                  // planning from elsewhere, or for a phone that will not give a fix.
                  // Only when there is something to undo. Offering to clear a location nobody has
                  // set is a control that can never do anything.
                  if (widget.hasLocation) ...[
                    ListTile(
                      leading: Icon(
                        Icons.location_off_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Clear my location',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      subtitle: const Text('Stops showing jobs by distance'),
                      onTap: () =>
                          Navigator.of(context).pop(const PlaceChoice.cleared()),
                    ),
                    const Divider(height: 1),
                  ],
                  ListTile(
                    leading: const Icon(Icons.my_location),
                    title: const Text('Use my current location'),
                    onTap: () => Navigator.of(context)
                        .pop(const PlaceChoice.currentLocation()),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: _onTyped,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Kazhakoottam, Kollam, Technopark…',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      errorText: _error,
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              tooltip: 'Search',
                              onPressed: _search,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (_results) {
                null => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Start typing a place — suggestions appear as you go.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                final found when found.isEmpty => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Nothing found for that. Try a nearby town instead of a building name.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                final found => ListView.separated(
                  controller: scrollController,
                  itemCount: found.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = found[index];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        place.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      // The full address distinguishes the three Kollams a search can return.
                      subtitle: Text(
                        place.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () =>
                          Navigator.of(context).pop(PlaceChoice.searched(place)),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A road route, and what it costs to travel it.
class TravelRoute {
  const TravelRoute({
    required this.distanceKm,
    required this.durationMinutes,
    required this.points,
  });

  factory TravelRoute.fromJson(Map<String, dynamic> json) => TravelRoute(
    distanceKm: (json['distanceKm'] as num).toDouble(),
    durationMinutes: (json['durationMinutes'] as num).toDouble(),
    points: ((json['points'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .map(
          (p) => (
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          ),
        )
        .toList(),
  );

  /// Road distance, which always exceeds the straight line.
  final double distanceKm;

  /// Driving time as the router estimates it. No traffic is accounted for.
  final double durationMinutes;

  /// The shape of the route, in order.
  final List<(double, double)> points;

  /// "55 km by road · 1 hr 2 min"
  String get label {
    final km = distanceKm < 10
        ? distanceKm.toStringAsFixed(1)
        : distanceKm.round().toString();
    final minutes = durationMinutes.round();
    final time = minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} hr${minutes % 60 == 0 ? '' : ' ${minutes % 60} min'}';
    return '$km km by road · $time';
  }
}
