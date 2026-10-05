String? validateRepairRevision({
  required int previousTotal,
  required int total,
  required String reason,
  required List<String> photos,
}) {
  if (total < 0 || total > 10000000)
    return 'Enter a valid total up to Rs. 10,000,000.';
  if (reason.trim().length < 10 || reason.length > 300)
    return 'Explain the reason for this change in 10 to 300 characters.';
  if (photos.length > 2 || photos.any((p) => p.isEmpty || p.length > 210000))
    return 'Attach at most two compressed evidence photos.';
  if (total > previousTotal && photos.isEmpty)
    return 'Attach a photo of the problem, replaced part or receipt for this increase.';
  return null;
}
