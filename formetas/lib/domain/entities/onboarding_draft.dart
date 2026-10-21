class OnboardingReserveDraft {
  const OnboardingReserveDraft({
    required this.name,
    required this.amount,
  });

  final String name;
  final double amount;
}

class OnboardingDraft {
  const OnboardingDraft({
    this.availableBalance = 0,
    this.reserves = const [],
  });

  final double availableBalance;
  final List<OnboardingReserveDraft> reserves;

  double get reservesTotal =>
      reserves.fold(0.0, (sum, item) => sum + item.amount);

  double get startingNetWorth => availableBalance + reservesTotal;
}
