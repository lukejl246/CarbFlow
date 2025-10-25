import Foundation

enum AnalyticsEventNames {
    static let screenView = "screen_view"
    static let foodLogged = "food_logged"
    static let fastStarted = "fast_started"
    static let fastStopped = "fast_stopped"
    static let quizCompleted = "quiz_completed"
}

private func timestamp(for date: Date = Date()) -> Int {
    Int(date.timeIntervalSince1970.rounded())
}

func logScreenView(screenName: String, at date: Date = Date()) {
    cf_logEvent(AnalyticsEventNames.screenView, [
        "ts": timestamp(for: date),
        "screen_name": screenName
    ])
}

func logFoodLogged(carbsGrams: Double, caloriesKilocalories: Double? = nil, meal: String? = nil, at date: Date = Date()) {
    var params: [String: Any] = [
        "ts": timestamp(for: date),
        "carbs_g": carbsGrams
    ]
    if let caloriesKilocalories {
        params["cal_kcal"] = caloriesKilocalories
    }
    if let meal, !meal.isEmpty {
        params["meal"] = meal
    }
    cf_logEvent(AnalyticsEventNames.foodLogged, params)
}

func logFastStarted(protocolName: String? = nil, at date: Date = Date()) {
    var params: [String: Any] = [
        "ts": timestamp(for: date)
    ]
    if let protocolName, !protocolName.isEmpty {
        params["protocol"] = protocolName
    }
    cf_logEvent(AnalyticsEventNames.fastStarted, params)
}

func logFastStopped(durationSeconds: Int? = nil, at date: Date = Date()) {
    var params: [String: Any] = [
        "ts": timestamp(for: date)
    ]
    if let durationSeconds {
        params["duration_s"] = durationSeconds
    }
    cf_logEvent(AnalyticsEventNames.fastStopped, params)
}

func logQuizCompleted(quizId: String, score: Int, at date: Date = Date()) {
    cf_logEvent(AnalyticsEventNames.quizCompleted, [
        "ts": timestamp(for: date),
        "quiz_id": quizId,
        "score": score
    ])
}
