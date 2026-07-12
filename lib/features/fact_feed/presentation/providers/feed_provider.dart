import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/fact_service.dart';
import '../../models/fact_card_state.dart';

class FeedState {
  const FeedState({
    this.items = const [],
    this.seenIds = const {},
    this.likedIds = const {},
    this.sessionViewedIds = const {},
    this.language = 'en',
    this.loadingMore = false,
    this.factCounter = 0,
    this.dailyStreak = 0,
    this.factsReadTotal = 0,
    this.goalCompletedToday = 0,
    this.translationToken = 0,
    this.translationCache = const {},
    this.currentCategory = 'science',
  });

  final List<FactCardState> items;
  final Set<String> seenIds;
  final Set<String> likedIds;
  final Set<String> sessionViewedIds;
  final String language;
  final bool loadingMore;
  final int factCounter;
  final int dailyStreak;
  final int factsReadTotal;
  final int goalCompletedToday;
  final int translationToken;
  final Map<String, String> translationCache;
  final String currentCategory;

  FeedState copyWith({
    List<FactCardState>? items,
    Set<String>? seenIds,
    Set<String>? likedIds,
    Set<String>? sessionViewedIds,
    String? language,
    bool? loadingMore,
    int? factCounter,
    int? dailyStreak,
    int? factsReadTotal,
    int? goalCompletedToday,
    int? translationToken,
    Map<String, String>? translationCache,
    String? currentCategory,
  }) {
    return FeedState(
      items: items ?? this.items,
      seenIds: seenIds ?? this.seenIds,
      likedIds: likedIds ?? this.likedIds,
      sessionViewedIds: sessionViewedIds ?? this.sessionViewedIds,
      language: language ?? this.language,
      loadingMore: loadingMore ?? this.loadingMore,
      factCounter: factCounter ?? this.factCounter,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      factsReadTotal: factsReadTotal ?? this.factsReadTotal,
      goalCompletedToday: goalCompletedToday ?? this.goalCompletedToday,
      translationToken: translationToken ?? this.translationToken,
      translationCache: translationCache ?? this.translationCache,
      currentCategory: currentCategory ?? this.currentCategory,
    );
  }
}

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(() {
  return FeedNotifier();
});

class FeedNotifier extends Notifier<FeedState> {
  static const int initialBatchSize = 10;
  static const int nextBatchSize = 5;
  static const int dailyGoal = 50;

  @override
  FeedState build() {
    return const FeedState();
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('factreel_lang') ?? 'en';
    final currentCategory = prefs.getString('factreel_category') ?? 'science';
    final likedList = prefs.getStringList('factreel_liked') ?? <String>[];
    final likedIds = Set<String>.from(likedList);
    var factsReadTotal = prefs.getInt('factreel_facts_read_total') ??
        (prefs.getStringList('factreel_viewed_ids')?.length ?? 0);

    final today = _todayKey();
    final savedStreak = prefs.getInt('factreel_streak_days') ?? 0;
    final lastStreakDateStr = prefs.getString('factreel_last_streak_date');
    final lastStreakDate = _parseDate(lastStreakDateStr);

    var dailyStreak = savedStreak;
    if (lastStreakDate != null && today.difference(lastStreakDate).inDays > 1) {
      dailyStreak = 0;
      await prefs.setInt('factreel_streak_days', 0);
    }

    final goalDate = prefs.getString('factreel_goal_date');
    var goalCompletedToday = 0;
    if (goalDate == today.toIso8601String()) {
      goalCompletedToday = prefs.getInt('factreel_goal_completed_today') ?? 0;
      if (goalCompletedToday > dailyGoal) {
        goalCompletedToday = dailyGoal;
      }
    } else {
      await prefs.setString('factreel_goal_date', today.toIso8601String());
      await prefs.setInt('factreel_goal_completed_today', 0);
    }

    state = state.copyWith(
      language: language,
      currentCategory: currentCategory,
      likedIds: likedIds,
      factsReadTotal: factsReadTotal,
      dailyStreak: dailyStreak,
      goalCompletedToday: goalCompletedToday,
    );

    final factService = ref.read(factServiceProvider);
    await factService.loadFacts(currentCategory);
    
    loadBatch(count: initialBatchSize);
    
    if (state.items.isNotEmpty && state.items.first.status == FactCardStatus.loaded) {
      await markFactViewed(state.items.first.id);
    }
  }

