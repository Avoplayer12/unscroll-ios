import AppIntents

/// A Shortcuts action. The gate automation runs it first and only opens the gate when it returns true,
/// so choosing "Open anyway" doesn't send you straight back to the gate.
struct ShouldShowGateIntent: AppIntent {
    static var title: LocalizedStringResource = "Should Show Gate"
    static var description = IntentDescription("Returns true unless you chose \"Open anyway\" in Unscroll in the last few minutes.")

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: !GatePass.isActive)
    }
}
