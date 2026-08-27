extension GamesView {

    // MARK: - Error

    func setError(
        _ message: String
    ) {
        errorMessage = message
    }
}

func getRelativeDateString(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    formatter.unitsStyle = .full
    
    return formatter.localizedString(for: date, relativeTo: Date())
}
