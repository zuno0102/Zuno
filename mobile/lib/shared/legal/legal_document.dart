import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// The app's help and legal pages. Each is a Markdown file under `assets/legal/`, the one copy the
/// app shows and the website publishes (`web/privacy.html`, `web/terms.html`), so they never say
/// different things. PRIVACY_AND_LEGAL.md says when they must change.
enum LegalDoc {
  help('Help and support', 'assets/legal/help.md', Icons.help_outline_rounded),
  privacy(
    'Privacy policy',
    'assets/legal/privacy_policy.md',
    Icons.privacy_tip_outlined,
  ),
  terms(
    'Terms of use',
    'assets/legal/terms_of_use.md',
    Icons.description_outlined,
  );

  const LegalDoc(this.title, this.asset, this.icon);

  final String title;
  final String asset;
  final IconData icon;
}

/// The owner's details the documents name — company, contact email, Grievance Officer — written
/// once in `assets/legal/legal.json` and filled into every page.
const legalFieldsAsset = 'assets/legal/legal.json';

/// What a field not yet filled in reads as, so a gap shows instead of vanishing mid-sentence.
const legalFieldMissing = '(to be added)';

/// [text] with each `{{name}}` replaced by its value in [fields].
String fillLegalFields(String text, Map<String, String> fields) =>
    text.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) {
      final value = fields[m[1]]?.trim() ?? '';
      return value.isEmpty ? legalFieldMissing : value;
    });

/// The document's text, with the owner's details filled in.
Future<String> loadLegalDocument(AssetBundle bundle, LegalDoc doc) async {
  final fields = (jsonDecode(await bundle.loadString(legalFieldsAsset)) as Map)
      .map((k, v) => MapEntry('$k', '$v'));
  return fillLegalFields(await bundle.loadString(doc.asset), fields);
}

/// One block of a document.
sealed class LegalBlock {
  const LegalBlock(this.text);
  final String text;
}

class LegalHeading extends LegalBlock {
  const LegalHeading(this.level, super.text);
  final int level;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(super.text);
}

class LegalBullet extends LegalBlock {
  const LegalBullet(super.text);
}

/// The few Markdown forms the documents use: `#`, `##` and `###` headings, `- ` bullets, and
/// paragraphs (lines run together until a blank line). `**bold**` is kept inside the text and
/// drawn by [LegalDocumentView]. Small on purpose, so the app takes no Markdown package for three
/// pages.
List<LegalBlock> parseLegalMarkdown(String source) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];

  void endParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalParagraph(paragraph.join(' ')));
    paragraph.clear();
  }

  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (line.isEmpty) {
      endParagraph();
    } else if (heading != null) {
      endParagraph();
      blocks.add(LegalHeading(heading[1]!.length, heading[2]!.trim()));
    } else if (line.startsWith('- ')) {
      endParagraph();
      blocks.add(LegalBullet(line.substring(2).trim()));
    } else if (blocks.isNotEmpty &&
        blocks.last is LegalBullet &&
        paragraph.isEmpty &&
        raw.startsWith('  ')) {
      // A bullet carried onto an indented next line.
      final last = blocks.removeLast();
      blocks.add(LegalBullet('${last.text} $line'));
    } else {
      paragraph.add(line);
    }
  }
  endParagraph();
  return blocks;
}

/// [text] as spans, `**bold**` parts bold.
List<TextSpan> legalSpans(String text) {
  final spans = <TextSpan>[];
  final parts = text.split('**');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    spans.add(
      TextSpan(
        text: parts[i],
        style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
    );
  }
  return spans;
}

/// A help or legal page, opened from Profile.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({required this.doc, super.key});

  final LegalDoc doc;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  /// Read once, not on every rebuild.
  late final Future<String> _text = loadLegalDocument(
    DefaultAssetBundle.of(context),
    widget.doc,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.doc.title)),
    body: FutureBuilder<String>(
      future: _text,
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(:final data?) => LegalDocumentView(text: data),
        AsyncSnapshot(:final error?) => Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: 'Could not open this page: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    ),
  );
}

/// The blocks of a document, laid out for reading.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final body = textTheme.bodyMedium?.copyWith(height: 1.5);
    final blocks = parseLegalMarkdown(text);

    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: blocks.length,
        itemBuilder: (context, i) => switch (blocks[i]) {
          LegalHeading(:final level, :final text) => Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : (level == 3 ? 12 : 20)),
            child: Text.rich(
              TextSpan(children: legalSpans(text)),
              style: switch (level) {
                1 => textTheme.headlineSmall,
                2 => textTheme.titleLarge,
                _ => textTheme.titleSmall,
              }?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          LegalParagraph(:final text) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text.rich(TextSpan(children: legalSpans(text)), style: body),
          ),
          LegalBullet(:final text) => Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: body),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: legalSpans(text)),
                    style: body,
                  ),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}
