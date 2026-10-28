/// A list loaded a page at a time. [nextBefore] is the cursor for the next page, null at the end.
class PagedList<T> {
  const PagedList({
    required this.items,
    this.nextBefore,
    this.isLoadingMore = false,
  });

  final List<T> items;
  final DateTime? nextBefore;
  final bool isLoadingMore;

  bool get hasMore => nextBefore != null;

  PagedList<T> copyWith({
    List<T>? items,
    DateTime? nextBefore,
    bool clearNext = false,
    bool? isLoadingMore,
  }) => PagedList(
    items: items ?? this.items,
    nextBefore: clearNext ? null : (nextBefore ?? this.nextBefore),
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  /// Puts [item] in place of the one with the same id, or at the top when it is new.
  PagedList<T> upsert(T item, String Function(T) idOf) {
    final index = items.indexWhere((i) => idOf(i) == idOf(item));
    final next = [...items];
    if (index < 0) {
      next.insert(0, item);
    } else {
      next[index] = item;
    }
    return copyWith(items: next);
  }
}
