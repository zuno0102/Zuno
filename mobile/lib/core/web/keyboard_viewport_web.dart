import 'dart:js_interop';

extension type _Element._(JSObject _) implements JSObject {
  external String? getAttribute(String name);
  external void setAttribute(String name, String value);
}

extension type _NodeList._(JSObject _) implements JSObject {
  external int get length;
  external _Element item(int index);
}

extension type _Document._(JSObject _) implements JSObject {
  external _NodeList querySelectorAll(String selectors);
}

@JS('document')
external _Document get _document;

/// The setting that makes the keyboard shrink the page rather than slide it.
const keyboardResizesContent = 'interactive-widget=resizes-content';

/// Adds [keyboardResizesContent] to the page's viewport tag. Called once Flutter has started: it
/// writes its own viewport tag on start, replacing any in `index.html`, so the setting is added to
/// that one. Browsers that do not know the setting ignore it.
void useKeyboardResizesContent() {
  final metas = _document.querySelectorAll('meta[name="viewport"]');
  for (var i = 0; i < metas.length; i++) {
    final meta = metas.item(i);
    final content = meta.getAttribute('content') ?? '';
    if (content.contains('interactive-widget')) continue;
    meta.setAttribute(
      'content',
      content.isEmpty
          ? keyboardResizesContent
          : '$content, $keyboardResizesContent',
    );
  }
}
