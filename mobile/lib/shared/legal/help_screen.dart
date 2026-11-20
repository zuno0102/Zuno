import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuno/core/theme/app_colors.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/shared/legal/legal_document.dart';
import 'package:zuno/shared/widgets/error_banner.dart';

/// Help and support: how to reach us, then the common questions by topic, each answer folded away
/// until it is asked for.
///
/// The words are `assets/legal/help.md`, the same file the website publishes: its `##` headings are
/// the topics, its `###` headings the questions, and what follows each question its answer. The
/// support email is `contactEmail` in `assets/legal/legal.json`; until it is filled in, the page
/// says so instead of offering a button that goes nowhere.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late final Future<(String, String)> _content = () async {
    final bundle = DefaultAssetBundle.of(context);
    final fields =
        (jsonDecode(await bundle.loadString(legalFieldsAsset)) as Map).map(
          (k, v) => MapEntry('$k', '$v'),
        );
    final text = await loadLegalDocument(bundle, LegalDoc.help);
    return (text, (fields['contactEmail'] ?? '').trim());
  }();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(LegalDoc.help.title)),
    body: FutureBuilder<(String, String)>(
      future: _content,
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(data: (final text, final email)?) => HelpView(
          help: HelpContent.parse(text),
          email: email,
        ),
        AsyncSnapshot(:final error?) => Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(message: 'Could not open this page: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    ),
  );
}

/// One question and its answer.
typedef HelpQuestion = ({String question, List<LegalBlock> answer});

/// The help page read into its parts.
class HelpContent {
  const HelpContent({required this.intro, required this.topics});

  /// What the page says before the first topic.
  final List<LegalBlock> intro;

  /// Each topic's name and its questions, in the file's order.
  final List<({String title, List<HelpQuestion> questions})> topics;

  static HelpContent parse(String text) {
    final intro = <LegalBlock>[];
    final topics = <({String title, List<HelpQuestion> questions})>[];
    List<LegalBlock>? answer;

    for (final block in parseLegalMarkdown(text)) {
      switch (block) {
        case LegalHeading(level: 1):
          break; // The page title; the app bar says it.
        case LegalHeading(level: 2, :final text):
          topics.add((title: text, questions: []));
          answer = null;
        case LegalHeading(:final text) when topics.isNotEmpty:
          answer = [];
          topics.last.questions.add((question: text, answer: answer));
        case LegalHeading(:final text):
          intro.add(LegalParagraph(text));
        default:
          (answer ?? intro).add(block);
      }
    }
    return HelpContent(intro: intro, topics: topics);
  }
}

class HelpView extends StatelessWidget {
  const HelpView({required this.help, required this.email, super.key});

  final HelpContent help;

  /// Where to write; empty until the owner fills it in.
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _ContactCard(email: email),
        for (final topic in help.topics) ...[
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(topic.title, style: theme.textTheme.titleMedium),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, q) in topic.questions.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ExpansionTile(
                    key: ValueKey('help-${q.question}'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text(q.question, style: theme.textTheme.titleSmall),
                    children: [
                      for (final block in q.answer)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (block is LegalBullet)
                                  const TextSpan(text: '•  '),
                                ...legalSpans(block.text),
                              ],
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The way to reach a person, first on the page.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppColors.onMediaMuted;
    final hasEmail = email.isNotEmpty;

    return Container(
      key: const ValueKey('help-contact'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.circleDark,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How can we help?',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.onMedia,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasEmail
                ? 'Find your question below. Still stuck? Email us with your '
                      'registered mobile number and what went wrong.'
                : 'Find your question below. A support email will be added '
                      'here soon.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          if (hasEmail) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('help-email'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.onMedia,
                  foregroundColor: AppColors.circleDark,
                ),
                onPressed: () => launchUrl(
                  Uri(
                    scheme: 'mailto',
                    path: email,
                    queryParameters: {'subject': 'Zuno help'},
                  ),
                ),
                icon: const Icon(Icons.mail_outline_rounded),
                label: Text('Email $email'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
