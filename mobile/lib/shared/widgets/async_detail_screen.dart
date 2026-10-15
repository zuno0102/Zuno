import 'package:flutter/material.dart';

/// A screen that fetches one thing, then becomes the screen for it.
///
/// Exists because a notification carries an id while every detail screen in this app takes a whole
/// object. Rather than give each of them a second id-based constructor — three screens, three
/// loading states, three ways to get the error handling slightly different — this fetches first and
/// hands the loaded object to the screen that already exists.
///
/// The spinner carries the destination's own title, so somebody who tapped "Boss T confirmed your
/// booking" sees "Booking" while it loads and not a bare blank page.
class AsyncDetailScreen<T> extends StatefulWidget {
  const AsyncDetailScreen({
    required this.title,
    required this.fetch,
    required this.builder,
    super.key,
  });

  /// Shown on the loading and error states. The built screen brings its own.
  final String title;

  final Future<T> Function() fetch;

  final Widget Function(BuildContext context, T value) builder;

  @override
  State<AsyncDetailScreen<T>> createState() => _AsyncDetailScreenState<T>();
}

class _AsyncDetailScreenState<T> extends State<AsyncDetailScreen<T>> {
  late Future<T> _future = widget.fetch();

  void _retry() => setState(() => _future = widget.fetch());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return widget.builder(context, snapshot.data as T);
      }

      if (snapshot.hasError) {
        return _Failed(
          title: widget.title,
          // Deliberately the real message. A booking that was cancelled, or one the person is no
          // longer party to, comes back as the server's own words, which say more than
          // "Something went wrong" ever could.
          message: snapshot.error.toString(),
          onRetry: _retry,
        );
      }

      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    },
  );
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
