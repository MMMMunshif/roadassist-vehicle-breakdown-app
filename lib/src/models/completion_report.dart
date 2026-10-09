class CompletionReport {
  const CompletionReport({
    required this.problem,
    required this.repairs,
    required this.parts,
    this.advice = '',
  });
  final String problem, repairs, parts, advice;
  void validate() {
    if (problem.trim().length < 10 ||
        repairs.trim().length < 10 ||
        parts.trim().isEmpty ||
        [problem, repairs, parts, advice].any((v) => v.trim().length > 500)) {
      throw ArgumentError(
        'Describe the problem and repair (at least 10 characters), and list replaced parts or No parts replaced. Maximum 500 characters per field.',
      );
    }
  }

  Map<String, dynamic> toMap() => {
    'problem': problem.trim(),
    'repairs': repairs.trim(),
    'parts': parts.trim(),
    'advice': advice.trim(),
  };
  static String description(Map<String, dynamic> data) {
    final report = data['completionReport'];
    if (report is! Map) return '';
    return [
      if (report['problem'] is String) 'Exact problem: ${report['problem']}',
      if (report['repairs'] is String) 'Work performed: ${report['repairs']}',
      if (report['parts'] is String) 'Parts replaced: ${report['parts']}',
      if (report['advice'] is String && (report['advice'] as String).isNotEmpty)
        'Advice / follow-up: ${report['advice']}',
    ].join('\n');
  }
}
