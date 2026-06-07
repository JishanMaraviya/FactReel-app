enum FactCardStatus { loading, loaded, error }

class FactCardState {
  const FactCardState({
    required this.id,
    required this.status,
    this.number,
    this.rawText,
    this.translatedText,
    this.liked = false,
    this.copied = false,
    this.translating = false,
    this.errorMessage,
  });

  final String id;
  final FactCardStatus status;
  final int? number;
  final String? rawText;
  final String? translatedText;
  final bool liked;
  final bool copied;
  final bool translating;
  final String? errorMessage;

  FactCardState copyWith({
    String? id,
    FactCardStatus? status,
    int? number,
    String? rawText,
    String? translatedText,
    bool? liked,
    bool? copied,
    bool? translating,
    String? errorMessage,
  }) {
    return FactCardState(
      id: id ?? this.id,
      status: status ?? this.status,
      number: number ?? this.number,
      rawText: rawText ?? this.rawText,
      translatedText: translatedText ?? this.translatedText,
      liked: liked ?? this.liked,
      copied: copied ?? this.copied,
      translating: translating ?? this.translating,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get displayText => translatedText ?? rawText ?? '';
}