  Future<void> reloadForCategory(String newCategory) async {
    if (newCategory == state.currentCategory) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('factreel_category', newCategory);
    
    final factService = ref.read(factServiceProvider);
    await factService.loadFacts(newCategory);
    
    state = state.copyWith(
      currentCategory: newCategory,
      items: const [],
      factCounter: 0,
      seenIds: const {},
      loadingMore: false,
    );

    loadBatch(count: initialBatchSize);
    if (state.items.isNotEmpty && state.items.first.status == FactCardStatus.loaded) {
      await markFactViewed(state.items.first.id);
    }
  }

  DateTime _todayKey() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final parsed = DateTime.parse(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistLikesAndSaves() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('factreel_liked', state.likedIds.toList());
  }

  Future<void> _persistUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('factreel_facts_read_total', state.factsReadTotal);
    await prefs.setInt('factreel_streak_days', state.dailyStreak);
    await prefs.setInt('factreel_goal_completed_today', state.goalCompletedToday);
    await prefs.setString('factreel_goal_date', _todayKey().toIso8601String());
  }

  Future<void> markFactViewed(String id) async {
    final itemIndex = state.items.indexWhere((e) => e.id == id);
    if (itemIndex == -1) return;
    final item = state.items[itemIndex];

    if (item.status != FactCardStatus.loaded || state.sessionViewedIds.contains(item.id)) {
      return;
    }

    bool goalReachedThisTime = false;
    
    final newSessionViewedIds = Set<String>.from(state.sessionViewedIds)..add(item.id);
    var newFactsReadTotal = state.factsReadTotal + 1;
    var newGoalCompletedToday = state.goalCompletedToday;
    
    if (newGoalCompletedToday < dailyGoal) {
      newGoalCompletedToday += 1;
      if (newGoalCompletedToday == dailyGoal) {
        goalReachedThisTime = true;
      }
    }

    state = state.copyWith(
      sessionViewedIds: newSessionViewedIds,
      factsReadTotal: newFactsReadTotal,
      goalCompletedToday: newGoalCompletedToday,
    );

    if (goalReachedThisTime) {
      final prefs = await SharedPreferences.getInstance();
      final now = _todayKey();
      final lastStreakDateStr = prefs.getString('factreel_last_streak_date');
      final lastStreakDate = _parseDate(lastStreakDateStr);
      
      if (lastStreakDate == null || now.difference(lastStreakDate).inDays > 0) {
        state = state.copyWith(dailyStreak: state.dailyStreak + 1);
        await prefs.setInt('factreel_streak_days', state.dailyStreak);
        await prefs.setString('factreel_last_streak_date', now.toIso8601String());
      }
    }

    await _persistUsageStats();
  }

  void toggleLikeAt(int index) {
    if (index < 0 || index >= state.items.length) return;
    
    final current = state.items[index];
    final newState = current.copyWith(liked: !current.liked);
    
    final newItems = List<FactCardState>.from(state.items);
    newItems[index] = newState;
    
    final newLikedIds = Set<String>.from(state.likedIds);
    if (newState.liked) {
      newLikedIds.add(newState.id);
    } else {
      newLikedIds.remove(newState.id);
    }
    
    state = state.copyWith(items: newItems, likedIds: newLikedIds);
    _persistLikesAndSaves();
  }

  void removeLikeById(String id) {
    final index = state.items.indexWhere((e) => e.id == id);
    if (index != -1) {
      toggleLikeAt(index);
    } else {
      final newLikedIds = Set<String>.from(state.likedIds)..remove(id);
      state = state.copyWith(likedIds: newLikedIds);
      _persistLikesAndSaves();
    }
  }

  void setItemCopied(int index, bool copied) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<FactCardState>.from(state.items);
    newItems[index] = newItems[index].copyWith(copied: copied);
    state = state.copyWith(items: newItems);
  }

  Future<void> setLanguage(String language) async {
    if (state.language == language) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('factreel_lang', language);

    final newToken = state.translationToken + 1;
    state = state.copyWith(language: language, translationToken: newToken);

    if (language == 'en') {
      final newItems = List<FactCardState>.from(state.items);
      for (var index = 0; index < newItems.length; index += 1) {
        final item = newItems[index];
        if (item.status == FactCardStatus.loaded) {
          newItems[index] = item.copyWith(
            translatedText: null,
            translating: false,
          );
        }
      }
      state = state.copyWith(items: newItems);
      return;
    }

    final loadedIndexes = <int>[];
    for (var index = 0; index < state.items.length; index += 1) {
      if (state.items[index].status == FactCardStatus.loaded) {
        loadedIndexes.add(index);
      }
    }

    var newItems = List<FactCardState>.from(state.items);
    for (final index in loadedIndexes) {
      newItems[index] = newItems[index].copyWith(translating: true);
    }
    state = state.copyWith(items: newItems);

    final factService = ref.read(factServiceProvider);

    for (final index in loadedIndexes) {
      if (newToken != state.translationToken || state.language != 'hi') {
        return;
      }

      final item = state.items[index];
      final rawText = item.rawText;
      if (rawText == null) continue;

      final cached = state.translationCache[item.id];
      final translated = cached ?? await factService.translateToHindi(rawText);
      
      final newCache = Map<String, String>.from(state.translationCache);
      if (cached == null) newCache[item.id] = translated;
      state = state.copyWith(translationCache: newCache);

      if (newToken != state.translationToken || state.language != 'hi') {
        return;
      }

      newItems = List<FactCardState>.from(state.items);
      newItems[index] = newItems[index].copyWith(
        translatedText: translated,
        translating: false,
      );
      state = state.copyWith(items: newItems);
    }
  }

  void loadBatch({required int count}) {
    final factService = ref.read(factServiceProvider);
    if (state.loadingMore || !factService.isLoaded) {
      return;
    }

    state = state.copyWith(loadingMore: true);

    final newItems = <FactCardState>[];
    var currentCounter = state.factCounter;
    final newSeenIds = Set<String>.from(state.seenIds);

    for (var index = 0; index < count; index += 1) {
      final fact = factService.getNextFact(seenIds: newSeenIds);
      currentCounter += 1;
      newSeenIds.add(fact.id);
      final liked = state.likedIds.contains(fact.id);
      newItems.add(
        FactCardState(
          id: fact.id,
          status: FactCardStatus.loaded,
          number: currentCounter,
          rawText: fact.text,
          liked: liked,
        ),
      );
    }

    final combinedItems = List<FactCardState>.from(state.items)..addAll(newItems);
    state = state.copyWith(
      items: combinedItems,
      factCounter: currentCounter,
      seenIds: newSeenIds,
      loadingMore: false,
    );

    if (state.language == 'hi') {
      final newIndexes = newItems.map((e) => combinedItems.indexOf(e)).toList();
      _translateItems(newIndexes);
    }
  }

  Future<void> _translateItems(List<int> indexes) async {
    final token = state.translationToken;
    final factService = ref.read(factServiceProvider);
    
    for (final index in indexes) {
      if (token != state.translationToken || state.language != 'hi') return;
      if (index < 0 || index >= state.items.length) continue;
      final item = state.items[index];
      if (item.status != FactCardStatus.loaded || item.rawText == null) continue;

      var newItems = List<FactCardState>.from(state.items);
      newItems[index] = item.copyWith(translating: true);
      state = state.copyWith(items: newItems);

      final cached = state.translationCache[item.id];
      final translated = cached ?? await factService.translateToHindi(item.rawText!);
      
      final newCache = Map<String, String>.from(state.translationCache);
      if (cached == null) newCache[item.id] = translated;
      state = state.copyWith(translationCache: newCache);

      if (token != state.translationToken || state.language != 'hi') return;

      if (index < state.items.length) {
        newItems = List<FactCardState>.from(state.items);
        newItems[index] = newItems[index].copyWith(
          translatedText: translated,
          translating: false,
        );
        state = state.copyWith(items: newItems);
      }
    }
  }

  void retryCard(int index) {
    final factService = ref.read(factServiceProvider);
    if (!factService.isLoaded) return;
    
    final newSeenIds = Set<String>.from(state.seenIds);
    final fact = factService.getNextFact(seenIds: newSeenIds);
    final newCounter = state.factCounter + 1;
    newSeenIds.add(fact.id);
    
    final newItems = List<FactCardState>.from(state.items);
    newItems[index] = FactCardState(
      id: fact.id,
      status: FactCardStatus.loaded,
      number: newCounter,
      rawText: fact.text,
      liked: state.likedIds.contains(fact.id),
    );
    
    state = state.copyWith(
      items: newItems,
      factCounter: newCounter,
      seenIds: newSeenIds,
    );

    if (state.language == 'hi') {
      _translateItems([index]);
    }
  }
}
