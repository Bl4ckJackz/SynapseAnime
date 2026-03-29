import 'package:flutter/foundation.dart';

/// Shared title matching/scoring utility used by anime and manga repositories.
/// Consolidates duplicated fuzzy matching logic into a single reusable class.
class TitleMatcher {
  const TitleMatcher._();

  // ──────────────────── TEXT NORMALIZATION ────────────────────

  /// Normalize a string for comparison: lowercase, strip special chars, collapse spaces.
  static String normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Clean a title for matching: remove ordinal season markers, parenthetical info, special chars.
  static String cleanTitle(String title) {
    var cleaned = title.replaceAllMapped(
      RegExp(r'(\d+)(?:st|nd|rd|th)\s+(?:Season|season)', caseSensitive: false),
      (Match m) => '${m.group(1)}',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    cleaned = cleaned.replaceAll(
        RegExp(r"[^a-zA-Z0-9\s\-/:';]"), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Strip season/part suffixes from a title to get the "base" title.
  static String stripSeasonSuffix(String title) {
    return title
        .replaceAll(RegExp(r'\s*Season\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Part\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\d+$'), '')
        .trim();
  }

  /// Extract significant keywords from a string (words with length > minLength).
  static List<String> extractKeywords(String text, {int minLength = 2}) {
    return normalize(text)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > minLength)
        .toList();
  }

  // ──────────────────── SEASON EXTRACTION ────────────────────

  /// Extract season number from title strings. Returns null for season 1 or unknown.
  static int? extractSeasonNumber(String title,
      {String? titleEnglish, String? titleRomaji}) {
    final allTitles = [title, titleEnglish, titleRomaji].whereType<String>();

    for (final t in allTitles) {
      // "Season X" or "Season X Part Y"
      final seasonMatch =
          RegExp(r'Season\s*(\d+)', caseSensitive: false).firstMatch(t);
      if (seasonMatch != null) {
        return int.tryParse(seasonMatch.group(1)!);
      }

      // Trailing number (not preceded by "Part"): "Title 2", "Title 3"
      final numSuffixMatch = RegExp(r'(?<!Part\s)(\d+)\s*$').firstMatch(t);
      if (numSuffixMatch != null) {
        final num = int.tryParse(numSuffixMatch.group(1)!);
        if (num != null && num >= 2 && num <= 10) return num;
      }

      // "2nd Season", "3rd Season"
      final ordinalMatch =
          RegExp(r'(\d+)(?:st|nd|rd|th)\s*Season', caseSensitive: false)
              .firstMatch(t);
      if (ordinalMatch != null) {
        return int.tryParse(ordinalMatch.group(1)!);
      }

      // Roman numerals: "Title II", "Title III"
      final romanMatch =
          RegExp(r'\s+(II|III|IV|V|VI|VII|VIII|IX|X)\s*$', caseSensitive: false)
              .firstMatch(t);
      if (romanMatch != null) {
        const romanMap = {
          'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6,
          'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10,
        };
        return romanMap[romanMatch.group(1)!.toUpperCase()];
      }
    }

    // Sequel subtitle patterns
    for (final t in allTitles) {
      if (t.toLowerCase().contains('shippuden') ||
          t.toLowerCase().contains('next generation')) {
        return 2;
      }
      if (RegExp(r'\sZ\s*$', caseSensitive: false).hasMatch(t)) {
        return 2;
      }
    }

    return null;
  }

  // ──────────────────── TITLE VARIANT MATCHING ────────────────────

  /// Check if a candidate title matches any of the given search variants.
  /// Returns true if at least one variant matches via substring or keyword overlap.
  static bool matchesAnyVariant(
      String candidateTitle, List<String> searchVariants) {
    final candLower = candidateTitle.toLowerCase();

    for (final variant in searchVariants) {
      final variantClean = stripSeasonSuffix(variant).toLowerCase();
      if (variantClean.isEmpty) continue;

      // Direct substring match
      if (candLower.contains(variantClean)) return true;

      // Keyword overlap (>= 50%)
      final variantKeywords =
          variantClean.split(' ').where((w) => w.length > 3).toList();
      if (variantKeywords.isNotEmpty) {
        int matches = 0;
        for (final k in variantKeywords) {
          if (candLower.contains(k)) matches++;
        }
        if (matches >= (variantKeywords.length / 2).ceil()) return true;
      }
    }
    return false;
  }

  // ──────────────────── GENERIC SCORING ────────────────────

  /// Score a candidate title against a query using fuzzy matching heuristics.
  /// Higher score = better match. Returns a [MatchScore] with breakdown.
  static MatchScore scoreTitle({
    required String candidateTitle,
    required String query,
    int? candidateYear,
    int? referenceYear,
    List<String>? candidateAuthors,
    List<String>? referenceAuthors,
  }) {
    final queryNorm = normalize(query);
    final queryLower = query.toLowerCase().trim();
    final queryWords = queryNorm.split(' ').where((w) => w.isNotEmpty).toList();
    final titleNorm = normalize(candidateTitle);
    final titleLower = candidateTitle.toLowerCase().trim();
    final titleWords = titleNorm.split(' ').where((w) => w.isNotEmpty).toList();

    int score = 0;
    final reasons = <String>[];

    // ── Exact match ──
    if (titleNorm == queryNorm) {
      score += 1000;
      reasons.add('exact_norm(+1000)');
    }
    if (titleLower == queryLower) {
      score += 200;
      reasons.add('exact_raw(+200)');
    }

    // ── Starts with ──
    if (titleNorm.startsWith(queryNorm)) {
      final bonus = queryNorm.length < 3 ? 50 : 300;
      score += bonus;
      reasons.add('starts_with(+$bonus)');
    }

    // ── Contains ──
    if (titleNorm.contains(queryNorm)) {
      score += 200;
      reasons.add('contains(+200)');
    }

    // ── Word overlap ──
    int wordMatches = 0;
    for (final qWord in queryWords) {
      if (titleWords.contains(qWord)) {
        score += 50;
        wordMatches++;
      }
    }
    if (wordMatches == queryWords.length && queryWords.isNotEmpty) {
      score += 100;
      reasons.add('all_words(+100)');
    }

    // ── Year match ──
    if (referenceYear != null && candidateYear != null) {
      if (candidateYear == referenceYear) {
        score += 50;
        reasons.add('year_match(+50)');
      } else if ((candidateYear - referenceYear).abs() > 2) {
        score -= 100;
        reasons.add('year_mismatch(-100)');
      }
    }

    // ── Author match ──
    if (referenceAuthors != null &&
        referenceAuthors.isNotEmpty &&
        candidateAuthors != null &&
        candidateAuthors.isNotEmpty) {
      final refNorm = referenceAuthors.map(normalize).toList();
      bool authorMatch = false;
      for (final ca in candidateAuthors) {
        final caNorm = normalize(ca);
        if (refNorm.any((ra) => ra.contains(caNorm) || caNorm.contains(ra))) {
          authorMatch = true;
          break;
        }
      }
      if (authorMatch) {
        score += 100;
        reasons.add('author_match(+100)');
      }
    }

    // ── PENALTIES ──

    // Length ratio penalty
    if (queryNorm.isNotEmpty) {
      final ratio = titleNorm.length / queryNorm.length;
      final isTitleLong = titleWords.length > 3;

      if (queryNorm.length < 5) {
        if (isTitleLong) {
          if (ratio > 2.0) { score -= 500; reasons.add('ratio_short(-500)'); }
          if (ratio > 3.0) { score -= 1000; reasons.add('ratio_short(-1000)'); }
        }
      } else {
        if (ratio > 2.0) { score -= 300; reasons.add('ratio(-300)'); }
        if (ratio > 3.0) { score -= 500; reasons.add('ratio(-500)'); }
      }
    }

    // Separator penalty (spinoffs often use " - ", ": ", etc.)
    const separators = [' - ', ' – ', ' — ', ': '];
    for (final sep in separators) {
      if (candidateTitle.contains(sep) && !query.contains(sep)) {
        score -= 300;
        reasons.add('separator(-300)');
        break;
      }
    }

    // Spinoff keyword penalty
    const spinoffKeywords = [
      'doujinshi', 'dj', '(dj)', 'anthology', 'fan comic', 'fancomic',
      'parody', '4-koma', 'yonkoma', 'oneshot collection', 'extra',
      'side story', 'gaiden', 'spinoff', 'spin-off',
    ];
    for (final keyword in spinoffKeywords) {
      if (titleLower.contains(keyword) && !queryLower.contains(keyword)) {
        score -= 500;
        reasons.add('spinoff(-500)');
        break;
      }
    }

    // Word count penalty
    if (titleWords.length > queryWords.length + 2) {
      score -= 200;
      reasons.add('word_count(-200)');
    }

    // Volume entry penalty
    if (titleLower.contains('volume') && !queryLower.contains('volume')) {
      score -= 200;
      reasons.add('volume(-200)');
    }

    return MatchScore(score: score, reasons: reasons);
  }

  // ──────────────────── ANIME-SPECIFIC SCORING ────────────────────

  /// Score an anime candidate considering season matching, year, type, etc.
  static int scoreAnimeCandidate({
    required Map<String, dynamic> candidate,
    required List<String> titlesToTry,
    required int originalTitleCount,
    int? extractedSeason,
    int? referenceYear,
    String? referenceType,
  }) {
    int score = 0;
    final candId = candidate['id'].toString().toLowerCase();
    final candTitle = candidate['title'].toString();
    final candTitleLower = candTitle.toLowerCase();

    // ── Title variant check (disqualify if no match) ──
    if (!matchesAnyVariant(candTitle, titlesToTry)) {
      return -10000;
    }

    // ── Season matching ──
    final idWithoutPart = candId
        .replaceAll(RegExp(r'-part-\d+'), '')
        .replaceAll('-ita', '');
    final idSeasonMatch = RegExp(r'-(\d+)(?:-|$)').firstMatch(idWithoutPart);
    int? candSeasonFromId;
    if (idSeasonMatch != null) {
      candSeasonFromId = int.tryParse(idSeasonMatch.group(1)!);
    }

    final hasPart2 =
        candId.contains('-part-2') || candTitleLower.contains('part 2');
    final originalHasPart2 =
        titlesToTry.first.toLowerCase().contains('part 2');
    final hasSubtitle =
        titlesToTry.first.contains(':') || titlesToTry.first.contains(' - ');

    if (extractedSeason != null && extractedSeason > 1) {
      if (candSeasonFromId == extractedSeason) {
        score += 200;
        if (originalHasPart2) {
          score += hasPart2 ? 100 : -50;
        }
      } else if (candSeasonFromId != null &&
          candSeasonFromId != extractedSeason) {
        score -= 100;
      } else if (candSeasonFromId == null) {
        score -= 50;
      }
    } else if (hasSubtitle) {
      final subtitle = titlesToTry.first.contains(':')
          ? titlesToTry.first.split(':').last.trim().toLowerCase()
          : titlesToTry.first.split(' - ').last.trim().toLowerCase();

      final idHasSubtitle = candId.contains(subtitle.replaceAll(' ', '-'));
      final titleHasSubtitle = candTitleLower.contains(subtitle);

      if (idHasSubtitle || titleHasSubtitle) {
        score += 150;
      } else if (candSeasonFromId != null && candSeasonFromId > 1) {
        score += 100;
      } else if (candSeasonFromId == null) {
        score -= 30;
      }
    } else {
      // Looking for season 1
      if (candSeasonFromId == null || candSeasonFromId == 1) {
        score += 50;
      } else if (candSeasonFromId != null && candSeasonFromId > 1) {
        score -= 100;
      }
    }

    // Italian dub penalty
    if (candTitleLower.contains('ita')) score -= 30;

    // ── Year check ──
    if (candidate['releaseDate'] != null && referenceYear != null && referenceYear > 0) {
      final candYearStr = candidate['releaseDate'].toString().split('-').first;
      final candYear = int.tryParse(candYearStr);
      if (candYear != null) {
        if (candYear == referenceYear) {
          score += 50;
        } else if ((candYear - referenceYear).abs() > 2) {
          score -= 100;
        }
      }
    }

    // ── Type check ──
    if (referenceType != null) {
      final refType = referenceType.toLowerCase();
      if (refType == 'movie') {
        if (candTitleLower.contains('movie') || candTitleLower.contains('film')) {
          score += 50;
        } else if (candTitleLower.contains('season')) {
          score -= 50;
        }
      } else if (refType == 'tv' || refType == 'tv_special') {
        if ((candTitleLower.contains('movie') || candTitleLower.contains('film')) &&
            !titlesToTry.any((t) => t.toLowerCase().contains('movie'))) {
          score -= 50;
        }
      }
    }

    // ── Exact/prefix title match bonus ──
    final candTitleClean = cleanTitle(candTitle).toLowerCase();
    final primaryVariants = titlesToTry.take(originalTitleCount).toList();

    bool isPrimaryMatch = false;
    for (final searchVariant in primaryVariants) {
      final searchClean = cleanTitle(searchVariant).toLowerCase();

      if (candTitleClean == searchClean) {
        score += 150;
        isPrimaryMatch = true;
        break;
      }

      if (candTitleClean.startsWith(searchClean)) {
        final suffix = candTitleClean.substring(searchClean.length).trim();
        if (RegExp(r'\d+').hasMatch(suffix)) {
          score -= 50;
        } else if (suffix.isNotEmpty) {
          score -= 10;
        }
      }
    }

    if (!isPrimaryMatch) {
      final baseSearchTitle = titlesToTry.first
          .toLowerCase().split(':').first.split(' - ').first.trim();
      if (candTitleLower.contains(baseSearchTitle)) {
        score += 10;
      }
    }

    if (kDebugMode) {
      debugPrint('TitleMatcher: $candId ($candTitle) -> score=$score');
    }

    return score;
  }

  // ──────────────────── MANGA-SPECIFIC: FIND BEST MATCH ────────────────────

  /// Find the best match from manga search results. Returns the result with `_score` set.
  static Map<String, dynamic> findBestMangaMatch(
    List<Map<String, dynamic>> results,
    String query, {
    int? referenceYear,
    List<String>? referenceAuthors,
  }) {
    int bestScore = -1000;
    Map<String, dynamic> bestMatch = results.first;

    for (final result in results) {
      final title = (result['title'] ?? '').toString();

      final matchScore = scoreTitle(
        candidateTitle: title,
        query: query,
        candidateYear: _parseYear(result['year']),
        referenceYear: referenceYear,
        candidateAuthors: _parseAuthors(result['authors']),
        referenceAuthors: referenceAuthors,
      );

      if (kDebugMode) {
        debugPrint(
            'TitleMatcher: manga "$title" -> ${matchScore.score} [${matchScore.reasons.join(", ")}]');
      }

      if (matchScore.score > bestScore) {
        bestScore = matchScore.score;
        bestMatch = result;
      }
    }

    bestMatch['_score'] = bestScore;
    return bestMatch;
  }

  static int? _parseYear(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<String>? _parseAuthors(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }
}

/// Result of a title scoring operation.
class MatchScore {
  final int score;
  final List<String> reasons;

  const MatchScore({required this.score, this.reasons = const []});

  @override
  String toString() => 'MatchScore($score, [${reasons.join(", ")}])';
}
