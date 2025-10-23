//
//  ProgramModel.swift
//  CarbFlow
//
//  Created for Phase 0.
//

import Foundation

struct DayModule: Identifiable, Hashable {
    let id = UUID()
    let day: Int
    let title: String
    let summary: String
}

enum Keys {
    static let currentDay = "cf_currentDay"
    static let streakCount = "cf_streakCount"
    static let lastCompletionISO = "cf_lastCompletionISO"
    static let isFasting = "cf_isFasting"
    static let fastingStart = "cf_fastingStart"
    static let username = "cf_username"
    static let hasOnboarded = "cf_hasOnboarded"
    static let carbTarget = "cf_carbTarget"
    static let hasSetCarbTarget = "cf_hasSetCarbTarget"
    static let carbEntriesJSON = "cf_carbEntriesJSON"
    static let carbEntriesDateISO = "cf_carbEntriesDateISO"
}

struct DayContent {
    let keyIdea: String
    let faqs: [String]
}

struct ProgramModel {
    static let modules: [DayModule] = [
        DayModule(day: 1, title: "Why Keto", summary: "Learn the metabolic context behind lowering carbs and using fat for fuel."),
        DayModule(day: 2, title: "Carb Targets", summary: "Choose a daily carb cap that balances dietary adherence with energy needs."),
        DayModule(day: 3, title: "Sweeteners 101", summary: "Compare natural and artificial sweeteners that fit ketosis."),
        DayModule(day: 4, title: "Pantry Reset", summary: "Clear out high-carb staples and restock with keto-friendly basics."),
        DayModule(day: 5, title: "Hidden Carbs", summary: "Spot sneaky sugars in condiments, sauces, and packaged foods."),
        DayModule(day: 6, title: "Hydration Essentials", summary: "Dial in water intake to support energy and appetite control."),
        DayModule(day: 7, title: "Electrolyte Balance", summary: "Prioritize sodium, potassium, and magnesium for steady energy."),
        DayModule(day: 8, title: "Breakfast Swaps", summary: "Reinvent morning meals with low-carb, high-fat ideas."),
        DayModule(day: 9, title: "Lunch Planning", summary: "Build portable keto lunches that keep you satisfied."),
        DayModule(day: 10, title: "Dinner Strategies", summary: "Craft balanced evening meals the whole family enjoys."),
        DayModule(day: 11, title: "Snack Prep", summary: "Prepare quick bites that prevent cravings and over-snacking."),
        DayModule(day: 12, title: "Eating Out", summary: "Navigate restaurant menus and stay within your carb budget."),
        DayModule(day: 13, title: "Label Literacy", summary: "Decode nutrition labels to confirm keto compliance."),
        DayModule(day: 14, title: "Macro Tracking", summary: "Use simple tracking tools to monitor carbs, fat, and protein."),
        DayModule(day: 15, title: "Fiber Focus", summary: "Increase low-carb fiber sources for gut and heart health."),
        DayModule(day: 16, title: "Healthy Fats", summary: "Choose quality fats that improve satiety and inflammation."),
        DayModule(day: 17, title: "Protein Priorities", summary: "Dial protein to protect lean mass and recovery."),
        DayModule(day: 18, title: "Meal Timing", summary: "Experiment with fasting windows that suit your schedule."),
        DayModule(day: 19, title: "Social Situations", summary: "Plan ahead for gatherings and keep goals intact."),
        DayModule(day: 20, title: "Dessert Makeovers", summary: "Satisfy sweet cravings with low-carb desserts."),
        DayModule(day: 21, title: "Plateau Busting", summary: "Adjust macros and habits when progress stalls."),
        DayModule(day: 22, title: "Sleep & Recovery", summary: "Support hormones and energy with rest-first routines."),
        DayModule(day: 23, title: "Workout Fueling", summary: "Match activity levels with targeted carb timing."),
        DayModule(day: 24, title: "Mindful Eating", summary: "Use hunger cues and mindful habits to avoid overeating."),
        DayModule(day: 25, title: "Stress Management", summary: "Build stress relief practices that curb emotional eating."),
        DayModule(day: 26, title: "Habit Stacking", summary: "Stack new routines on existing habits for consistency."),
        DayModule(day: 27, title: "Kitchen Tools", summary: "Equip your kitchen with gadgets for faster prep."),
        DayModule(day: 28, title: "Batch Cooking", summary: "Cook once and eat many times with freezer-friendly meals."),
        DayModule(day: 29, title: "Travel Tips", summary: "Stay on track while commuting or flying."),
        DayModule(day: 30, title: "Long-Term Success", summary: "Create a maintenance plan to sustain keto living."),
        DayModule(day: 31, title: "Fasting Focus", summary: "Investigate fasting strategies alongside keto (look into this).")
    ]

    static let contentByDay: [Int: DayContent] = [
        1: DayContent(
            keyIdea: "Keto lowers carbs to reduce glucose swings and encourage fat utilisation.",
            faqs: [
                "Is this medical advice? No—consult your doctor.",
                "Track calories now? Not yet; start with carbs only."
            ]
        ),
        2: DayContent(
            keyIdea: "Pick a sustainable daily carb cap: 20, 30, 40, or 50 g.",
            faqs: [
                "Which level? Start at 30 g; adjust in week 2.",
                "Do fibre carbs count? You can use net carbs—just be consistent."
            ]
        ),
        31: DayContent(
            keyIdea: "Fasting can complement ketosis; evaluate protocols and safety before implementing.",
            faqs: [
                "Should I fast daily? Look into this with your healthcare provider—start conservatively.",
                "How long should a fast last? Begin with short windows and monitor how you feel."
            ]
        )
    ]
}

extension Date {
    static let isoDayFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    var isoDayString: String {
        Date.isoDayFormatter.string(from: self)
    }
}
