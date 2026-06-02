import AuthenticationServices
import Charts
import Combine
import CoreData
import CoreML
import HealthKit
import PhotosUI
import SwiftUI
import UIKit
import UserNotifications
import Vision
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - Theme

enum FawFittTheme {
    static let background = Color(hex: 0x080709)
    static let secondaryBackground = Color(hex: 0x171519)
    static let neon = Color(hex: 0x45F38D)
    static let warning = Color(hex: 0xF87171)
    static let cyan = Color(hex: 0xD9FBE6)
    static let violet = Color(hex: 0x9EA0A6)
    static let glass = Color.white.opacity(0.085)
    static let glassStroke = Color.white.opacity(0.16)
    static let mutedText = Color.white.opacity(0.58)

    static let dashboardGradient = LinearGradient(
        colors: [neon.opacity(0.055), Color.white.opacity(0.018), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension DateFormatter {
    static let fawShortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let fawAgentDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Models

enum FitnessTarget: String, CaseIterable, Identifiable, Codable {
    case loseWeight = "Lose Weight"
    case gainMuscle = "Gain Muscle"
    case maintain = "Maintain Body"
    var id: String { rawValue }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
}

enum WorkoutCategory: String, CaseIterable, Identifiable {
    case shoulder = "Shoulder"
    case arms = "Arms"
    case legs = "Legs"
    case abs = "Abs"
    case cardio = "Cardio"
    var id: String { rawValue }

    /// Asset-catalog image whose photo matches this muscle group.
    var artworkAsset: String {
        switch self {
        case .shoulder: return "WorkoutShoulder"
        case .arms:     return "WorkoutArms"
        case .legs:     return "WorkoutLegs"
        case .abs:      return "WorkoutAbs"
        case .cardio:   return "WorkoutCardio"
        }
    }
}

enum ExerciseType: String, CaseIterable, Identifiable {
    case shoulderPress = "Shoulder Press"
    case lateralRaise = "Lateral Raise"
    case pikePushUp = "Pike Push Up"
    case pushUp = "Push Up"
    case bicepCurl = "Bicep Curl"
    case tricepDip = "Tricep Dip"
    case squat = "Squat"
    case lunge = "Lunge"
    case gluteBridge = "Glute Bridge"
    case crunch = "Crunch"
    case legRaise = "Leg Raise"
    case plank = "Plank"
    case jumpingJack = "Jumping Jack"
    case highKnees = "High Knees"
    case mountainClimber = "Mountain Climber"
    var id: String { rawValue }

    var planned: PlannedExercise {
        PlannedExercise(
            name: rawValue,
            sets: 3,
            reps: defaultReps,
            holdSeconds: self == .plank ? 30 : 0,
            isTimed: self == .plank,
            restSeconds: defaultRest,
            systemImage: defaultSymbol,
            muscle: defaultMuscle,
            equipment: defaultEquipment,
            difficulty: "beginner",
            instructions: ""
        )
    }

    private var defaultReps: Int {
        switch self {
        case .shoulderPress, .bicepCurl, .tricepDip: return 12
        case .lateralRaise: return 15
        case .pikePushUp, .pushUp: return 10
        case .squat, .lunge, .gluteBridge: return 15
        case .crunch, .legRaise: return 15
        case .plank: return 0
        case .jumpingJack: return 30
        case .highKnees, .mountainClimber: return 25
        }
    }

    private var defaultRest: Int {
        switch self {
        case .plank: return 30
        case .jumpingJack, .highKnees, .mountainClimber: return 30
        default: return 45
        }
    }

    private var defaultSymbol: String {
        switch self {
        case .shoulderPress, .lateralRaise, .pikePushUp: return "dumbbell.fill"
        case .pushUp: return "figure.strengthtraining.traditional"
        case .bicepCurl, .tricepDip: return "figure.arms.open"
        case .squat, .lunge: return "figure.cooldown"
        case .gluteBridge: return "figure.core.training"
        case .crunch, .legRaise: return "figure.core.training"
        case .plank: return "figure.mind.and.body"
        case .jumpingJack, .highKnees: return "figure.jumprope"
        case .mountainClimber: return "figure.run"
        }
    }

    private var defaultMuscle: String {
        switch self {
        case .shoulderPress, .lateralRaise, .pikePushUp: return "traps"
        case .pushUp: return "chest"
        case .bicepCurl: return "biceps"
        case .tricepDip: return "triceps"
        case .squat, .lunge: return "quadriceps"
        case .gluteBridge: return "glutes"
        case .crunch, .legRaise, .plank: return "abdominals"
        case .jumpingJack, .highKnees, .mountainClimber: return "cardio"
        }
    }

    private var defaultEquipment: String {
        switch self {
        case .shoulderPress, .lateralRaise, .bicepCurl: return "dumbbell"
        default: return "body_only"
        }
    }
}

struct PlannedExercise: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: Int
    let holdSeconds: Int
    let isTimed: Bool
    let restSeconds: Int
    let systemImage: String
    let muscle: String
    let equipment: String
    let difficulty: String
    let instructions: String

    var detailText: String {
        isTimed
            ? "\(sets) × \(holdSeconds)s hold • \(restSeconds)s rest"
            : "\(sets) × \(reps) reps • \(restSeconds)s rest"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PlannedExercise, rhs: PlannedExercise) -> Bool { lhs.id == rhs.id }
}

struct ApiNinjasExercise: Decodable {
    let name: String
    let type: String
    let muscle: String
    let equipment: String
    let difficulty: String
    let instructions: String
}

enum ApiNinjasService {
    enum APIError: LocalizedError {
        case noKey
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .noKey:        return "APININJAS_KEY missing in Info.plist or environment."
            case .http(let s):  return "API Ninjas HTTP \(s)"
            }
        }
    }

    static var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["APININJAS_KEY"], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "APININJAS_KEY") as? String, !plist.isEmpty {
            return plist
        }
        return nil
    }

    static func fetchExercises(muscle: String?, type: String?, difficulty: String?) async throws -> [ApiNinjasExercise] {
        guard let key = apiKey else { throw APIError.noKey }
        var comps = URLComponents(string: "https://api.api-ninjas.com/v1/exercises")!
        var items: [URLQueryItem] = []
        if let muscle, !muscle.isEmpty, muscle != "cardio" {
            items.append(URLQueryItem(name: "muscle", value: muscle))
        }
        if let type, !type.isEmpty {
            items.append(URLQueryItem(name: "type", value: type))
        }
        if let difficulty, !difficulty.isEmpty {
            items.append(URLQueryItem(name: "difficulty", value: difficulty))
        }
        comps.queryItems = items.isEmpty ? nil : items
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        return try JSONDecoder().decode([ApiNinjasExercise].self, from: data)
    }

    static func fetchCaloriesBurned(activity: String, weightKG: Double, durationMinutes: Int) async throws -> Int? {
        guard let key = apiKey else { throw APIError.noKey }
        var comps = URLComponents(string: "https://api.api-ninjas.com/v1/caloriesburned")!
        let weightLbs = Int((weightKG * 2.20462).rounded())
        comps.queryItems = [
            URLQueryItem(name: "activity", value: activity),
            URLQueryItem(name: "weight", value: String(weightLbs)),
            URLQueryItem(name: "duration", value: String(durationMinutes))
        ]
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        struct CalRow: Decodable {
            let name: String
            let total_calories: Int?
            let calories_per_hour: Int?
        }
        let rows = try JSONDecoder().decode([CalRow].self, from: data)
        return rows.first?.total_calories
    }
}

extension PlannedExercise {
    init(api: ApiNinjasExercise, sets: Int, reps: Int, restSeconds: Int) {
        let timed = api.type == "stretching" || api.name.lowercased().contains("plank")
        self.init(
            name: api.name,
            sets: sets,
            reps: timed ? 0 : reps,
            holdSeconds: timed ? 30 : 0,
            isTimed: timed,
            restSeconds: restSeconds,
            systemImage: Self.symbol(forType: api.type, muscle: api.muscle),
            muscle: api.muscle,
            equipment: api.equipment,
            difficulty: api.difficulty,
            instructions: api.instructions
        )
    }

    private static func symbol(forType type: String, muscle: String) -> String {
        switch type {
        case "cardio":      return "figure.run"
        case "stretching":  return "figure.mind.and.body"
        case "plyometrics": return "figure.jumprope"
        default: break
        }
        switch muscle {
        case "biceps", "triceps", "forearms": return "figure.arms.open"
        case "chest":                          return "figure.strengthtraining.traditional"
        case "quadriceps", "hamstrings", "calves", "glutes", "adductors", "abductors":
                                              return "figure.cooldown"
        case "abdominals":                     return "figure.core.training"
        case "traps", "lats", "lower_back", "middle_back", "neck":
                                              return "dumbbell.fill"
        default:                                return "figure.strengthtraining.functional"
        }
    }
}

extension WorkoutPlan {
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
}

struct UserFitnessProfile: Identifiable {
    let id = UUID()
    var name = "Alex"
    var heightCM = 176.0
    var weightKG = 72.0
    var gender = "Prefer not to say"
    var age = 29
    var activityLevel: ActivityLevel = .intermediate
    var dailyCalorieGoal = 2400
    var target: FitnessTarget = .maintain
    var workoutDaysPerWeek = 3
    var preferredWorkoutTime = "Evening"
    var equipment = "No equipment"
    var healthNotes = ""
}

struct HealthSnapshot {
    var activeEnergy: Double
    var steps: Double
    var heartRate: Double
    var sleepHours: Double
    var workoutMinutes: Double
    var caloriesBurned: Double

    static let mock = HealthSnapshot(
        activeEnergy: 684,
        steps: 8420,
        heartRate: 72,
        sleepHours: 7.4,
        workoutMinutes: 46,
        caloriesBurned: 820
    )

    static let empty = HealthSnapshot(
        activeEnergy: 0,
        steps: 0,
        heartRate: 0,
        sleepHours: 0,
        workoutMinutes: 0,
        caloriesBurned: 0
    )
}

struct AppleHealthAgentA2AResponse: Decodable {
    let jsonrpc: String
    let id: String
    let result: Result

    struct Result: Decodable {
        let agent: Agent
        let artifact: Artifact
        let calories: Calories
        let summary: String
    }

    struct Agent: Decodable {
        let name: String
        let persona: String
        let version: String
    }

    struct Artifact: Decodable {
        let type: String
        let unit: String
        let generatedAt: String
    }

    struct Calories: Decodable {
        let activeEnergyBurned: Int
        let restingEnergyBurned: Int
        let totalBurned: Int
        let dailyGoal: Int
        let samples: [CalorieSample]
    }

    struct CalorieSample: Decodable {
        let date: String
        let active: Int
        let total: Int
        let score: Int
    }

    var weeklyMetrics: [WeeklyMetric] {
        result.calories.samples.compactMap { sample in
            guard let date = DateFormatter.fawAgentDate.date(from: sample.date) else { return nil }
            return WeeklyMetric(
                date: date,
                calories: Double(sample.active),
                workouts: sample.active > 0 ? 1.0 : 0.0,
                score: Double(sample.score)
            )
        }
    }
}

enum AppleHealthAgentParser {
    static func decodeMockResponse() throws -> AppleHealthAgentA2AResponse {
        let data = Data(MockData.appleHealthAgentA2AResponseJSON.utf8)
        return try JSONDecoder().decode(AppleHealthAgentA2AResponse.self, from: data)
    }
}

struct WeeklyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let workouts: Double
    let score: Double
}

struct WorkoutPlan: Identifiable {
    let id = UUID()
    let title: String
    let category: WorkoutCategory
    let duration: Int
    let intensity: ActivityLevel
    let calories: Int
    let recoveryScore: Int
    let exercises: [PlannedExercise]
    let rationale: String
}

struct MealLog: Identifiable {
    var id = UUID()
    var name: String
    var mealType: String = "Meal"
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var mealDate: Date = Date()
}

// MARK: - Food Detection (on-device Food-101 CoreML)

struct FoodNutrition: Equatable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let displayName: String

    static let unknown = FoodNutrition(calories: 0, protein: 0, carbs: 0, fat: 0, displayName: "Unknown food")
}

enum FoodNutritionData {
    static let table: [String: FoodNutrition] = [
        "apple_pie":           FoodNutrition(calories: 296, protein: 2,  carbs: 43, fat: 14, displayName: "Apple pie"),
        "baby_back_ribs":      FoodNutrition(calories: 460, protein: 32, carbs: 8,  fat: 33, displayName: "Baby back ribs"),
        "baklava":             FoodNutrition(calories: 334, protein: 5,  carbs: 40, fat: 18, displayName: "Baklava"),
        "beef_carpaccio":      FoodNutrition(calories: 205, protein: 26, carbs: 2,  fat: 10, displayName: "Beef carpaccio"),
        "beef_tartare":        FoodNutrition(calories: 240, protein: 24, carbs: 3,  fat: 14, displayName: "Beef tartare"),
        "beet_salad":          FoodNutrition(calories: 130, protein: 4,  carbs: 14, fat: 7,  displayName: "Beet salad"),
        "beignets":            FoodNutrition(calories: 280, protein: 5,  carbs: 36, fat: 13, displayName: "Beignets"),
        "bibimbap":            FoodNutrition(calories: 560, protein: 21, carbs: 78, fat: 16, displayName: "Bibimbap"),
        "bread_pudding":       FoodNutrition(calories: 310, protein: 7,  carbs: 42, fat: 12, displayName: "Bread pudding"),
        "breakfast_burrito":   FoodNutrition(calories: 480, protein: 22, carbs: 44, fat: 22, displayName: "Breakfast burrito"),
        "bruschetta":          FoodNutrition(calories: 195, protein: 6,  carbs: 28, fat: 7,  displayName: "Bruschetta"),
        "caesar_salad":        FoodNutrition(calories: 320, protein: 9,  carbs: 12, fat: 27, displayName: "Caesar salad"),
        "cannoli":             FoodNutrition(calories: 220, protein: 4,  carbs: 24, fat: 12, displayName: "Cannoli"),
        "caprese_salad":       FoodNutrition(calories: 240, protein: 12, carbs: 6,  fat: 18, displayName: "Caprese salad"),
        "carrot_cake":         FoodNutrition(calories: 415, protein: 4,  carbs: 53, fat: 21, displayName: "Carrot cake"),
        "ceviche":             FoodNutrition(calories: 175, protein: 20, carbs: 8,  fat: 6,  displayName: "Ceviche"),
        "cheesecake":          FoodNutrition(calories: 410, protein: 7,  carbs: 35, fat: 28, displayName: "Cheesecake"),
        "cheese_plate":        FoodNutrition(calories: 380, protein: 22, carbs: 4,  fat: 30, displayName: "Cheese plate"),
        "chicken_curry":       FoodNutrition(calories: 430, protein: 28, carbs: 18, fat: 26, displayName: "Chicken curry"),
        "chicken_quesadilla":  FoodNutrition(calories: 520, protein: 28, carbs: 45, fat: 26, displayName: "Chicken quesadilla"),
        "chicken_wings":       FoodNutrition(calories: 430, protein: 30, carbs: 0,  fat: 32, displayName: "Chicken wings"),
        "chocolate_cake":      FoodNutrition(calories: 370, protein: 5,  carbs: 50, fat: 18, displayName: "Chocolate cake"),
        "chocolate_mousse":    FoodNutrition(calories: 290, protein: 5,  carbs: 25, fat: 20, displayName: "Chocolate mousse"),
        "churros":             FoodNutrition(calories: 250, protein: 3,  carbs: 28, fat: 14, displayName: "Churros"),
        "clam_chowder":        FoodNutrition(calories: 195, protein: 11, carbs: 18, fat: 9,  displayName: "Clam chowder"),
        "club_sandwich":       FoodNutrition(calories: 540, protein: 30, carbs: 38, fat: 28, displayName: "Club sandwich"),
        "crab_cakes":          FoodNutrition(calories: 240, protein: 15, carbs: 10, fat: 16, displayName: "Crab cakes"),
        "creme_brulee":        FoodNutrition(calories: 320, protein: 5,  carbs: 28, fat: 22, displayName: "Crème brûlée"),
        "croque_madame":       FoodNutrition(calories: 540, protein: 28, carbs: 38, fat: 30, displayName: "Croque madame"),
        "cup_cakes":           FoodNutrition(calories: 190, protein: 2,  carbs: 28, fat: 8,  displayName: "Cupcakes"),
        "deviled_eggs":        FoodNutrition(calories: 145, protein: 6,  carbs: 1,  fat: 13, displayName: "Deviled eggs"),
        "donuts":              FoodNutrition(calories: 260, protein: 4,  carbs: 32, fat: 14, displayName: "Donuts"),
        "dumplings":           FoodNutrition(calories: 300, protein: 12, carbs: 38, fat: 11, displayName: "Dumplings"),
        "edamame":             FoodNutrition(calories: 120, protein: 11, carbs: 9,  fat: 5,  displayName: "Edamame"),
        "eggs_benedict":       FoodNutrition(calories: 425, protein: 22, carbs: 28, fat: 25, displayName: "Eggs benedict"),
        "escargots":           FoodNutrition(calories: 180, protein: 14, carbs: 2,  fat: 14, displayName: "Escargots"),
        "falafel":             FoodNutrition(calories: 333, protein: 13, carbs: 32, fat: 18, displayName: "Falafel"),
        "filet_mignon":        FoodNutrition(calories: 380, protein: 40, carbs: 0,  fat: 24, displayName: "Filet mignon"),
        "fish_and_chips":      FoodNutrition(calories: 620, protein: 24, carbs: 65, fat: 30, displayName: "Fish and chips"),
        "foie_gras":           FoodNutrition(calories: 460, protein: 12, carbs: 5,  fat: 44, displayName: "Foie gras"),
        "french_fries":        FoodNutrition(calories: 365, protein: 4,  carbs: 48, fat: 17, displayName: "French fries"),
        "french_onion_soup":   FoodNutrition(calories: 290, protein: 13, carbs: 26, fat: 15, displayName: "French onion soup"),
        "french_toast":        FoodNutrition(calories: 320, protein: 11, carbs: 38, fat: 14, displayName: "French toast"),
        "fried_calamari":      FoodNutrition(calories: 310, protein: 18, carbs: 22, fat: 16, displayName: "Fried calamari"),
        "fried_rice":          FoodNutrition(calories: 400, protein: 12, carbs: 56, fat: 14, displayName: "Fried rice"),
        "frozen_yogurt":       FoodNutrition(calories: 160, protein: 4,  carbs: 28, fat: 4,  displayName: "Frozen yogurt"),
        "garlic_bread":        FoodNutrition(calories: 200, protein: 5,  carbs: 24, fat: 9,  displayName: "Garlic bread"),
        "gnocchi":             FoodNutrition(calories: 380, protein: 9,  carbs: 60, fat: 12, displayName: "Gnocchi"),
        "greek_salad":         FoodNutrition(calories: 220, protein: 7,  carbs: 11, fat: 17, displayName: "Greek salad"),
        "grilled_cheese_sandwich": FoodNutrition(calories: 380, protein: 14, carbs: 28, fat: 24, displayName: "Grilled cheese sandwich"),
        "grilled_salmon":      FoodNutrition(calories: 360, protein: 38, carbs: 0,  fat: 22, displayName: "Grilled salmon"),
        "guacamole":           FoodNutrition(calories: 150, protein: 2,  carbs: 8,  fat: 14, displayName: "Guacamole"),
        "gyoza":               FoodNutrition(calories: 280, protein: 11, carbs: 32, fat: 12, displayName: "Gyoza"),
        "hamburger":           FoodNutrition(calories: 540, protein: 28, carbs: 40, fat: 30, displayName: "Hamburger"),
        "hot_and_sour_soup":   FoodNutrition(calories: 160, protein: 9,  carbs: 14, fat: 8,  displayName: "Hot and sour soup"),
        "hot_dog":             FoodNutrition(calories: 290, protein: 11, carbs: 22, fat: 18, displayName: "Hot dog"),
        "huevos_rancheros":    FoodNutrition(calories: 420, protein: 18, carbs: 32, fat: 24, displayName: "Huevos rancheros"),
        "hummus":              FoodNutrition(calories: 180, protein: 6,  carbs: 14, fat: 11, displayName: "Hummus"),
        "ice_cream":           FoodNutrition(calories: 270, protein: 5,  carbs: 31, fat: 14, displayName: "Ice cream"),
        "lasagna":             FoodNutrition(calories: 460, protein: 22, carbs: 38, fat: 24, displayName: "Lasagna"),
        "lobster_bisque":      FoodNutrition(calories: 290, protein: 14, carbs: 14, fat: 20, displayName: "Lobster bisque"),
        "lobster_roll_sandwich": FoodNutrition(calories: 510, protein: 28, carbs: 36, fat: 28, displayName: "Lobster roll sandwich"),
        "macaroni_and_cheese": FoodNutrition(calories: 425, protein: 16, carbs: 44, fat: 22, displayName: "Macaroni and cheese"),
        "macarons":            FoodNutrition(calories: 95,  protein: 2,  carbs: 14, fat: 4,  displayName: "Macarons"),
        "miso_soup":           FoodNutrition(calories: 85,  protein: 5,  carbs: 9,  fat: 3,  displayName: "Miso soup"),
        "mussels":             FoodNutrition(calories: 180, protein: 22, carbs: 8,  fat: 6,  displayName: "Mussels"),
        "nachos":              FoodNutrition(calories: 580, protein: 18, carbs: 56, fat: 32, displayName: "Nachos"),
        "omelette":            FoodNutrition(calories: 280, protein: 18, carbs: 4,  fat: 22, displayName: "Omelette"),
        "onion_rings":         FoodNutrition(calories: 410, protein: 6,  carbs: 52, fat: 20, displayName: "Onion rings"),
        "oysters":             FoodNutrition(calories: 80,  protein: 9,  carbs: 4,  fat: 3,  displayName: "Oysters"),
        "pad_thai":            FoodNutrition(calories: 480, protein: 22, carbs: 58, fat: 18, displayName: "Pad thai"),
        "paella":              FoodNutrition(calories: 480, protein: 24, carbs: 56, fat: 16, displayName: "Paella"),
        "pancakes":            FoodNutrition(calories: 350, protein: 8,  carbs: 50, fat: 12, displayName: "Pancakes"),
        "panna_cotta":         FoodNutrition(calories: 280, protein: 5,  carbs: 24, fat: 19, displayName: "Panna cotta"),
        "peking_duck":         FoodNutrition(calories: 460, protein: 28, carbs: 18, fat: 32, displayName: "Peking duck"),
        "pho":                 FoodNutrition(calories: 350, protein: 24, carbs: 44, fat: 8,  displayName: "Pho"),
        "pizza":               FoodNutrition(calories: 285, protein: 12, carbs: 36, fat: 10, displayName: "Pizza (1 slice)"),
        "pork_chop":           FoodNutrition(calories: 340, protein: 32, carbs: 0,  fat: 22, displayName: "Pork chop"),
        "poutine":             FoodNutrition(calories: 620, protein: 18, carbs: 58, fat: 36, displayName: "Poutine"),
        "prime_rib":           FoodNutrition(calories: 540, protein: 40, carbs: 0,  fat: 42, displayName: "Prime rib"),
        "pulled_pork_sandwich": FoodNutrition(calories: 480, protein: 28, carbs: 38, fat: 22, displayName: "Pulled pork sandwich"),
        "ramen":               FoodNutrition(calories: 480, protein: 22, carbs: 60, fat: 16, displayName: "Ramen"),
        "ravioli":             FoodNutrition(calories: 380, protein: 16, carbs: 48, fat: 14, displayName: "Ravioli"),
        "red_velvet_cake":     FoodNutrition(calories: 390, protein: 4,  carbs: 52, fat: 19, displayName: "Red velvet cake"),
        "risotto":             FoodNutrition(calories: 410, protein: 11, carbs: 56, fat: 14, displayName: "Risotto"),
        "samosa":              FoodNutrition(calories: 260, protein: 5,  carbs: 30, fat: 14, displayName: "Samosa"),
        "sashimi":             FoodNutrition(calories: 145, protein: 23, carbs: 0,  fat: 5,  displayName: "Sashimi"),
        "scallops":            FoodNutrition(calories: 160, protein: 22, carbs: 4,  fat: 5,  displayName: "Scallops"),
        "seaweed_salad":       FoodNutrition(calories: 100, protein: 2,  carbs: 9,  fat: 7,  displayName: "Seaweed salad"),
        "shrimp_and_grits":    FoodNutrition(calories: 430, protein: 22, carbs: 38, fat: 22, displayName: "Shrimp and grits"),
        "spaghetti_bolognese": FoodNutrition(calories: 520, protein: 22, carbs: 60, fat: 22, displayName: "Spaghetti bolognese"),
        "spaghetti_carbonara": FoodNutrition(calories: 580, protein: 22, carbs: 56, fat: 28, displayName: "Spaghetti carbonara"),
        "spring_rolls":        FoodNutrition(calories: 180, protein: 6,  carbs: 22, fat: 8,  displayName: "Spring rolls"),
        "steak":               FoodNutrition(calories: 480, protein: 42, carbs: 0,  fat: 32, displayName: "Steak"),
        "strawberry_shortcake": FoodNutrition(calories: 340, protein: 4,  carbs: 48, fat: 15, displayName: "Strawberry shortcake"),
        "sushi":               FoodNutrition(calories: 200, protein: 8,  carbs: 38, fat: 2,  displayName: "Sushi"),
        "tacos":               FoodNutrition(calories: 220, protein: 11, carbs: 18, fat: 12, displayName: "Tacos"),
        "takoyaki":            FoodNutrition(calories: 220, protein: 9,  carbs: 28, fat: 8,  displayName: "Takoyaki"),
        "tiramisu":            FoodNutrition(calories: 380, protein: 6,  carbs: 35, fat: 24, displayName: "Tiramisu"),
        "tuna_tartare":        FoodNutrition(calories: 220, protein: 24, carbs: 4,  fat: 12, displayName: "Tuna tartare"),
        "waffles":             FoodNutrition(calories: 310, protein: 7,  carbs: 38, fat: 14, displayName: "Waffles")
    ]

    static func lookup(_ rawLabel: String) -> FoodNutrition? {
        let candidates: [String] = [
            rawLabel,
            rawLabel.lowercased().replacingOccurrences(of: " ", with: "_"),
            rawLabel.lowercased().replacingOccurrences(of: "-", with: "_")
        ]
        for key in candidates {
            if let hit = table[key] { return hit }
        }
        return nil
    }
}

struct FoodPrediction: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let displayName: String
    let confidence: Double
    let nutrition: FoodNutrition
}

@MainActor
final class FoodCalorieClassifier: ObservableObject {
    @Published private(set) var usingCoreML = false
    @Published private(set) var lastError: String?

    private var visionModel: VNCoreMLModel?
    private static let modelCandidates = ["FoodClassifier", "Food101Classifier"]

    init(modelName: String? = nil) {
        let names = modelName.map { [$0] } ?? Self.modelCandidates
        loadModel(named: names)
    }

    private func loadModel(named names: [String]) {
        for name in names {
            let urls: [URL?] = [
                Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
                Bundle.main.url(forResource: name, withExtension: "mlmodel")
            ]
            for case let url? in urls {
                do {
                    let config = MLModelConfiguration()
                    config.computeUnits = .all
                    let mlModel = try MLModel(contentsOf: url, configuration: config)
                    let vision = try VNCoreMLModel(for: mlModel)
                    self.visionModel = vision
                    self.usingCoreML = true
                    print("[FoodCoreML] Loaded \(url.lastPathComponent)")
                    return
                } catch {
                    print("[FoodCoreML] Failed to init \(url.lastPathComponent): \(error)")
                }
            }
        }
        usingCoreML = false
        print("[FoodCoreML] No food classifier bundled (tried \(names.joined(separator: ", ")))")
    }

    func classify(_ image: UIImage) async -> FoodPrediction? {
        guard let visionModel else {
            lastError = "Food classifier model not bundled. Train one in Create ML and add it to the project."
            return nil
        }
        guard let cgImage = image.cgImage ?? image.fixedOrientation().cgImage else {
            lastError = "Couldn't read pixel data from the photo."
            return nil
        }
        lastError = nil
        return await withCheckedContinuation { (cont: CheckedContinuation<FoodPrediction?, Never>) in
            let request = VNCoreMLRequest(model: visionModel) { req, error in
                if let error {
                    Task { @MainActor in self.lastError = error.localizedDescription }
                    cont.resume(returning: nil)
                    return
                }
                guard let results = req.results as? [VNClassificationObservation],
                      let top = results.first else {
                    cont.resume(returning: nil)
                    return
                }
                let nutrition = FoodNutritionData.lookup(top.identifier) ?? FoodNutrition.unknown
                let displayName = nutrition == .unknown
                    ? top.identifier.replacingOccurrences(of: "_", with: " ").capitalized
                    : nutrition.displayName
                let pred = FoodPrediction(
                    label: top.identifier,
                    displayName: displayName,
                    confidence: Double(top.confidence),
                    nutrition: nutrition
                )
                cont.resume(returning: pred)
            }
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    Task { @MainActor in self.lastError = error.localizedDescription }
                    cont.resume(returning: nil)
                }
            }
        }
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return normalized
    }
}

enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .breakfast: return "sun.max.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }

    static func sortOrder(_ raw: String) -> Int {
        switch raw {
        case Self.breakfast.rawValue: return 0
        case Self.lunch.rawValue: return 1
        case Self.dinner.rawValue: return 2
        case Self.snack.rawValue: return 3
        default: return 4
        }
    }
}

struct CoachMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let date = Date()
}

struct Achievement: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let unlocked: Bool
}

enum AchievementTier: String {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"

    var color: Color {
        switch self {
        case .bronze: return Color(hex: 0xCD7F32)
        case .silver: return Color(hex: 0xC0C0C0)
        case .gold:   return FawFittTheme.neon
        }
    }
}

struct GamifiedAchievement: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tier: AchievementTier
    let target: Int
    let currentValue: Int
    let unit: String

    var isUnlocked: Bool { currentValue >= target }
    var progress: Double { min(1, Double(currentValue) / Double(max(1, target))) }
    var remaining: Int { max(0, target - currentValue) }
}

struct RegistrationProfile: Codable {
    var name = ""
    var gender = "Prefer not to say"
    var age = 20
    var heightCM = 170.0
    var weightKG = 65.0
    var target: FitnessTarget = .maintain
    var activityLevel: ActivityLevel = .beginner
    var workoutDaysPerWeek = 3
    var preferredWorkoutTime = "Evening"
    var equipment = "No equipment"
    var healthNotes = ""

    init() {}

    var estimatedDailyCalorieGoal: Int {
        let base = 10 * weightKG + 6.25 * heightCM - 5 * Double(age)
        let genderAdjustment = gender == "Female" ? -161.0 : 5.0
        let activityMultiplier: Double
        switch activityLevel {
        case .beginner: activityMultiplier = 1.35
        case .intermediate: activityMultiplier = 1.55
        case .advanced: activityMultiplier = 1.75
        }

        let targetAdjustment: Double
        switch target {
        case .loseWeight: targetAdjustment = -350
        case .gainMuscle: targetAdjustment = 250
        case .maintain: targetAdjustment = 0
        }

        return max(1200, Int(((base + genderAdjustment) * activityMultiplier + targetAdjustment).rounded()))
    }

    func applied(to profile: inout UserFitnessProfile, email: String) {
        profile.name = name.isEmpty ? email.components(separatedBy: "@").first ?? "Athlete" : name
        profile.gender = gender
        profile.age = age
        profile.heightCM = heightCM
        profile.weightKG = weightKG
        profile.activityLevel = activityLevel
        profile.target = target
        profile.dailyCalorieGoal = estimatedDailyCalorieGoal
        profile.workoutDaysPerWeek = workoutDaysPerWeek
        profile.preferredWorkoutTime = preferredWorkoutTime
        profile.equipment = equipment
        profile.healthNotes = healthNotes
    }
}

extension UserFitnessProfile {
    init(registration: RegistrationProfile) {
        self.init()
        self.name = registration.name
        self.gender = registration.gender
        self.age = registration.age
        self.heightCM = registration.heightCM
        self.weightKG = registration.weightKG
        self.activityLevel = registration.activityLevel
        self.target = registration.target
        self.dailyCalorieGoal = registration.estimatedDailyCalorieGoal
        self.workoutDaysPerWeek = registration.workoutDaysPerWeek
        self.preferredWorkoutTime = registration.preferredWorkoutTime
        self.equipment = registration.equipment
        self.healthNotes = registration.healthNotes
    }

    var asRegistration: RegistrationProfile {
        var reg = RegistrationProfile()
        reg.name = name
        reg.gender = gender
        reg.age = age
        reg.heightCM = heightCM
        reg.weightKG = weightKG
        reg.activityLevel = activityLevel
        reg.target = target
        reg.workoutDaysPerWeek = workoutDaysPerWeek
        reg.preferredWorkoutTime = preferredWorkoutTime
        reg.equipment = equipment
        reg.healthNotes = healthNotes
        return reg
    }
}

// MARK: - Services

// MARK: - A2A API Service
// Implements A2A Protocol: https://a2a-protocol.org/latest/
// JSON-RPC 2.0 endpoint: POST /
// Agent Card discovery:  GET  /.well-known/agent.json

enum FawFittAPIService {
    // Use Mac's local IP (e.g. "http://192.168.1.x:8000") when testing on a real device.
    static let baseURL = "http://localhost:8000"

    // MARK: Private helpers

    /// Build an A2A-compliant JSON-RPC 2.0 message/send request.
    private static func a2aRequest(skill: String, message: String, contextId: String? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        let msgId = UUID().uuidString
        let ctxId = contextId ?? UUID().uuidString

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": msgId,
            "method": "message/send",
            "params": [
                "message": [
                    "role": "user",
                    "parts": [["type": "text", "text": message]],
                    "messageId": msgId,
                    "contextId": ctxId
                ] as [String: Any],
                // metadata.skill is a FawFitt extension for explicit skill routing
                "metadata": ["skill": skill]
            ] as [String: Any]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// Extract the first text part from the A2A Task result artifacts.
    private static func extractArtifactText(from data: Data) throws -> String {
        guard
            let json      = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result    = json["result"]    as? [String: Any],
            let artifacts = result["artifacts"] as? [[String: Any]],
            let parts     = artifacts.first?["parts"] as? [[String: Any]],
            let text      = parts.first?["text"] as? String,
            !text.isEmpty
        else { throw URLError(.cannotParseResponse) }
        return text
    }

    // MARK: Public API

    /// Fetch Agent Card for discovery (optional – used for debugging).
    static func fetchAgentCard() async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/.well-known/agent.json") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }

    /// apple_health skill → returns AppleHealthAgentA2AResponse (the inner A2A payload).
    static func fetchAppleHealth() async throws -> AppleHealthAgentA2AResponse {
        let req = try a2aRequest(skill: "apple_health", message: "Get Apple Health calorie summary")
        let (data, _) = try await URLSession.shared.data(for: req)
        let jsonText   = try extractArtifactText(from: data)
        guard let jsonData = jsonText.data(using: .utf8) else { throw URLError(.cannotParseResponse) }
        return try JSONDecoder().decode(AppleHealthAgentA2AResponse.self, from: jsonData)
    }

    /// coach_chat skill → returns the coach's reply text.
    static func sendCoachMessage(_ text: String, profileSummary: String = "") async throws -> String {
        let fullMessage = profileSummary.isEmpty ? text : "\(text)\n\nUser profile: \(profileSummary)"
        let req = try a2aRequest(skill: "coach_chat", message: fullMessage)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try extractArtifactText(from: data)
    }
}

// MARK: - AI Plugin

protocol AIPlugin {
    var identifier: String { get }
    func run(prompt: String, context: String) async throws -> String
}

extension AIPlugin {
    func run(prompt: String) async throws -> String {
        try await run(prompt: prompt, context: "")
    }
}

struct MockCoachPlugin: AIPlugin {
    let identifier = "fawfitt.ai.coach.mock"

    func run(prompt: String, context: String) async throws -> String {
        do {
            return try await FawFittAPIService.sendCoachMessage(prompt, profileSummary: context)
        } catch {
            // Server offline fallback — still personalize from the context summary so the
            // canned reply at least addresses the user.
            try await Task.sleep(nanoseconds: 350_000_000)
            let goalLine = context.contains("Lose Weight")  ? "fat-loss"
                         : context.contains("Gain Muscle")  ? "hypertrophy"
                         : "maintenance"
            return "Neural coach readout: keep today's session recovery-aware for your \(goalLine) goal. Pair 28 minutes of strength with mobility cooldown, then hit 2.8L hydration. \(prompt.isEmpty ? "Your trend is climbing." : "Signal noted: \(prompt)")"
        }
    }
}

enum GroqConfig {
    static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    static let defaultModel = "llama-3.1-8b-instant"
    static let systemPrompt = "You are FawFitt's AI fitness coach. Reply in the same language as the user. Keep answers under 110 words, give short motivating actionable advice on training, recovery, hydration, and nutrition."

    /// Resolves the Groq API key from (in order):
    /// 1. Process environment `GROQ_API_KEY` (Xcode scheme env vars during dev).
    /// 2. Info.plist key `GROQ_API_KEY` (production builds via xcconfig injection).
    /// Returns nil when no key is configured — `GroqCoachPlugin` then throws and
    /// the coach pipeline falls back to `MockCoachPlugin`.
    static var apiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String, !plistKey.isEmpty {
            return plistKey
        }
        return nil
    }
}

struct GroqCoachPlugin: AIPlugin {
    let identifier = "fawfitt.ai.coach.groq"
    let model: String

    init(model: String = GroqConfig.defaultModel) { self.model = model }

    func run(prompt: String, context: String) async throws -> String {
        guard let apiKey = GroqConfig.apiKey else {
            throw NSError(domain: "fawfitt.groq", code: -10, userInfo: [
                NSLocalizedDescriptionKey: "GROQ_API_KEY is not configured. Set it in Xcode scheme env vars or Info.plist."
            ])
        }
        var req = URLRequest(url: GroqConfig.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let systemContent: String = context.isEmpty
            ? GroqConfig.systemPrompt
            : "\(GroqConfig.systemPrompt)\n\nYou know the user. Use this profile and recent data to personalize every reply. Address them by name when relevant. Reference their goal, recent workouts, and recovery signal when giving advice.\n\n--- USER CONTEXT ---\n\(context)\n--- END CONTEXT ---"
        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.6,
            "max_tokens": 320,
            "messages": [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": prompt]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "fawfitt.groq", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Groq error \(http.statusCode): \(body)"
            ])
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw URLError(.cannotParseResponse) }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class PluginRegistry {
    static let shared = PluginRegistry()
    private var plugins: [AIPlugin] = [GroqCoachPlugin(), MockCoachPlugin()]

    func plugin(named identifier: String) -> AIPlugin? {
        plugins.first { $0.identifier == identifier }
    }
}

struct StoredWorkoutLog: Codable, Identifiable {
    var id = UUID()
    var planTitle: String
    var category: String
    var durationSeconds: Int
    var completedSets: Int
    var totalSets: Int
    var calories: Int
    var completedAt: Date
}

struct StoredUserData: Codable {
    var email: String
    var profile: RegistrationProfile
    var workouts: [StoredWorkoutLog] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

enum LocalUserStore {
    private static var rootDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = docs.appendingPathComponent("users", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private static func fileURL(forUID uid: String) -> URL {
        rootDirectory.appendingPathComponent("\(uid).json")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func load(uid: String) -> StoredUserData? {
        let url = fileURL(forUID: uid)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(StoredUserData.self, from: data)
    }

    static func save(_ stored: StoredUserData, uid: String) throws {
        var copy = stored
        copy.updatedAt = Date()
        let data = try encoder.encode(copy)
        let url = fileURL(forUID: uid)
        try data.write(to: url, options: [.atomic])
        print("[LocalStore] wrote \(url.path) (\(data.count) bytes)")
    }

    static func upsertProfile(_ profile: RegistrationProfile, uid: String, email: String) throws {
        var stored = load(uid: uid) ?? StoredUserData(email: email, profile: profile)
        stored.email = email
        stored.profile = profile
        try save(stored, uid: uid)
    }

    static func appendWorkout(_ log: StoredWorkoutLog, uid: String, email: String) throws {
        var stored = load(uid: uid) ?? StoredUserData(email: email, profile: RegistrationProfile())
        stored.workouts.append(log)
        try save(stored, uid: uid)
    }

    static func clear(uid: String) {
        try? FileManager.default.removeItem(at: fileURL(forUID: uid))
    }
}

enum FitnessDataStore {
    enum StoreError: LocalizedError {
        case notAuthenticated
        case firebaseUnavailable

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:    return "You are signed out. Log in again to sync."
            case .firebaseUnavailable: return "Firebase Auth is not linked to this build."
            }
        }
    }

    static func createAccount(email: String, password: String) async throws -> String {
        #if canImport(FirebaseAuth)
        _ = try await Auth.auth().createUser(withEmail: normalizedEmail(email), password: password)
        return "Account created"
        #else
        throw StoreError.firebaseUnavailable
        #endif
    }

    static func saveOnboardingProfile(email: String, profile: RegistrationProfile) async throws {
        try await persist(profile: profile, email: email, isOnboarding: true)
    }

    static func saveProfile(_ profile: UserFitnessProfile, email: String) async throws {
        try await persist(profile: profile.asRegistration, email: email, isOnboarding: false)
    }

    private static func persist(profile: RegistrationProfile, email: String, isOnboarding: Bool) async throws {
        let uid = try currentUID()
        try LocalUserStore.upsertProfile(profile, uid: uid, email: normalizedEmail(email))
        print("[LocalStore] saved profile uid=\(uid) onboarding=\(isOnboarding)")
        #if canImport(FirebaseAuth)
        if isOnboarding, let user = Auth.auth().currentUser {
            let change = user.createProfileChangeRequest()
            change.displayName = profile.name
            try? await change.commitChanges()
        }
        #endif
    }

    /// Returns the persisted RegistrationProfile for the current user, or nil if none exists.
    static func loadProfile() async -> RegistrationProfile? {
        guard let uid = try? currentUID() else { return nil }
        return LocalUserStore.load(uid: uid)?.profile
    }

    static func signIn(email: String, password: String) async throws -> String {
        #if canImport(FirebaseAuth)
        _ = try await Auth.auth().signIn(withEmail: normalizedEmail(email), password: password)
        return "Signed in"
        #else
        throw StoreError.firebaseUnavailable
        #endif
    }

    static func hasFirebaseSession() -> Bool {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser != nil
        #else
        return false
        #endif
    }

    static func signOut() throws {
        #if canImport(FirebaseAuth)
        try Auth.auth().signOut()
        #endif
    }

    static func logWorkoutSession(planTitle: String, category: String, durationSeconds: Int, completedSets: Int, totalSets: Int, calories: Int) async {
        guard let uid = try? currentUID() else { return }
        let log = StoredWorkoutLog(
            planTitle: planTitle,
            category: category,
            durationSeconds: durationSeconds,
            completedSets: completedSets,
            totalSets: totalSets,
            calories: calories,
            completedAt: Date()
        )
        do {
            try LocalUserStore.appendWorkout(log, uid: uid, email: currentEmail())
        } catch {
            print("[LocalStore] logWorkoutSession failed: \(error)")
        }
    }

    static func loadWorkoutLogs() -> [StoredWorkoutLog] {
        guard let uid = try? currentUID() else { return [] }
        return LocalUserStore.load(uid: uid)?.workouts ?? []
    }

    static func currentEmail() -> String {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.email ?? ""
        #else
        return ""
        #endif
    }

    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func currentUID() throws -> String {
        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw StoreError.notAuthenticated
        }
        return uid
        #else
        throw StoreError.firebaseUnavailable
        #endif
    }
}

actor WorkoutRecommendationEngine {
    func recommendations(profile: UserFitnessProfile, health: HealthSnapshot) async -> [WorkoutPlan] {
        let recovery = recoveryFactor(for: health)
        let categories = categoryRotation(for: profile.target, daysPerWeek: profile.workoutDaysPerWeek)
        let intensity = intensityScale(for: profile.activityLevel)
        let difficulty = apiDifficulty(for: profile.activityLevel)

        // Fetch live exercises per category in parallel (one API Ninjas call each).
        // If any call fails or the key is missing, fall back to the local catalog for
        // that category so the user always gets a plan.
        return await withTaskGroup(of: (Int, WorkoutPlan).self) { group in
            for (index, category) in categories.enumerated() {
                group.addTask { [self] in
                    let exercises = await self.fetchExercises(
                        category: category,
                        target: profile.target,
                        equipment: profile.equipment,
                        difficulty: difficulty
                    )
                    let plan = await self.buildPlan(
                        category: category,
                        index: index,
                        profile: profile,
                        recovery: recovery,
                        intensity: intensity,
                        health: health,
                        exercises: exercises
                    )
                    return (index, plan)
                }
            }
            var results: [(Int, WorkoutPlan)] = []
            for await pair in group { results.append(pair) }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    private func apiDifficulty(for level: ActivityLevel) -> String {
        switch level {
        case .beginner:     return "beginner"
        case .intermediate: return "intermediate"
        case .advanced:     return "expert"
        }
    }

    /// Tries API Ninjas first; on any failure (no key, HTTP error, empty result) falls back
    /// to the local ExerciseType catalog so the workout matrix is never empty.
    private func fetchExercises(
        category: WorkoutCategory,
        target: FitnessTarget,
        equipment: String,
        difficulty: String
    ) async -> [PlannedExercise] {
        let muscle = apiMuscle(for: category, target: target)
        let type = category == .cardio ? "cardio" : "strength"
        do {
            let live = try await ApiNinjasService.fetchExercises(
                muscle: muscle,
                type: type,
                difficulty: difficulty
            )
            let filtered = filterByEquipment(live, equipment: equipment).prefix(3)
            if filtered.isEmpty {
                return localExercises(for: category, target: target, equipment: equipment)
            }
            let restSeconds = category == .cardio ? 30 : 45
            let reps = repsFor(category: category, target: target)
            let mapped = filtered.map { PlannedExercise(api: $0, sets: 3, reps: reps, restSeconds: restSeconds) }
            print("[ApiNinjas] \(category.rawValue) live=\(mapped.count) (\(mapped.map(\.name).joined(separator: ", ")))")
            return Array(mapped)
        } catch {
            print("[ApiNinjas] \(category.rawValue) fallback to local catalog: \(error.localizedDescription)")
            return localExercises(for: category, target: target, equipment: equipment)
        }
    }

    private func apiMuscle(for category: WorkoutCategory, target: FitnessTarget) -> String? {
        switch category {
        case .shoulder: return "traps"
        case .arms:     return target == .gainMuscle ? "biceps" : "triceps"
        case .legs:
            switch target {
            case .gainMuscle: return "quadriceps"
            case .loseWeight: return "glutes"
            case .maintain:   return "hamstrings"
            }
        case .abs:      return "abdominals"
        case .cardio:   return nil
        }
    }

    private func filterByEquipment(_ list: [ApiNinjasExercise], equipment: String) -> [ApiNinjasExercise] {
        switch equipment {
        case "No equipment":
            return list.filter { ["body_only", "none", ""].contains($0.equipment) }
        case "Dumbbells":
            return list.filter { ["dumbbell", "body_only", "none", ""].contains($0.equipment) }
        case "Resistance bands":
            return list.filter { ["bands", "body_only", "none", ""].contains($0.equipment) }
        default: // Full gym
            return list
        }
    }

    private func repsFor(category: WorkoutCategory, target: FitnessTarget) -> Int {
        switch (category, target) {
        case (.cardio, _):          return 30
        case (_, .gainMuscle):      return 10
        case (_, .loseWeight):      return 15
        case (_, .maintain):        return 12
        }
    }

    private func localExercises(
        for category: WorkoutCategory,
        target: FitnessTarget,
        equipment: String
    ) -> [PlannedExercise] {
        legacyExercises(for: category, target: target, equipment: equipment).map(\.planned)
    }

    // 0.3 (poor) … 1.0 (great) based on sleep + resting HR.
    private func recoveryFactor(for health: HealthSnapshot) -> Double {
        let sleepScore = max(0, min(1, health.sleepHours / 8))
        let hrScore: Double
        if health.heartRate <= 0 {
            hrScore = 0.5
        } else {
            hrScore = max(0, min(1, (85 - health.heartRate) / 25))
        }
        return max(0.3, sleepScore * 0.6 + hrScore * 0.4)
    }

    private func intensityScale(for level: ActivityLevel) -> Double {
        switch level {
        case .beginner:     return 0.75
        case .intermediate: return 1.0
        case .advanced:     return 1.25
        }
    }

    private func categoryRotation(for target: FitnessTarget, daysPerWeek: Int) -> [WorkoutCategory] {
        let base: [WorkoutCategory]
        switch target {
        case .loseWeight: base = [.cardio, .legs, .abs, .cardio, .arms, .legs]
        case .gainMuscle: base = [.shoulder, .legs, .arms, .shoulder, .abs, .legs]
        case .maintain:   base = [.legs, .arms, .abs, .cardio, .shoulder]
        }
        let count = max(2, min(base.count, daysPerWeek))
        return Array(base.prefix(count))
    }

    /// Per-workout-type session length and burn rate, then nudged by the user's goal.
    /// Cardio burns fastest, big-muscle leg work runs longest, core sessions are short.
    /// `loseWeight` lengthens and raises burn, `gainMuscle` lengthens but lowers cardio burn.
    private func baseMetrics(for category: WorkoutCategory, target: FitnessTarget) -> (duration: Int, kcalPerMin: Double) {
        let categoryBase: (duration: Int, kcalPerMin: Double)
        switch category {
        case .cardio:   categoryBase = (28, 11.5)
        case .legs:     categoryBase = (40, 9.0)
        case .shoulder: categoryBase = (34, 7.0)
        case .arms:     categoryBase = (30, 6.0)
        case .abs:      categoryBase = (24, 5.5)
        }

        let durationScale: Double
        let burnScale: Double
        switch target {
        case .loseWeight: durationScale = 1.15; burnScale = 1.15
        case .gainMuscle: durationScale = 1.10; burnScale = 0.92
        case .maintain:   durationScale = 1.0;  burnScale = 1.0
        }

        return (
            Int((Double(categoryBase.duration) * durationScale).rounded()),
            categoryBase.kcalPerMin * burnScale
        )
    }

    private func buildPlan(
        category: WorkoutCategory,
        index: Int,
        profile: UserFitnessProfile,
        recovery: Double,
        intensity: Double,
        health: HealthSnapshot,
        exercises: [PlannedExercise]
    ) -> WorkoutPlan {
        let base = baseMetrics(for: category, target: profile.target)
        // Heavier bodies burn more for the same work; clamp so estimates stay plausible.
        let weightFactor = max(0.8, min(1.4, profile.weightKG / 70.0))

        let duration = max(15, Int((Double(base.duration) * recovery * intensity).rounded()) - index)
        let calories = max(120, Int((Double(duration) * base.kcalPerMin * weightFactor).rounded()))
        let recoveryScore = Int((recovery * 100).rounded())

        return WorkoutPlan(
            title: title(for: category, target: profile.target),
            category: category,
            duration: duration,
            intensity: profile.activityLevel,
            calories: calories,
            recoveryScore: recoveryScore,
            exercises: exercises,
            rationale: rationale(
                profile: profile,
                category: category,
                recovery: recovery,
                health: health
            )
        )
    }

    private func title(for category: WorkoutCategory, target: FitnessTarget) -> String {
        switch (category, target) {
        case (.shoulder, .gainMuscle): return "Shoulder Hypertrophy"
        case (.shoulder, _):           return "Shoulder Sculpt"
        case (.arms, .gainMuscle):     return "Arms Builder"
        case (.arms, .loseWeight):     return "Arms Tone Burn"
        case (.arms, _):               return "Arms Conditioning"
        case (.legs, .gainMuscle):     return "Leg Strength"
        case (.legs, .loseWeight):     return "Leg Burn Circuit"
        case (.legs, _):               return "Leg Day"
        case (.abs, .gainMuscle):      return "Weighted Core"
        case (.abs, _):                return "Core Cut"
        case (.cardio, .loseWeight):   return "Fat-Burn Cardio"
        case (.cardio, .gainMuscle):   return "Conditioning Finisher"
        case (.cardio, _):             return "Cardio Flow"
        }
    }

    private func legacyExercises(
        for category: WorkoutCategory,
        target: FitnessTarget,
        equipment: String
    ) -> [ExerciseType] {
        let hasWeights = equipment.contains("Dumbbells") || equipment.contains("Full gym")
        switch category {
        case .shoulder:
            return hasWeights
                ? [.shoulderPress, .lateralRaise, .pikePushUp]
                : [.pikePushUp, .pushUp, .pushUp]
        case .arms:
            return hasWeights
                ? [.bicepCurl, .tricepDip, .pushUp]
                : [.pushUp, .tricepDip, .mountainClimber]
        case .legs:
            switch target {
            case .gainMuscle: return [.squat, .lunge, .gluteBridge]
            case .loseWeight: return [.squat, .lunge, .jumpingJack]
            case .maintain:   return [.squat, .gluteBridge, .lunge]
            }
        case .abs:
            return target == .gainMuscle
                ? [.plank, .crunch, .legRaise]
                : [.crunch, .legRaise, .mountainClimber]
        case .cardio:
            return target == .loseWeight
                ? [.jumpingJack, .highKnees, .mountainClimber]
                : [.highKnees, .mountainClimber, .jumpingJack]
        }
    }

    private func rationale(
        profile: UserFitnessProfile,
        category: WorkoutCategory,
        recovery: Double,
        health: HealthSnapshot
    ) -> String {
        let recoveryLabel: String
        switch recovery {
        case 0.8...:        recoveryLabel = "great recovery"
        case 0.55..<0.8:    recoveryLabel = "moderate recovery"
        default:            recoveryLabel = "low recovery"
        }

        let goalLine: String
        switch profile.target {
        case .loseWeight:
            goalLine = "high-burn \(category.rawValue.lowercased()) circuit to push you toward your fat-loss target"
        case .gainMuscle:
            goalLine = "progressive \(category.rawValue.lowercased()) volume sized for hypertrophy"
        case .maintain:
            goalLine = "balanced \(category.rawValue.lowercased()) work to keep your baseline sharp"
        }

        var line = "\(profile.activityLevel.rawValue) plan: \(goalLine). Tuned for \(recoveryLabel) (sleep \(String(format: "%.1f", health.sleepHours))h, HR \(Int(health.heartRate))bpm)."
        if !profile.healthNotes.trimmingCharacters(in: .whitespaces).isEmpty {
            line += " Limit noted: \(profile.healthNotes)."
        }
        if profile.equipment != "No equipment" {
            line += " Uses your \(profile.equipment.lowercased())."
        }
        return line
    }
}

@MainActor
final class HealthKitManager: ObservableObject {
    @Published private(set) var snapshot = HealthSnapshot.empty
    @Published private(set) var syncStatus = "Not connected to Apple Health"
    @Published private(set) var isAuthorized = false

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable else {
            syncStatus = "HealthKit unavailable on this device"
            return
        }

        let readTypes: Set<HKObjectType> = [
            Self.quantityType(.activeEnergyBurned),
            Self.quantityType(.stepCount),
            Self.quantityType(.heartRate),
            Self.quantityType(.appleExerciseTime),
            Self.sleepType(),
            HKObjectType.workoutType()
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            syncStatus = "Synced with Apple Health"
            await refresh()
        } catch {
            syncStatus = "Health permissions need attention"
        }
    }

    func refresh() async {
        guard isAvailable else { return }
        async let active = quantityToday(.activeEnergyBurned, unit: .kilocalorie())
        async let steps = quantityToday(.stepCount, unit: .count())
        async let exercise = quantityToday(.appleExerciseTime, unit: .minute())
        async let heart = averageHeartRate()
        async let sleep = sleepHours()

        do {
            let values = try await (active, steps, exercise, heart, sleep)
            snapshot = HealthSnapshot(
                activeEnergy: values.0,
                steps: values.1,
                heartRate: values.3,
                sleepHours: values.4,
                workoutMinutes: values.2,
                caloriesBurned: values.0 + 136
            )
            syncStatus = "Updated \(Date().formatted(date: .omitted, time: .shortened))"
        } catch {
            syncStatus = "Using cached wellness estimate"
        }
    }

    func apply(agentResponse: AppleHealthAgentA2AResponse) {
        let calories = agentResponse.result.calories
        snapshot = HealthSnapshot(
            activeEnergy: Double(calories.activeEnergyBurned),
            steps: snapshot.steps,
            heartRate: snapshot.heartRate,
            sleepHours: snapshot.sleepHours,
            workoutMinutes: snapshot.workoutMinutes,
            caloriesBurned: Double(calories.totalBurned)
        )
        syncStatus = "\(agentResponse.result.agent.name) mock A2A"
    }

    private func quantityToday(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double {
        let type = Self.quantityType(identifier)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let result = try await descriptor.result(for: store)
        return result?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    private func averageHeartRate() async throws -> Double {
        let type = Self.quantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .hour, value: -12, to: Date()), end: Date())
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .discreteAverage
        )
        let result = try await descriptor.result(for: store)
        return result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
    }

    private func sleepHours() async throws -> Double {
        let type = Self.sleepType()
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 20
        )
        let samples = try await descriptor.result(for: store)
        return samples.reduce(0) { total, sample in
            guard sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue else { return total }
            return total + sample.endDate.timeIntervalSince(sample.startDate) / 3600
        }
    }

    private static func quantityType(_ identifier: HKQuantityTypeIdentifier) -> HKQuantityType {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            preconditionFailure("Missing HealthKit quantity type: \(identifier.rawValue)")
        }
        return type
    }

    private static func sleepType() -> HKCategoryType {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            preconditionFailure("Missing HealthKit sleep analysis type")
        }
        return type
    }
}

@MainActor
final class NotificationManager: ObservableObject {
    @Published private(set) var authorizationStatus = "Not requested"

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? "Reminders enabled" : "Reminders disabled"
        } catch {
            authorizationStatus = "Notification setup failed"
        }
    }

    func scheduleDailyWellnessReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["hydration", "workout", "sleep"])
        schedule(id: "hydration", title: "Hydration pulse", body: "Log water and keep your recovery score climbing.", hour: 11)
        schedule(id: "workout", title: "FawFitt challenge", body: "Your AI workout window is open.", hour: 18)
        schedule(id: "sleep", title: "Recovery protocol", body: "Wind down soon to protect tomorrow's output.", hour: 22)
    }

    private func schedule(id: String, title: String, body: String, hour: Int) {
        var date = DateComponents()
        date.hour = hour
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

final class PersistenceController {
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FawFittModel", managedObjectModel: Self.model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.loadPersistentStores { _, error in
            if let error { assertionFailure("Core Data store failed: \(error.localizedDescription)") }
        }
    }

    static var model: NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entities = [
            entity("CDUserProfile", [
                attribute("name", .stringAttributeType),
                attribute("heightCM", .doubleAttributeType),
                attribute("weightKG", .doubleAttributeType),
                attribute("target", .stringAttributeType),
                attribute("updatedAt", .dateAttributeType)
            ]),
            entity("CDWorkoutHistory", [
                attribute("title", .stringAttributeType),
                attribute("duration", .integer32AttributeType),
                attribute("calories", .integer32AttributeType),
                attribute("completedAt", .dateAttributeType)
            ]),
            entity("CDNutritionLog", [
                attribute("meal", .stringAttributeType),
                attribute("calories", .integer32AttributeType),
                attribute("protein", .integer32AttributeType),
                attribute("loggedAt", .dateAttributeType)
            ]),
            entity("CDAchievement", [
                attribute("title", .stringAttributeType),
                attribute("unlocked", .booleanAttributeType),
                attribute("createdAt", .dateAttributeType)
            ])
        ]
        model.entities = entities
        return model
    }

    private static func entity(_ name: String, _ properties: [NSPropertyDescription]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = properties
        return entity
    }

    private static func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = false
        switch type {
        case .stringAttributeType:
            attribute.defaultValue = ""
        case .doubleAttributeType:
            attribute.defaultValue = 0
        case .integer32AttributeType:
            attribute.defaultValue = 0
        case .booleanAttributeType:
            attribute.defaultValue = false
        case .dateAttributeType:
            attribute.defaultValue = Date()
        default:
            break
        }
        return attribute
    }
}

// MARK: - View Models

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isAuthenticated = UserDefaults.standard.bool(forKey: "FawFitt.isAuthenticated")
    @Published var isOnboarded = UserDefaults.standard.bool(forKey: "FawFitt.isOnboarded")
    @Published var selectedTab: AppTab = .home
    @Published var profile = UserFitnessProfile()
    @Published var weeklyMetrics: [WeeklyMetric] = []
    @Published var workouts: [WorkoutPlan] = []
    @Published var meals: [MealLog] = MockData.meals
    @Published var achievements: [Achievement] = MockData.achievements
    @Published var coachMessages: [CoachMessage] = [
        CoachMessage(isUser: false, text: "Welcome to FawFitt. Your neural training layer is online.")
    ]
    @Published var waterGlasses = 5
    @Published var streak = 12
    @Published var isLoadingCoach = false
    @Published var isAuthenticating = false
    @Published var authStatus = ""
    @Published var appleHealthAgentResponse: AppleHealthAgentA2AResponse?

    let healthKit = HealthKitManager()
    let notifications = NotificationManager()
    private let engine = WorkoutRecommendationEngine()
    private let coachPlugin: AIPlugin = PluginRegistry.shared.plugin(named: "fawfitt.ai.coach.groq") ?? GroqCoachPlugin()

    var fitnessScore: Int {
        min(99, Int((healthKit.snapshot.activeEnergy / 10) + Double(streak * 2) + healthKit.snapshot.sleepHours * 4))
    }

    var calorieProgress: Double {
        min(1, healthKit.snapshot.caloriesBurned / Double(profile.dailyCalorieGoal))
    }

    /// Computes achievements live from streak, HealthKit snapshot, and weekly metrics.
    /// Higher tier = harder to unlock — used by the gamification grid in Progress.
    var gamifiedAchievements: [GamifiedAchievement] {
        let snap = healthKit.snapshot
        let totalWorkouts = Int(weeklyMetrics.reduce(0.0) { $0 + $1.workouts })
        let weeklyBurn = Int(weeklyMetrics.reduce(0.0) { $0 + $1.calories })
        return [
            GamifiedAchievement(title: "First Steps", icon: "figure.run", tier: .bronze,
                                target: 1, currentValue: totalWorkouts, unit: "workout"),
            GamifiedAchievement(title: "Week Warrior", icon: "calendar", tier: .silver,
                                target: 5, currentValue: totalWorkouts, unit: "workouts"),
            GamifiedAchievement(title: "Iron Streak", icon: "flame.fill", tier: .silver,
                                target: 7, currentValue: streak, unit: "days"),
            GamifiedAchievement(title: "Marathon Soul", icon: "crown.fill", tier: .gold,
                                target: 30, currentValue: streak, unit: "days"),
            GamifiedAchievement(title: "10K Steps", icon: "shoeprints.fill", tier: .bronze,
                                target: 10_000, currentValue: Int(snap.steps), unit: "steps"),
            GamifiedAchievement(title: "Calorie Crusher", icon: "bolt.fill", tier: .gold,
                                target: 5_000, currentValue: weeklyBurn, unit: "kcal/wk"),
            GamifiedAchievement(title: "Recovery Pro", icon: "moon.stars.fill", tier: .silver,
                                target: 7, currentValue: Int(snap.sleepHours), unit: "h sleep"),
            GamifiedAchievement(title: "Active Hour", icon: "stopwatch.fill", tier: .bronze,
                                target: 60, currentValue: Int(snap.workoutMinutes), unit: "min")
        ]
    }

    func bootstrap() {
        if FitnessDataStore.hasFirebaseSession() {
            if !isAuthenticated {
                markAuthenticated(animated: false)
            }
            Task {
                await applyRemoteProfileIfAvailable(email: FitnessDataStore.currentEmail())
            }
        }

        rehydrateMetricsFromLogs()
        loadAppleHealthAgentMockResponse()

        Task {
            await refreshRecommendations()
        }
    }

    func completeOnboarding(with registration: RegistrationProfile, email: String) async throws {
        var nextProfile = profile
        registration.applied(to: &nextProfile, email: email)
        profile = nextProfile

        do {
            try await FitnessDataStore.saveOnboardingProfile(email: email, profile: registration)
            authStatus = "Profile synced"
        } catch {
            authStatus = "Profile save failed: \(authMessage(for: error))"
            throw error
        }

        UserDefaults.standard.set(true, forKey: "FawFitt.isOnboarded")
        withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
            isOnboarded = true
        }
        bootstrap()
    }

    func saveProfileChanges() async {
        let email = FitnessDataStore.currentEmail()
        do {
            try await FitnessDataStore.saveProfile(profile, email: email)
            authStatus = "Profile synced"
        } catch {
            authStatus = "Profile save failed: \(authMessage(for: error))"
        }
        await refreshRecommendations()
    }

    func authenticate(email: String, password: String) {
        Task {
            await signIn(email: email, password: password)
        }
    }

    func signIn(email: String, password: String) async {
        let email = FitnessDataStore.normalizedEmail(email)
        guard validate(email: email, password: password) else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            authStatus = try await FitnessDataStore.signIn(email: email, password: password)
            await applyRemoteProfileIfAvailable(email: email)
            markAuthenticated()
        } catch {
            authStatus = "Login failed: \(authMessage(for: error))"
        }
    }

    func register(email: String, password: String) async {
        let email = FitnessDataStore.normalizedEmail(email)
        guard validate(email: email, password: password) else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            authStatus = try await FitnessDataStore.createAccount(email: email, password: password)
            UserDefaults.standard.set(false, forKey: "FawFitt.isOnboarded")
            isOnboarded = false
            markAuthenticated()
        } catch {
            authStatus = "Register failed: \(authMessage(for: error))"
        }
    }

    private func applyRemoteProfileIfAvailable(email: String) async {
        guard let registration = await FitnessDataStore.loadProfile() else { return }
        var nextProfile = profile
        registration.applied(to: &nextProfile, email: email)
        profile = nextProfile
        UserDefaults.standard.set(true, forKey: "FawFitt.isOnboarded")
        isOnboarded = true
    }

    func logCompletedWorkout(plan: WorkoutPlan, durationSeconds: Int, completedSets: Int) async {
        let ratio = plan.totalSets > 0 ? Double(completedSets) / Double(plan.totalSets) : 0
        let estimatedCalories = Int(Double(plan.calories) * max(0, min(1, ratio)))
        await FitnessDataStore.logWorkoutSession(
            planTitle: plan.title,
            category: plan.category.rawValue,
            durationSeconds: durationSeconds,
            completedSets: completedSets,
            totalSets: plan.totalSets,
            calories: estimatedCalories
        )
        applyCompletedWorkoutResult(calories: estimatedCalories)
    }

    /// Read all persisted workout logs from local JSON and aggregate them into daily
    /// WeeklyMetric buckets (last 7 days). Runs at app launch so the Progress chart
    /// survives app restarts.
    private func rehydrateMetricsFromLogs() {
        let logs = FitnessDataStore.loadWorkoutLogs()
        guard !logs.isEmpty else { return }

        let calendar = Calendar.current
        var buckets: [Date: (calories: Double, workouts: Double)] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.completedAt)
            let existing = buckets[day] ?? (0, 0)
            buckets[day] = (existing.calories + Double(log.calories), existing.workouts + 1)
        }
        let metrics = buckets
            .map { (day, data) -> WeeklyMetric in
                let raw = data.calories / 10 + data.workouts * 8
                let score = max(60, min(99, raw))
                return WeeklyMetric(date: day, calories: data.calories, workouts: data.workouts, score: score)
            }
            .sorted { $0.date < $1.date }
            .suffix(7)
        weeklyMetrics = Array(metrics)
        print("[Progress] rehydrated \(weeklyMetrics.count) day(s) from \(logs.count) workout log(s)")
    }

    private func applyCompletedWorkoutResult(calories: Int) {
        let calendar = Calendar.current
        let today = Date()
        var nextMetrics = weeklyMetrics.filter { !calendar.isDateInToday($0.date) }
        let currentToday = weeklyMetrics.first { calendar.isDateInToday($0.date) }
        let nextCalories = (currentToday?.calories ?? 0) + Double(calories)
        let nextWorkouts = (currentToday?.workouts ?? 0) + 1
        let nextScore = min(99, max(currentToday?.score ?? 70, nextCalories / 10 + nextWorkouts * 8))

        nextMetrics.append(
            WeeklyMetric(
                date: today,
                calories: nextCalories,
                workouts: nextWorkouts,
                score: nextScore
            )
        )
        nextMetrics.sort { $0.date < $1.date }
        if nextMetrics.count > 7 {
            nextMetrics = Array(nextMetrics.suffix(7))
        }
        weeklyMetrics = nextMetrics
    }

    func signInWithApplePlaceholder() {
        authStatus = "Signed in locally with Apple placeholder"
        markAuthenticated()
    }

    func signOut() {
        do {
            try FitnessDataStore.signOut()
        } catch {
            authStatus = "Logout failed: \(authMessage(for: error))"
        }

        UserDefaults.standard.set(false, forKey: "FawFitt.isAuthenticated")
        UserDefaults.standard.set(false, forKey: "FawFitt.isOnboarded")
        withAnimation {
            isAuthenticated = false
            isOnboarded = false
        }
        profile = UserFitnessProfile()
        weeklyMetrics = []
        workouts = []
        coachMessages = [CoachMessage(isUser: false, text: "Welcome to FawFitt. Your neural training layer is online.")]
    }

    func refreshRecommendations() async {
        workouts = await engine.recommendations(profile: profile, health: healthKit.snapshot)
    }

    func requestHealthAccess() {
        Task {
            await healthKit.requestAuthorization()
            await refreshRecommendations()
        }
    }

    func requestNotifications() {
        Task {
            await notifications.requestAuthorization()
            notifications.scheduleDailyWellnessReminders()
        }
    }

    func loadAppleHealthAgentMockResponse() {
        Task {
            do {
                let response = try await FawFittAPIService.fetchAppleHealth()
                applyAgentResponse(response, isLive: true)
            } catch {
                // Server offline — fall back to embedded mock JSON for the agent envelope only;
                // do not seed weeklyMetrics from mock samples so Progress reflects real activity.
                if let response = try? AppleHealthAgentParser.decodeMockResponse() {
                    applyAgentResponse(response, isLive: false)
                }
            }
        }
    }

    private func applyAgentResponse(_ response: AppleHealthAgentA2AResponse, isLive: Bool) {
        appleHealthAgentResponse = response
        healthKit.apply(agentResponse: response)
        if isLive {
            weeklyMetrics = response.weeklyMetrics
        }
        profile.dailyCalorieGoal = response.result.calories.dailyGoal
    }

    func meals(on date: Date) -> [MealLog] {
        let cal = Calendar.current
        return meals
            .filter { cal.isDate($0.mealDate, inSameDayAs: date) }
            .sorted { MealType.sortOrder($0.mealType) < MealType.sortOrder($1.mealType) }
    }

    func addMeal(_ meal: MealLog) {
        meals.append(meal)
    }

    func updateMeal(_ meal: MealLog) {
        if let idx = meals.firstIndex(where: { $0.id == meal.id }) {
            meals[idx] = meal
        }
    }

    func deleteMeal(_ meal: MealLog) {
        meals.removeAll { $0.id == meal.id }
    }

    func sendCoachMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        coachMessages.append(CoachMessage(isUser: true, text: text))
        isLoadingCoach = true
        Task {
            let reply = await fetchCoachReply(for: text)
            coachMessages.append(CoachMessage(isUser: false, text: reply))
            isLoadingCoach = false
        }
    }

    private func fetchCoachReply(for text: String) async -> String {
        let context = buildCoachContext()
        do {
            return try await coachPlugin.run(prompt: text, context: context)
        } catch {
            #if DEBUG
            print("[Coach] Groq failed: \(error)")
            #endif
            // Fallback chain: Groq → Mock canned reply so the user always gets a response.
            if let mock = PluginRegistry.shared.plugin(named: "fawfitt.ai.coach.mock"),
               let reply = try? await mock.run(prompt: text, context: context) {
                return reply
            }
            let nsErr = error as NSError
            return "Coach is reconnecting. (\(nsErr.domain) \(nsErr.code))"
        }
    }

    /// Builds a compact summary of who the user is, today's health signal, and recent
    /// workout history. Injected as system context on every coach call so replies are
    /// grounded in real data instead of generic advice.
    private func buildCoachContext() -> String {
        let p = profile
        let snap = healthKit.snapshot
        var lines: [String] = []

        // Identity & body composition
        lines.append("Name: \(p.name.isEmpty ? "Athlete" : p.name)")
        lines.append("Age: \(p.age), Gender: \(p.gender)")
        lines.append("Height: \(Int(p.heightCM))cm, Weight: \(String(format: "%.1f", p.weightKG))kg")

        // Goals & preferences
        lines.append("Goal: \(p.target.rawValue)")
        lines.append("Activity level: \(p.activityLevel.rawValue)")
        lines.append("Training schedule: \(p.workoutDaysPerWeek)x/week, preferred \(p.preferredWorkoutTime)")
        lines.append("Equipment: \(p.equipment)")
        if !p.healthNotes.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("Injuries / limits: \(p.healthNotes)")
        }
        lines.append("Daily calorie goal: \(p.dailyCalorieGoal) kcal")

        // Today's health signal (from HealthKit / Apple Health agent)
        lines.append("--- Today's signal ---")
        lines.append("Active energy: \(Int(snap.activeEnergy)) kcal")
        lines.append("Steps: \(Int(snap.steps))")
        lines.append("Resting HR: \(Int(snap.heartRate)) bpm")
        lines.append("Sleep last night: \(String(format: "%.1f", snap.sleepHours))h")
        lines.append("Workout minutes today: \(Int(snap.workoutMinutes))")

        // Weekly trend (computed from real logs)
        let recent = weeklyMetrics.suffix(7)
        if !recent.isEmpty {
            let totalCal = recent.reduce(0.0) { $0 + $1.calories }
            let workoutDays = recent.filter { $0.workouts > 0 }.count
            let avgScore = recent.reduce(0.0) { $0 + $1.score } / Double(recent.count)
            lines.append("--- Last \(recent.count) days ---")
            lines.append("Workouts logged: \(workoutDays)/\(recent.count) days")
            lines.append("Total active burn: \(Int(totalCal)) kcal")
            lines.append("Avg fitness score: \(Int(avgScore))/100")
        }

        // Recent workout sessions from the local JSON log
        let logs = FitnessDataStore.loadWorkoutLogs().suffix(5)
        if !logs.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            lines.append("--- Recent sessions ---")
            for log in logs.reversed() {
                let completion = log.totalSets > 0 ? "\(log.completedSets)/\(log.totalSets) sets" : "free session"
                lines.append("\(formatter.string(from: log.completedAt)): \(log.planTitle) — \(completion), \(log.calories) kcal, \(log.durationSeconds / 60)min")
            }
        }

        // Current recommendation queue so the coach can reference today's plan
        if let nextPlan = workouts.first {
            lines.append("--- Today's recommended plan ---")
            lines.append("\(nextPlan.title) (\(nextPlan.category.rawValue)) — \(nextPlan.duration)min, \(nextPlan.calories) kcal")
            lines.append("Rationale: \(nextPlan.rationale)")
        }

        return lines.joined(separator: "\n")
    }

    private func validate(email: String, password: String) -> Bool {
        guard email.contains("@") else {
            authStatus = "Enter a valid email address."
            return false
        }

        guard password.count >= 6 else {
            authStatus = "Password must be at least 6 characters."
            return false
        }

        return true
    }

    private func markAuthenticated(animated: Bool = true) {
        UserDefaults.standard.set(true, forKey: "FawFitt.isAuthenticated")
        let update = { [self] in
            self.isAuthenticated = true
        }
        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85), update)
        } else {
            update()
        }
    }

    private func authMessage(for error: Error) -> String {
        let nsError = error as NSError
        #if canImport(FirebaseAuth)
        guard nsError.domain == AuthErrorDomain else {
            return error.localizedDescription
        }

        switch nsError.code {
        case 17008:
            return "Email format is invalid."
        case 17009:
            return "Password is incorrect."
        case 17011:
            return "No Firebase Auth account exists for this email. Register first or check the email."
        case 17007:
            return "This email is already registered. Use Login instead."
        case 17020:
            return "Network error. Check your connection and try again."
        case 17006:
            return "Email/password login is not enabled in Firebase Authentication."
        default:
            return error.localizedDescription
        }
        #else
        return error.localizedDescription
        #endif
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case workout = "Workout"
    case coach = "AI Coach"
    case progress = "Progress"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .workout: return "figure.strengthtraining.traditional"
        case .coach: return "sparkles"
        case .progress: return "chart.xyaxis.line"
        }
    }
}

// MARK: - App Shell

struct ContentView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if !appModel.isAuthenticated {
                AuthView()
                    .transition(.opacity)
            } else if !appModel.isOnboarded {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            appModel.bootstrap()
            withAnimation(.easeInOut(duration: 0.7).delay(1.4)) {
                showSplash = false
            }
        }
    }
}

struct AuthView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer(minLength: 36)
                    brandMark
                    headline
                    accountCard

                    if !appModel.authStatus.isEmpty {
                        Label(appModel.authStatus, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(FawFittTheme.mutedText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    switchModeButton
                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }

    private var brandMark: some View {
        ZStack {
            Circle()
                .fill(FawFittTheme.neon.opacity(0.15))
            Circle()
                .stroke(FawFittTheme.glassStroke, lineWidth: 1)
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(FawFittTheme.neon)
        }
        .frame(width: 84, height: 84)
        .accessibilityHidden(true)
    }

    private var headline: some View {
        VStack(spacing: 8) {
            Text(isRegistering ? "Create your account" : "Welcome back")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(isRegistering
                 ? "We'll build your personalized plan in the next step."
                 : "Sign in to continue your training.")
                .font(.subheadline)
                .foregroundStyle(FawFittTheme.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var switchModeButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                isRegistering.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(isRegistering ? "Already have an account?" : "New here?")
                    .foregroundStyle(FawFittTheme.mutedText)
                Text(isRegistering ? "Log in" : "Create account")
                    .foregroundStyle(FawFittTheme.neon)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
    }

    private var accountCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                AuthTextField(title: "Email", text: $email, keyboard: .emailAddress, contentType: .emailAddress)
                SecureField("Password", text: $password)
                    .textContentType(isRegistering ? .newPassword : .password)
                    .padding(14)
                    .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                NeonButton(
                    title: appModel.isAuthenticating ? "Please wait" : (isRegistering ? "Create account" : "Log in"),
                    systemImage: isRegistering ? "person.badge.plus" : "arrow.right"
                ) {
                    guard !appModel.isAuthenticating else { return }
                    Task {
                        if isRegistering {
                            await appModel.register(email: email, password: password)
                        } else {
                            await appModel.signIn(email: email, password: password)
                        }
                    }
                }

                dividerWithLabel

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    if case .success = result {
                        appModel.signInWithApplePlaceholder()
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(Capsule())
                .accessibilityLabel("Sign in with Apple")
            }
        }
    }

    private var dividerWithLabel: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(FawFittTheme.glassStroke)
                .frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundStyle(FawFittTheme.mutedText)
            Rectangle()
                .fill(FawFittTheme.glassStroke)
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    let contentType: UITextContentType?

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled(keyboard == .emailAddress)
            .padding(14)
            .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(FawFittTheme.glassStroke, lineWidth: 22)
                        .frame(width: 146, height: 146)
                        .scaleEffect(pulse ? 1.18 : 0.82)
                        .opacity(pulse ? 0.08 : 0.42)
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(FawFittTheme.neon)
                        .accessibilityHidden(true)
                }
                Text("AI Fitness Coach")
                    .font(.headline)
                    .foregroundStyle(FawFittTheme.mutedText)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var stepIndex = 0
    @State private var registration = RegistrationProfile()
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, notes }

    private enum Step: Int, CaseIterable {
        case name, gender, age, height, weight, goal, activity, days, time, equipment, notes, summary
    }

    private let genders = ["Prefer not to say", "Male", "Female"]
    private let workoutTimes = ["Morning", "Afternoon", "Evening", "Flexible"]
    private let equipmentOptions = ["No equipment", "Dumbbells", "Resistance bands", "Full gym"]

    private var step: Step { Step(rawValue: stepIndex) ?? .name }
    private var progress: Double {
        Double(stepIndex + 1) / Double(Step.allCases.count)
    }
    private var isLastStep: Bool { step == .summary }
    private var canAdvance: Bool {
        switch step {
        case .name:   return !registration.name.trimmingCharacters(in: .whitespaces).isEmpty
        default:      return true
        }
    }

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 18) {
                progressHeader
                stepBody
                Spacer(minLength: 0)
                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.warning)
                        .padding(10)
                        .background(FawFittTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .fixedSize(horizontal: false, vertical: true)
                }
                actionRow
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    if stepIndex > 0 {
                        focusedField = nil
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            stepIndex -= 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.bold())
                        .foregroundStyle(stepIndex > 0 ? .white : .clear)
                        .frame(width: 38, height: 38)
                        .background(FawFittTheme.glass, in: Circle())
                        .overlay(Circle().stroke(FawFittTheme.glassStroke, lineWidth: 1))
                }
                .disabled(stepIndex == 0)
                .accessibilityLabel("Previous step")

                Spacer()
                Text("\(stepIndex + 1) of \(Step.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FawFittTheme.mutedText)
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }
            ProgressView(value: progress)
                .tint(FawFittTheme.neon)
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                stepHeader
                stepInput
                    .id(stepIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .padding(.top, 12)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: stepIndex)
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stepEyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(FawFittTheme.neon)
                .textCase(.uppercase)
                .tracking(1.5)
            Text(stepTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            if !stepSubtitle.isEmpty {
                Text(stepSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(FawFittTheme.mutedText)
            }
        }
    }

    private var stepEyebrow: String {
        switch step {
        case .name, .gender, .age, .height, .weight: return "About you"
        case .goal, .activity:                       return "Your goal"
        case .days, .time, .equipment, .notes:       return "Training preferences"
        case .summary:                               return "All set"
        }
    }

    private var stepTitle: String {
        switch step {
        case .name:      return "What should we call you?"
        case .gender:    return "How do you identify?"
        case .age:       return "How old are you?"
        case .height:    return "What's your height?"
        case .weight:    return "What's your current weight?"
        case .goal:      return "What's your main goal?"
        case .activity:  return "How active are you right now?"
        case .days:      return "How many days a week can you train?"
        case .time:      return "When do you prefer to work out?"
        case .equipment: return "What equipment do you have?"
        case .notes:     return "Any injuries or limits we should know?"
        case .summary:   return "Your plan is ready"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .name:      return "Used to personalize your coaching."
        case .gender:    return "Tunes calorie estimates."
        case .age:       return "Drives intensity and recovery targets."
        case .height:    return "We compute it together with weight."
        case .weight:    return "Used for calorie & load estimates."
        case .goal:      return "Your goal shapes every workout we build."
        case .activity:  return "Your starting fitness sets initial volume."
        case .days:      return "We'll build a rotation that fits your week."
        case .time:      return "Reminders will respect this window."
        case .equipment: return "Exercises will match what you have."
        case .notes:     return "Optional — we'll work around it."
        case .summary:   return "Review and launch your training."
        }
    }

    @ViewBuilder
    private var stepInput: some View {
        switch step {
        case .name:
            GlassCard {
                TextField("First name", text: $registration.name)
                    .focused($focusedField, equals: .name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .font(.title3)
                    .padding(14)
                    .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onAppear { focusedField = .name }
            }
        case .gender:
            optionList(options: genders, selection: $registration.gender)
        case .age:
            stepperCard(
                value: Binding(get: { Double(registration.age) },
                               set: { registration.age = Int($0) }),
                display: "\(registration.age) years",
                range: 13...90, step: 1
            )
        case .height:
            stepperCard(
                value: $registration.heightCM,
                display: "\(Int(registration.heightCM)) cm",
                range: 120...220, step: 1
            )
        case .weight:
            stepperCard(
                value: $registration.weightKG,
                display: String(format: "%.1f kg", registration.weightKG),
                range: 35...200, step: 0.5
            )
        case .goal:
            optionList(
                options: FitnessTarget.allCases.map(\.rawValue),
                selection: Binding(
                    get: { registration.target.rawValue },
                    set: { raw in
                        if let v = FitnessTarget.allCases.first(where: { $0.rawValue == raw }) {
                            registration.target = v
                        }
                    }
                ),
                icons: ["flame", "dumbbell", "leaf"]
            )
        case .activity:
            optionList(
                options: ActivityLevel.allCases.map(\.rawValue),
                selection: Binding(
                    get: { registration.activityLevel.rawValue },
                    set: { raw in
                        if let v = ActivityLevel.allCases.first(where: { $0.rawValue == raw }) {
                            registration.activityLevel = v
                        }
                    }
                ),
                icons: ["figure.walk", "figure.run", "bolt.fill"]
            )
        case .days:
            stepperCard(
                value: Binding(get: { Double(registration.workoutDaysPerWeek) },
                               set: { registration.workoutDaysPerWeek = Int($0) }),
                display: "\(registration.workoutDaysPerWeek)x / week",
                range: 1...7, step: 1
            )
        case .time:
            optionList(
                options: workoutTimes,
                selection: $registration.preferredWorkoutTime,
                icons: ["sunrise", "sun.max", "moon.stars", "calendar"]
            )
        case .equipment:
            optionList(
                options: equipmentOptions,
                selection: $registration.equipment,
                icons: ["figure.mind.and.body", "dumbbell", "bandage", "building.2"]
            )
        case .notes:
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("e.g. knee pain, lower-back sensitivity", text: $registration.healthNotes, axis: .vertical)
                        .focused($focusedField, equals: .notes)
                        .lineLimit(3, reservesSpace: true)
                        .padding(14)
                        .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("Leave blank if none.")
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                }
            }
        case .summary:
            summaryCard
        }
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                summaryRow(icon: "person.fill", label: "Name", value: registration.name)
                summaryRow(icon: "target", label: "Goal", value: registration.target.rawValue)
                summaryRow(icon: "bolt.fill", label: "Activity", value: registration.activityLevel.rawValue)
                summaryRow(icon: "calendar", label: "Frequency", value: "\(registration.workoutDaysPerWeek)x / week")
                summaryRow(icon: "dumbbell", label: "Equipment", value: registration.equipment)
                Divider().background(FawFittTheme.glassStroke)
                HStack {
                    Image(systemName: "flame.fill").foregroundStyle(FawFittTheme.neon)
                    Text("Daily calorie target")
                        .font(.subheadline)
                    Spacer()
                    Text("\(registration.estimatedDailyCalorieGoal) kcal")
                        .font(.subheadline.bold())
                        .foregroundStyle(FawFittTheme.neon)
                }
            }
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(FawFittTheme.neon)
            Text(label)
                .foregroundStyle(FawFittTheme.mutedText)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .font(.subheadline)
    }

    private var actionRow: some View {
        NeonButton(
            title: actionTitle,
            systemImage: isLastStep ? "checkmark" : "arrow.right"
        ) {
            handleAdvance()
        }
        .opacity(canAdvance ? 1 : 0.55)
        .disabled(!canAdvance || isSaving)
    }

    private var actionTitle: String {
        if isSaving { return "Saving…" }
        return isLastStep ? "Start training" : "Continue"
    }

    private func handleAdvance() {
        focusedField = nil
        if isLastStep {
            guard !isSaving else { return }
            isSaving = true
            saveError = nil
            Task {
                do {
                    try await appModel.completeOnboarding(
                        with: registration,
                        email: FitnessDataStore.currentEmail()
                    )
                } catch {
                    saveError = appModel.authStatus.isEmpty
                        ? "Profile save failed: \(error.localizedDescription)"
                        : appModel.authStatus
                }
                isSaving = false
            }
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            stepIndex = min(stepIndex + 1, Step.allCases.count - 1)
        }
    }

    @ViewBuilder
    private func optionList(
        options: [String],
        selection: Binding<String>,
        icons: [String]? = nil
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                OnboardingOptionRow(
                    title: option,
                    icon: icons?[safe: idx],
                    isSelected: selection.wrappedValue == option
                ) {
                    selection.wrappedValue = option
                }
            }
        }
    }

    private func stepperCard(
        value: Binding<Double>,
        display: String,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        GlassCard {
            VStack(spacing: 18) {
                Text(display)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(FawFittTheme.neon)
                HStack(spacing: 18) {
                    stepperButton(systemImage: "minus") {
                        let next = max(range.lowerBound, value.wrappedValue - step)
                        value.wrappedValue = next
                    }
                    Slider(value: value, in: range, step: step)
                        .tint(FawFittTheme.neon)
                    stepperButton(systemImage: "plus") {
                        let next = min(range.upperBound, value.wrappedValue + step)
                        value.wrappedValue = next
                    }
                }
            }
        }
    }

    private func stepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.bold())
                .frame(width: 42, height: 42)
                .background(FawFittTheme.glass, in: Circle())
                .overlay(Circle().stroke(FawFittTheme.glassStroke, lineWidth: 1))
                .foregroundStyle(.white)
        }
    }
}

private struct OnboardingOptionRow: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.headline)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(isSelected ? .black : FawFittTheme.neon)
                        .background(
                            (isSelected ? FawFittTheme.neon : FawFittTheme.neon.opacity(0.15)),
                            in: Circle()
                        )
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? FawFittTheme.neon : FawFittTheme.mutedText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? FawFittTheme.neon.opacity(0.12) : FawFittTheme.glass)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? FawFittTheme.neon.opacity(0.7) : FawFittTheme.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appModel.selectedTab {
                case .home: HomeDashboardView()
                case .workout: WorkoutView()
                case .coach: AICoachView()
                case .progress: ProgressAnalyticsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selectedTab: $appModel.selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Screens

struct HomeDashboardView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var isRefreshing = false
    @State private var showProfile = false
    @State private var showNutritionPlanner = false
    @State private var activePlan: WorkoutPlan?

    private var dailyGoal: Int { appModel.profile.dailyCalorieGoal }
    private var profileInitial: String {
        String(appModel.profile.name.prefix(1)).uppercased()
    }

    private var todayMeals: [MealLog] { appModel.meals(on: Date()) }
    private var plannedCalories: Int { todayMeals.reduce(0) { $0 + $1.calories } }
    private var nutritionProgress: Double {
        dailyGoal > 0 ? min(1.0, Double(plannedCalories) / Double(dailyGoal)) : 0
    }
    private var nutritionPercent: Int { Int(nutritionProgress * 100) }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        nutritionHeroCard
                        featuredWorkoutCard
                        dailyProgramSection
                        recommendationCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 108)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await appModel.healthKit.refresh()
                await appModel.refreshRecommendations()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showNutritionPlanner) {
                NutritionPlannerView()
                    .environmentObject(appModel)
            }
            .sheet(item: $activePlan) { plan in
                WorkoutDetailSheet(plan: plan)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button {
                showProfile = true
            } label: {
                ZStack {
                    Circle()
                        .fill(FawFittTheme.glass)
                    Text(profileInitial.isEmpty ? "F" : profileInitial)
                        .font(.headline.bold())
                        .foregroundStyle(FawFittTheme.neon)
                }
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(FawFittTheme.glassStroke, lineWidth: 1))
            }
            .accessibilityLabel("Open profile")

            VStack(alignment: .leading, spacing: 2) {
                Text("Hi, \(appModel.profile.name)")
                    .font(.title2.bold())
                    .lineLimit(1)
                Text("Welcome back")
                    .font(.subheadline)
                    .foregroundStyle(FawFittTheme.mutedText)
            }
            Spacer()
            Button {
                guard !isRefreshing else { return }
                isRefreshing = true
                Task {
                    await appModel.healthKit.refresh()
                    await appModel.refreshRecommendations()
                    isRefreshing = false
                }
            } label: {
                Group {
                    if isRefreshing {
                        ProgressView()
                            .tint(FawFittTheme.neon)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FawFittTheme.neon)
                    }
                }
                .frame(width: 40, height: 40)
                .background(FawFittTheme.neon.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Refresh health data")
        }
    }

    private var nutritionHeroCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(FawFittTheme.glassStroke.opacity(0.7), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: nutritionProgress)
                            .stroke(FawFittTheme.neon, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: nutritionProgress)
                            .shadow(color: .black.opacity(0.2), radius: 8)
                        VStack(spacing: 0) {
                            Text("\(nutritionPercent)%")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(FawFittTheme.neon)
                            Text("of goal")
                                .font(.system(size: 10))
                                .foregroundStyle(FawFittTheme.mutedText)
                        }
                    }
                    .frame(width: 110, height: 110)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's nutrition")
                                .font(.caption)
                                .foregroundStyle(FawFittTheme.mutedText)
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(plannedCalories)")
                                    .font(.system(size: 40, weight: .black))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.4), value: plannedCalories)
                                Text("kcal")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FawFittTheme.mutedText)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(todayMeals.count) meal\(todayMeals.count == 1 ? "" : "s") planned")
                                .font(.caption)
                                .foregroundStyle(FawFittTheme.mutedText)
                            Text("Goal \(dailyGoal) kcal")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    showNutritionPlanner = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                        Text("Manage nutrition")
                            .font(.subheadline.bold())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(FawFittTheme.neon, in: Capsule())
                }
                .accessibilityLabel("Open nutrition planner")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's nutrition: \(plannedCalories) of \(dailyGoal) daily goal. \(nutritionPercent) percent complete.")
    }

private var recommendationCard: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                appModel.selectedTab = .workout
            }
        } label: {
            GlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(FawFittTheme.glass)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 20))
                            .foregroundStyle(FawFittTheme.neon)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Workouts for you")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text(
                            appModel.workouts.first.map { "\($0.title) · \($0.duration) min" }
                                ?? "Tap to see your plan"
                        )
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                        .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(FawFittTheme.mutedText)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Workouts for you. " +
            (appModel.workouts.first.map { "\($0.title), \($0.duration) minutes" } ?? "Tap to see your plan")
        )
        .accessibilityHint("Opens workout tab")
    }

    private var featuredWorkoutCard: some View {
        Button {
            if let top = appModel.workouts.first {
                activePlan = top
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    appModel.selectedTab = .workout
                }
            }
        } label: {
            PhotoFeatureCard(
                imageName: appModel.workouts.first?.category.artworkAsset ?? "WorkoutTrend",
                eyebrow: "Trending",
                title: appModel.workouts.first?.title ?? "Full Body Strength",
                detail: "Recovery-aware session picked for today",
                badge: "#1"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trending workout: \(appModel.workouts.first?.title ?? "Full Body Strength").")
        .accessibilityHint("Opens workout detail")
    }

    // The two quick tiles below the trending #1 — the next picks in today's rotation.
    // Falls back to the first picks if there aren't enough beyond #1, so the row
    // always renders a consistent two-tile layout.
    private var dailyProgram: [WorkoutPlan] {
        let rest = Array(appModel.workouts.dropFirst())
        return rest.count >= 2 ? Array(rest.prefix(2)) : Array(appModel.workouts.prefix(2))
    }

    private var dailyProgramSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Program")
                .font(.title3.bold())
            if dailyProgram.isEmpty {
                Text("Your program appears once recommendations load.")
                    .font(.caption)
                    .foregroundStyle(FawFittTheme.mutedText)
            } else {
                HStack(spacing: 12) {
                    ForEach(dailyProgram) { plan in
                        Button {
                            activePlan = plan
                        } label: {
                            PhotoProgramTile(
                                imageName: plan.category.artworkAsset,
                                title: plan.title,
                                subtitle: "\(plan.duration) min"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens workout detail")
                    }
                }
            }
        }
    }
}

struct WorkoutView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var activePlan: WorkoutPlan?

    private var matrixSubtitle: String {
        let goal = appModel.profile.target.rawValue.lowercased()
        let level = appModel.profile.activityLevel.rawValue.lowercased()
        let days = appModel.profile.workoutDaysPerWeek
        return "\(days)x/week \(level) plan for your \(goal) goal, tuned to today's recovery."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        Text("Workout Matrix")
                            .font(.system(size: 34, weight: .bold))
                        Text(matrixSubtitle)
                            .foregroundStyle(FawFittTheme.mutedText)
                        ForEach(appModel.workouts) { workout in
                            Button {
                                activePlan = workout
                            } label: {
                                WorkoutPlanCard(plan: workout)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Open workout detail")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 108)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activePlan) { plan in
                WorkoutDetailSheet(plan: plan)
            }
        }
    }
}

struct AICoachView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var text = ""

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("AI Coach")
                            .font(.system(size: 34, weight: .bold))
                        Text("Futuristic guidance, mock-backed and API-ready.")
                            .foregroundStyle(FawFittTheme.mutedText)
                    }
                    Spacer()
                    Image(systemName: "brain.head.profile")
                        .font(.title)
                        .foregroundStyle(FawFittTheme.neon)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(appModel.coachMessages) { message in
                                CoachBubble(message: message)
                                    .id(message.id)
                            }
                            if appModel.isLoadingCoach {
                                HStack {
                                    ProgressView().tint(FawFittTheme.neon)
                                    Text("Coach analyzing").foregroundStyle(FawFittTheme.mutedText)
                                    Spacer()
                                }
                                .padding(.horizontal, 18)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .onChange(of: appModel.coachMessages.count) { _ in
                        if let last = appModel.coachMessages.last?.id {
                            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("Ask about training, recovery, nutrition", text: $text)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(.ultraThinMaterial, in: Capsule())
                    Button {
                        appModel.sendCoachMessage(text)
                        text = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(width: 48, height: 48)
                            .background(FawFittTheme.neon, in: Circle())
                    }
                    .accessibilityLabel("Send coach message")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
        }
    }
}

struct ProgressAnalyticsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    private var metrics: [WeeklyMetric] { appModel.weeklyMetrics }

    private var totalBurn: Double {
        metrics.reduce(0) { $0 + $1.calories }
    }

    private var workoutDays: Int {
        metrics.filter { $0.workouts > 0 }.count
    }

    private var goalRatePercent: Int {
        let goal = max(1, appModel.profile.dailyCalorieGoal)
        let dailyTarget = Double(goal) * 0.25 // active burn target ~ 25% of daily intake goal
        guard !metrics.isEmpty else { return 0 }
        let hitCount = metrics.filter { $0.calories >= dailyTarget }.count
        return Int((Double(hitCount) / Double(metrics.count)) * 100)
    }

    private var recoveryLabel: String {
        let snapshot = appModel.healthKit.snapshot
        let sleep = snapshot.sleepHours
        let hr = snapshot.heartRate
        // No data yet — show neutral placeholder instead of misleading "Low".
        if sleep <= 0 && hr <= 0 { return "—" }
        switch (sleep, hr) {
        case let (s, h) where s >= 7.5 && h > 0 && h < 70: return "Excellent"
        case let (s, h) where s >= 6.5 && (h <= 0 || h < 78): return "Good"
        case let (s, _) where s >= 5.5: return "Fair"
        default: return "Low"
        }
    }

    private var burnDisplay: String {
        switch totalBurn {
        case 10_000...:
            return String(format: "%.1fk", totalBurn / 1000)
        default:
            return "\(Int(totalBurn))"
        }
    }

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("Progress")
                        .font(.system(size: 34, weight: .bold))
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Fitness Improvement Trend")
                                .font(.headline)
                            Text("Daily score 0–100, blending active calories, steps, sleep, and workouts. Higher line = stronger trend.")
                                .font(.caption)
                                .foregroundStyle(FawFittTheme.mutedText)
                                .fixedSize(horizontal: false, vertical: true)
                            if metrics.isEmpty {
                                emptyTrend
                            } else {
                                Chart(metrics) { metric in
                                    AreaMark(
                                        x: .value("Day", metric.date),
                                        y: .value("Score", metric.score)
                                    )
                                    .foregroundStyle(FawFittTheme.neon.opacity(0.25))
                                    LineMark(
                                        x: .value("Day", metric.date),
                                        y: .value("Score", metric.score)
                                    )
                                    .foregroundStyle(FawFittTheme.neon)
                                    .symbol(Circle())
                                }
                                .frame(height: 230)
                            }
                        }
                    }
                    todaySignalCard
                    Text("This week")
                        .font(.title3.bold())
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Goal Rate", value: "\(goalRatePercent)%", icon: "target", color: FawFittTheme.neon)
                        StatCard(title: "Weekly Burn", value: burnDisplay, icon: "flame", color: FawFittTheme.warning)
                        StatCard(title: "Consistency", value: "\(workoutDays)/\(max(metrics.count, 1))", icon: "calendar", color: FawFittTheme.cyan)
                        StatCard(title: "Recovery", value: recoveryLabel, icon: "bed.double", color: FawFittTheme.violet)
                    }
                    achievementsSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 108)
            }
        }
    }

    private var todaySignalCard: some View {
        let snap = appModel.healthKit.snapshot
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today's signal").font(.headline)
                    Spacer()
                    Text("From Apple Health")
                        .font(.caption2)
                        .foregroundStyle(FawFittTheme.mutedText)
                }
                HStack(spacing: 10) {
                    miniTile(icon: "flame.fill", value: "\(Int(snap.activeEnergy))", unit: "kcal", color: FawFittTheme.warning)
                    miniTile(icon: "figure.walk", value: stepDisplay(snap.steps), unit: "steps", color: FawFittTheme.neon)
                    miniTile(icon: "bed.double.fill", value: String(format: "%.1f", snap.sleepHours), unit: "h sleep", color: FawFittTheme.violet)
                    miniTile(icon: "stopwatch.fill", value: "\(Int(snap.workoutMinutes))", unit: "min", color: FawFittTheme.cyan)
                }
            }
        }
    }

    private func miniTile(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(FawFittTheme.mutedText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stepDisplay(_ steps: Double) -> String {
        if steps >= 10_000 { return String(format: "%.1fk", steps / 1000) }
        return "\(Int(steps))"
    }

    private var emptyTrend: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 28))
                .foregroundStyle(FawFittTheme.mutedText)
            Text("Complete your first workout to see your trend.")
                .font(.caption)
                .foregroundStyle(FawFittTheme.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder private var achievementsSection: some View {
        let all = appModel.gamifiedAchievements
        let unlockedCount = all.filter(\.isUnlocked).count
        let nextUp = all.first { !$0.isUnlocked && $0.progress > 0 }
            ?? all.first { !$0.isUnlocked }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Achievements").font(.title3.bold())
                Spacer()
                Text("\(unlockedCount)/\(all.count) unlocked")
                    .font(.caption.bold())
                    .foregroundStyle(FawFittTheme.neon)
            }
            if let nextUp {
                nextMilestoneCard(nextUp)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(all) { achievement in
                    AchievementGameCard(achievement: achievement)
                }
            }
        }
    }

    private func nextMilestoneCard(_ achievement: GamifiedAchievement) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(achievement.tier.color.opacity(0.2))
                    Image(systemName: achievement.icon)
                        .font(.title2)
                        .foregroundStyle(achievement.tier.color)
                }
                .frame(width: 54, height: 54)
                .overlay(Circle().stroke(achievement.tier.color.opacity(0.5), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Next up").font(.caption2.bold())
                            .foregroundStyle(FawFittTheme.mutedText)
                        Text(achievement.tier.rawValue.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(achievement.tier.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(achievement.tier.color.opacity(0.18), in: Capsule())
                    }
                    Text(achievement.title).font(.headline)
                    Text("\(achievement.remaining) \(achievement.unit) to go")
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                    ProgressView(value: achievement.progress)
                        .tint(achievement.tier.color)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next achievement \(achievement.title), \(achievement.remaining) \(achievement.unit) remaining")
    }
}

struct AchievementGameCard: View {
    let achievement: GamifiedAchievement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                tierBadge
                Spacer()
                if achievement.isUnlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(achievement.tier.color)
                }
            }
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: achievement.isUnlocked
                                ? [achievement.tier.color, achievement.tier.color.opacity(0.4)]
                                : [FawFittTheme.glass, FawFittTheme.glass],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 50
                        )
                    )
                Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? .black : FawFittTheme.mutedText)
            }
            .frame(width: 56, height: 56)
            .overlay(
                Circle().stroke(
                    achievement.isUnlocked ? achievement.tier.color.opacity(0.6) : FawFittTheme.glassStroke,
                    lineWidth: 1
                )
            )
            .shadow(
                color: achievement.isUnlocked ? achievement.tier.color.opacity(0.5) : .clear,
                radius: achievement.isUnlocked ? 12 : 0
            )
            .frame(maxWidth: .infinity, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundStyle(achievement.isUnlocked ? .white : FawFittTheme.mutedText)
                Text("\(formattedValue(achievement.currentValue))/\(formattedValue(achievement.target)) \(achievement.unit)")
                    .font(.caption2)
                    .foregroundStyle(FawFittTheme.mutedText)
                    .lineLimit(1)
                ProgressView(value: achievement.progress)
                    .tint(achievement.tier.color)
                    .scaleEffect(x: 1, y: 0.8, anchor: .center)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    achievement.isUnlocked ? achievement.tier.color.opacity(0.4) : FawFittTheme.glassStroke,
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(achievement.title), \(achievement.tier.rawValue) tier, \(achievement.isUnlocked ? "unlocked" : "locked"), progress \(Int(achievement.progress * 100)) percent"
        )
    }

    private var tierBadge: some View {
        Text(achievement.tier.rawValue.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(achievement.tier.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(achievement.tier.color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(achievement.tier.color.opacity(0.3), lineWidth: 0.5))
    }

    private func formattedValue(_ v: Int) -> String {
        if v >= 1000 { return String(format: "%.1fk", Double(v) / 1000) }
        return "\(v)"
    }
}

// MARK: - Nutrition Planner

struct NutritionPlannerView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var editingMeal: MealLog?
    @State private var isCreating = false

    private var days: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var mealsForDay: [MealLog] { appModel.meals(on: selectedDate) }

    private var totalCalories: Int { mealsForDay.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Int { mealsForDay.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Int { mealsForDay.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Int { mealsForDay.reduce(0) { $0 + $1.fat } }

    var body: some View {
        NavigationStack {
            ZStack {
                FawFittTheme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        daySelector
                        summaryCard
                        actionRow
                        mealList
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Nutrition planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $editingMeal) { meal in
                MealEditorSheet(mode: .edit(meal), defaultDate: selectedDate)
                    .environmentObject(appModel)
            }
            .sheet(isPresented: $isCreating) {
                MealEditorSheet(mode: .create, defaultDate: selectedDate)
                    .environmentObject(appModel)
            }
        }
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    dayPill(day)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func dayPill(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(day)
        let weekday = day.formatted(.dateTime.weekday(.abbreviated))
        let dayNum = cal.component(.day, from: day)
        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 4) {
                Text(isToday ? "Today" : weekday)
                    .font(.caption2.bold())
                Text("\(dayNum)")
                    .font(.headline)
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(width: 60, height: 56)
            .background(
                isSelected ? FawFittTheme.neon : FawFittTheme.glass,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.clear : FawFittTheme.glassStroke, lineWidth: 1)
            )
        }
    }

    private var summaryCard: some View {
        let goal = max(1, appModel.profile.dailyCalorieGoal)
        let ratio = min(1, Double(totalCalories) / Double(goal))
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(totalCalories) kcal")
                        .font(.title2.bold())
                        .foregroundStyle(FawFittTheme.neon)
                    Text("/ \(goal) goal")
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                    Spacer()
                    Text("\(mealsForDay.count) meal\(mealsForDay.count == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .foregroundStyle(FawFittTheme.mutedText)
                }
                ProgressView(value: ratio).tint(FawFittTheme.neon)
                HStack(spacing: 14) {
                    macroLabel("Protein", "\(totalProtein)g", FawFittTheme.cyan)
                    macroLabel("Carbs", "\(totalCarbs)g", FawFittTheme.warning)
                    macroLabel("Fat", "\(totalFat)g", FawFittTheme.violet)
                }
            }
        }
    }

    private func macroLabel(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(FawFittTheme.mutedText)
            Text(value).font(.subheadline.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionRow: some View {
        Button {
            isCreating = true
        } label: {
            Label("Add meal", systemImage: "plus")
                .font(.subheadline.bold())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FawFittTheme.neon, in: Capsule())
        }
        .accessibilityLabel("Add new meal")
    }

    @ViewBuilder private var mealList: some View {
        if mealsForDay.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 32))
                    .foregroundStyle(FawFittTheme.mutedText)
                Text("No meals planned for this day.")
                    .font(.subheadline)
                    .foregroundStyle(FawFittTheme.mutedText)
                Text("Tap Add meal to plan your day.")
                    .font(.caption)
                    .foregroundStyle(FawFittTheme.mutedText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ForEach(mealsForDay) { meal in
                Button {
                    editingMeal = meal
                } label: {
                    MealRow(meal: meal)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        appModel.deleteMeal(meal)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        editingMeal = meal
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        appModel.deleteMeal(meal)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

struct MealEditorSheet: View {
    enum Mode {
        case create
        case edit(MealLog)
    }

    let mode: Mode
    let defaultDate: Date

    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var mealType: String = MealType.breakfast.rawValue
    @State private var calories: Int = 0
    @State private var protein: Int = 0
    @State private var carbs: Int = 0
    @State private var fat: Int = 0
    @State private var date: Date = Date()
    @State private var photoItem: PhotosPickerItem?
    @State private var detectionState: DetectionState = .idle
    @State private var lastPrediction: FoodPrediction?
    @StateObject private var classifier = FoodCalorieClassifier()
    private var existingId: UUID?

    private enum DetectionState: Equatable {
        case idle
        case classifying
        case result(FoodPrediction)
        case failed(String)
    }

    init(mode: Mode, defaultDate: Date) {
        self.mode = mode
        self.defaultDate = defaultDate
        if case let .edit(meal) = mode {
            _name = State(initialValue: meal.name)
            _mealType = State(initialValue: meal.mealType)
            _calories = State(initialValue: meal.calories)
            _protein = State(initialValue: meal.protein)
            _carbs = State(initialValue: meal.carbs)
            _fat = State(initialValue: meal.fat)
            _date = State(initialValue: meal.mealDate)
            existingId = meal.id
        } else {
            _date = State(initialValue: defaultDate)
            existingId = nil
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && calories >= 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FawFittTheme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        detectionCard
                        nameCard
                        typeCard
                        dateCard
                        macroDistributionBar
                        macroGrid
                        if isEditing, case let .edit(meal) = mode {
                            Button(role: .destructive) {
                                appModel.deleteMeal(meal)
                                dismiss()
                            } label: {
                                Label("Delete meal", systemImage: "trash")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(FawFittTheme.warning)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(FawFittTheme.glass, in: Capsule())
                                    .overlay(Capsule().stroke(FawFittTheme.warning.opacity(0.4), lineWidth: 1))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(isEditing ? "Edit meal" : "New meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { newItem in
                handlePhotoSelection(newItem)
            }
        }
    }

    private var detectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    Image(systemName: detectionStateIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(FawFittTheme.neon, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan food with camera")
                            .font(.subheadline.bold())
                        Text(detectionStateSubtitle)
                            .font(.caption)
                            .foregroundStyle(FawFittTheme.mutedText)
                            .lineLimit(2)
                    }
                    Spacer()
                    if case .classifying = detectionState {
                        ProgressView().tint(FawFittTheme.neon)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(FawFittTheme.mutedText)
                    }
                }
                .padding(14)
                .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FawFittTheme.glassStroke, lineWidth: 1)
                )
            }
            .disabled({ if case .classifying = detectionState { return true } else { return false } }())
            .accessibilityLabel("Scan food image to autofill nutrition")

            if case let .result(prediction) = detectionState {
                detectionResultRow(prediction)
            }
            if case let .failed(message) = detectionState {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(FawFittTheme.warning)
                    .padding(.leading, 4)
            }
            if !classifier.usingCoreML {
                Text("Model not bundled yet — drop FoodClassifier.mlmodel into the app target after training in Create ML.")
                    .font(.caption2)
                    .foregroundStyle(FawFittTheme.mutedText)
                    .padding(.leading, 4)
            }
        }
    }

    private var detectionStateIcon: String {
        switch detectionState {
        case .idle, .failed: return "camera.viewfinder"
        case .classifying:   return "sparkle.magnifyingglass"
        case .result:        return "checkmark"
        }
    }

    private var detectionStateSubtitle: String {
        switch detectionState {
        case .idle:
            return classifier.usingCoreML
                ? "Pick a photo to auto-fill name & macros."
                : "Pick a photo (model not loaded — will fail silently)."
        case .classifying:
            return "Analyzing image…"
        case .result(let p):
            return String(format: "Detected %@ (%d%% confidence)", p.displayName, Int(p.confidence * 100))
        case .failed(let msg):
            return msg
        }
    }

    private func detectionResultRow(_ prediction: FoodPrediction) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(FawFittTheme.neon)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apply detection to fields")
                    .font(.caption.bold())
                Text("\(prediction.nutrition.calories) kcal · P \(prediction.nutrition.protein)g · C \(prediction.nutrition.carbs)g · F \(prediction.nutrition.fat)g")
                    .font(.caption2)
                    .foregroundStyle(FawFittTheme.mutedText)
            }
            Spacer()
            Button("Apply") { apply(prediction) }
                .font(.caption.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(FawFittTheme.neon, in: Capsule())
        }
        .padding(10)
        .background(FawFittTheme.neon.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        detectionState = .classifying
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    detectionState = .failed("Couldn't read the selected photo.")
                    return
                }
                if let prediction = await classifier.classify(image) {
                    detectionState = .result(prediction)
                    lastPrediction = prediction
                } else {
                    detectionState = .failed(classifier.lastError ?? "No prediction returned.")
                }
            } catch {
                detectionState = .failed(error.localizedDescription)
            }
        }
    }

    private func apply(_ prediction: FoodPrediction) {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = prediction.displayName
        }
        calories = prediction.nutrition.calories
        protein = prediction.nutrition.protein
        carbs = prediction.nutrition.carbs
        fat = prediction.nutrition.fat
    }

    private var macroDistributionBar: some View {
        let total = max(1, protein + carbs + fat)
        let pRatio = CGFloat(protein) / CGFloat(total)
        let cRatio = CGFloat(carbs) / CGFloat(total)
        let fRatio = CGFloat(fat) / CGFloat(total)
        let hasMacros = (protein + carbs + fat) > 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                macroLegendDot("P", value: protein, color: FawFittTheme.cyan)
                macroLegendDot("C", value: carbs, color: FawFittTheme.warning)
                macroLegendDot("F", value: fat, color: FawFittTheme.violet)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if hasMacros {
                        Capsule().fill(FawFittTheme.cyan).frame(width: geo.size.width * pRatio)
                        Capsule().fill(FawFittTheme.warning).frame(width: geo.size.width * cRatio)
                        Capsule().fill(FawFittTheme.violet).frame(width: geo.size.width * fRatio)
                    } else {
                        Capsule().fill(FawFittTheme.glass)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: protein)
                .animation(.easeInOut(duration: 0.3), value: carbs)
                .animation(.easeInOut(duration: 0.3), value: fat)
            }
            .frame(height: 8)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 4)
    }

    private func macroLegendDot(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(value)g")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }

    private var nameCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FawFittTheme.neon)
                    .frame(width: 36, height: 36)
                    .background(FawFittTheme.neon.opacity(0.14), in: Circle())
                TextField("Meal name (e.g. Grilled chicken bowl)", text: $name)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .submitLabel(.done)
            }
        }
    }

    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal type")
                .font(.caption.bold())
                .foregroundStyle(FawFittTheme.mutedText)
                .padding(.leading, 4)
            HStack(spacing: 8) {
                ForEach(MealType.allCases) { type in
                    typePill(type)
                }
            }
        }
    }

    private func typePill(_ type: MealType) -> some View {
        let isSelected = mealType == type.rawValue
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { mealType = type.rawValue }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.system(size: 18, weight: .semibold))
                Text(type.rawValue)
                    .font(.caption2.bold())
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ? FawFittTheme.neon : FawFittTheme.glass,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? .clear : FawFittTheme.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var dateCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FawFittTheme.cyan)
                    .frame(width: 36, height: 36)
                    .background(FawFittTheme.cyan.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date").font(.caption).foregroundStyle(FawFittTheme.mutedText)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FawFittTheme.neon)
                }
                Spacer()
            }
        }
    }

    private var macroGrid: some View {
        VStack(spacing: 10) {
            macroStepperTile(
                title: "Calories",
                value: $calories,
                unit: "kcal",
                step: 10,
                range: 0...3000,
                icon: "flame.fill",
                color: FawFittTheme.neon
            )
            macroStepperTile(
                title: "Protein",
                value: $protein,
                unit: "g",
                step: 1,
                range: 0...300,
                icon: "fish.fill",
                color: FawFittTheme.cyan
            )
            macroStepperTile(
                title: "Carbs",
                value: $carbs,
                unit: "g",
                step: 1,
                range: 0...500,
                icon: "leaf.fill",
                color: FawFittTheme.warning
            )
            macroStepperTile(
                title: "Fat",
                value: $fat,
                unit: "g",
                step: 1,
                range: 0...200,
                icon: "drop.fill",
                color: FawFittTheme.violet
            )
        }
    }

    private func macroStepperTile(
        title: String,
        value: Binding<Int>,
        unit: String,
        step: Int,
        range: ClosedRange<Int>,
        icon: String,
        color: Color
    ) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundStyle(FawFittTheme.mutedText)
                    Text("\(value.wrappedValue) \(unit)")
                        .font(.headline)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: value.wrappedValue)
                }
                Spacer()
                HStack(spacing: 8) {
                    macroButton(systemImage: "minus") {
                        let next = max(range.lowerBound, value.wrappedValue - step)
                        value.wrappedValue = next
                    }
                    .disabled(value.wrappedValue <= range.lowerBound)
                    macroButton(systemImage: "plus") {
                        let next = min(range.upperBound, value.wrappedValue + step)
                        value.wrappedValue = next
                    }
                    .disabled(value.wrappedValue >= range.upperBound)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value.wrappedValue) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            case .decrement:
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            @unknown default:
                break
            }
        }
    }

    private func macroButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(FawFittTheme.glass, in: Circle())
                .overlay(Circle().stroke(FawFittTheme.glassStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if let id = existingId {
            let updated = MealLog(
                id: id,
                name: trimmedName,
                mealType: mealType,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                mealDate: date
            )
            appModel.updateMeal(updated)
        } else {
            let new = MealLog(
                name: trimmedName,
                mealType: mealType,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                mealDate: date
            )
            appModel.addMeal(new)
        }
        dismiss()
    }
}

struct ProfileView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var saveStatus: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        heroCard
                        statsRow
                        basicsCard
                        goalCard
                        permissionsCard
                        if let saveStatus {
                            Label(saveStatus, systemImage: "icloud.and.arrow.up")
                                .font(.caption)
                                .foregroundStyle(FawFittTheme.mutedText)
                                .frame(maxWidth: .infinity)
                        }
                        NeonButton(
                            title: isSaving ? "Saving…" : "Save changes",
                            systemImage: "checkmark.icloud"
                        ) {
                            Task { await saveChanges() }
                        }
                        .opacity(isSaving ? 0.6 : 1)
                        .disabled(isSaving)
                        signOutButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func saveChanges() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        await appModel.saveProfileChanges()
        saveStatus = appModel.authStatus.isEmpty ? "Synced" : appModel.authStatus
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [FawFittTheme.neon.opacity(0.42), FawFittTheme.cyan.opacity(0.18), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    avatar
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appModel.profile.name.isEmpty ? "Athlete" : appModel.profile.name)
                            .font(.title.bold())
                            .lineLimit(1)
                            .foregroundStyle(.white)
                        Text("\(appModel.profile.age) yrs · \(Int(appModel.profile.heightCM))cm · \(String(format: "%.1f", appModel.profile.weightKG))kg")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    heroTag(icon: "target", text: appModel.profile.target.rawValue)
                    heroTag(icon: "bolt.fill", text: appModel.profile.activityLevel.rawValue)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FawFittTheme.glass)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(FawFittTheme.glassStroke, lineWidth: 1)
        )
        .shadow(color: FawFittTheme.neon.opacity(0.18), radius: 24, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [FawFittTheme.neon, FawFittTheme.cyan.opacity(0.6)],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 80
                    )
                )
            Text(profileInitial)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.black)
        }
        .frame(width: 72, height: 72)
        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 2))
        .shadow(color: FawFittTheme.neon.opacity(0.5), radius: 14)
        .accessibilityHidden(true)
    }

    private func heroTag(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.bold())
            Text(text).font(.caption.bold())
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.92), in: Capsule())
    }

    private var statsRow: some View {
        let weekBurn = Int(appModel.weeklyMetrics.reduce(0.0) { $0 + $1.calories })
        let weekWorkouts = Int(appModel.weeklyMetrics.reduce(0.0) { $0 + $1.workouts })
        return HStack(spacing: 12) {
            statTile(value: "\(appModel.streak)", label: "Day streak", icon: "flame.fill", color: FawFittTheme.warning)
            statTile(value: "\(weekWorkouts)", label: "Workouts/wk", icon: "figure.run", color: FawFittTheme.neon)
            statTile(value: weekBurn >= 1000 ? String(format: "%.1fk", Double(weekBurn) / 1000) : "\(weekBurn)", label: "Burn/wk", icon: "bolt.fill", color: FawFittTheme.cyan)
        }
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(FawFittTheme.mutedText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FawFittTheme.glassStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private var basicsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Personal", icon: "person.crop.circle.fill")
                HStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(FawFittTheme.neon)
                        .frame(width: 28, height: 28)
                        .background(FawFittTheme.neon.opacity(0.14), in: Circle())
                    TextField("Name", text: $appModel.profile.name)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                }
                .padding(10)
                .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 12) {
                    MetricInput(title: "Height", value: $appModel.profile.heightCM, suffix: "cm")
                    MetricInput(title: "Weight", value: $appModel.profile.weightKG, suffix: "kg")
                }

                Stepper("Age \(appModel.profile.age)", value: $appModel.profile.age, in: 13...90)
                    .font(.subheadline)
                    .tint(FawFittTheme.neon)
            }
        }
    }

    private var goalCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Goal", icon: "target")
                HStack(spacing: 10) {
                    ProfileSummaryPill(title: "Target", value: appModel.profile.target.rawValue)
                    ProfileSummaryPill(title: "Level", value: appModel.profile.activityLevel.rawValue)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(FawFittTheme.warning)
                        Text("Daily calorie goal")
                            .font(.subheadline)
                        Spacer()
                        Text("\(appModel.profile.dailyCalorieGoal) kcal")
                            .font(.headline)
                            .foregroundStyle(FawFittTheme.neon)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.2), value: appModel.profile.dailyCalorieGoal)
                    }
                    Stepper(
                        "Adjust",
                        value: $appModel.profile.dailyCalorieGoal,
                        in: 1200...5000,
                        step: 50
                    )
                    .labelsHidden()
                    .tint(FawFittTheme.neon)
                }
                .padding(12)
                .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var permissionsCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                sectionHeader("Permissions", icon: "lock.shield.fill")
                ProfileActionRow(
                    icon: "heart.text.square",
                    title: "Apple Health",
                    subtitle: appModel.healthKit.syncStatus,
                    buttonTitle: appModel.healthKit.isAuthorized ? "Sync" : "Connect",
                    action: appModel.requestHealthAccess
                )
                Divider().background(FawFittTheme.glassStroke)
                ProfileActionRow(
                    icon: "bell",
                    title: "Notifications",
                    subtitle: appModel.notifications.authorizationStatus,
                    buttonTitle: "Enable",
                    action: appModel.requestNotifications
                )
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(FawFittTheme.neon)
            Text(title).font(.headline)
        }
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            appModel.signOut()
            dismiss()
        } label: {
            Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.headline)
                .foregroundStyle(FawFittTheme.warning)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FawFittTheme.glass, in: Capsule())
                .overlay(Capsule().stroke(FawFittTheme.glassStroke, lineWidth: 1))
        }
    }

    private var profileInitial: String {
        let initial = String(appModel.profile.name.prefix(1)).uppercased()
        return initial.isEmpty ? "F" : initial
    }
}

struct ProfileSummaryPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(FawFittTheme.mutedText)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ProfileActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FawFittTheme.neon)
                .frame(width: 38, height: 38)
                .background(FawFittTheme.neon.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(FawFittTheme.mutedText)
                    .lineLimit(1)
            }
            Spacer()
            Button(buttonTitle) { action() }
                .font(.caption.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(FawFittTheme.neon, in: Capsule())
        }
    }
}

// MARK: - Workout Flow

struct WorkoutDetailSheet: View {
    let plan: WorkoutPlan
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning = false
    @State private var exerciseIndex = 0
    @State private var setIndex = 0
    @State private var phase: Phase = .work
    @State private var phaseRemaining: Int = 0
    @State private var elapsedSeconds: Int = 0
    @State private var completedSets: Int = 0
    @State private var didFinish = false
    @State private var showLiveCamera = false
    @State private var lastDetectedReps: Int?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum Phase { case work, rest, done }

    private var currentExercise: PlannedExercise? {
        guard plan.exercises.indices.contains(exerciseIndex) else { return nil }
        return plan.exercises[exerciseIndex]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FawFittTheme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        if didFinish {
                            resultPanel
                        } else if isRunning {
                            activePanel
                        } else {
                            summaryPanel
                        }
                        if !didFinish {
                            exerciseList
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 110)
                }
                VStack {
                    Spacer()
                    actionBar
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }
            .navigationTitle(plan.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { saveProgressOnDismiss(); dismiss() }
                }
            }
            .onReceive(ticker) { _ in tick() }
            .interactiveDismissDisabled(isRunning && completedSets > 0)
            .fullScreenCover(isPresented: $showLiveCamera) {
                if let exercise = currentExercise {
                    LiveWorkoutView(
                        exerciseId: cameraExerciseId(for: exercise),
                        targetExerciseName: exercise.name,
                        targetReps: exercise.isTimed ? 0 : exercise.reps
                    ) { result in
                        lastDetectedReps = result.repCount
                        advanceSet()
                    }
                }
            }
        }
    }

    private func cameraExerciseId(for exercise: PlannedExercise) -> String {
        // Normalize the live exercise name to a slug the MotionTracker can dispatch on.
        // Slugs matching ExerciseDefinition get angle-based rep counting; the rest
        // (plank, lunge, jacks…) still get the camera + pose overlay for visual feedback.
        let lower = exercise.name.lowercased()
        if lower.contains("squat") { return "squat" }
        if lower.contains("lunge") { return "lunge" }
        if lower.contains("push") { return "pushup" }
        if lower.contains("pull") { return "pullup" }
        if lower.contains("plank") { return "plank" }
        if lower.contains("crunch") { return "crunch" }
        if lower.contains("sit") { return "situp" }
        if lower.contains("curl") { return "bicep_curl" }
        if lower.contains("lateral") || lower.contains("side raise") { return "lateral_raise" }
        if lower.contains("overhead") || lower.contains("shoulder press") { return "overhead_press" }
        if lower.contains("knee") { return "knee_raise" }
        if lower.contains("leg raise") { return "leg_raise" }
        if lower.contains("jack") { return "jumping_jack" }
        return lower.replacingOccurrences(of: " ", with: "_")
    }

    private func saveProgressOnDismiss() {
        // If the user did at least one set but never tapped End or finished the plan,
        // still log their partial progress so it shows up in Progress.
        guard !didFinish, completedSets > 0 else { return }
        let duration = elapsedSeconds
        let sets = completedSets
        let plan = self.plan
        Task { await appModel.logCompletedWorkout(plan: plan, durationSeconds: duration, completedSets: sets) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.rationale)
                .font(.subheadline)
                .foregroundStyle(FawFittTheme.mutedText)
            HStack(spacing: 14) {
                Label("\(plan.duration)m", systemImage: "timer")
                Label("\(plan.calories) kcal", systemImage: "flame")
                Label(plan.intensity.rawValue, systemImage: "bolt.fill")
            }
            .font(.caption)
            .foregroundStyle(FawFittTheme.mutedText)
        }
    }

    private var summaryPanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Plan overview").font(.headline)
                HStack {
                    statTile(title: "Exercises", value: "\(plan.exercises.count)")
                    statTile(title: "Total sets", value: "\(plan.totalSets)")
                    statTile(title: "Recovery", value: "\(plan.recoveryScore)")
                }
                Text("Tap Start to step through each exercise. Mark each set complete when you finish it, and we'll handle the rest timer for you.")
                    .font(.caption)
                    .foregroundStyle(FawFittTheme.mutedText)
            }
        }
    }

    private var activePanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                if let exercise = currentExercise {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(phase == .rest ? "Rest" : exercise.name)
                                .font(.title2.bold())
                            Text(phase == .rest
                                 ? "Next: \(nextLabel())"
                                 : "Set \(setIndex + 1) of \(exercise.sets) · \(exercise.detailText)")
                                .font(.caption)
                                .foregroundStyle(FawFittTheme.mutedText)
                        }
                        Spacer()
                        Image(systemName: exercise.systemImage)
                            .font(.system(size: 36))
                            .foregroundStyle(FawFittTheme.neon)
                    }
                    timerBlock(exercise: exercise)
                } else {
                    Text("Workout complete")
                        .font(.title2.bold())
                }
                ProgressView(value: progress)
                    .tint(FawFittTheme.neon)
                HStack {
                    Label("Elapsed \(formatTime(elapsedSeconds))", systemImage: "stopwatch")
                    Spacer()
                    Label("\(completedSets)/\(plan.totalSets) total sets", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundStyle(FawFittTheme.mutedText)
                Text("Exercise \(exerciseIndex + 1) of \(plan.exercises.count) · Set \((currentExercise?.sets ?? 0) > 0 ? min(setIndex + 1, currentExercise?.sets ?? 0) : 0) of \(currentExercise?.sets ?? 0)")
                    .font(.caption2)
                    .foregroundStyle(FawFittTheme.mutedText.opacity(0.85))
            }
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                Image(resultImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipped()
                LinearGradient(
                    colors: [Color.black.opacity(0.05), Color.black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: completionRatio >= 1 ? "checkmark.seal.fill" : "flag.checkered")
                        .font(.system(size: 34))
                        .foregroundStyle(FawFittTheme.neon)
                    Text(completionRatio >= 1 ? "Workout complete" : "Workout saved")
                        .font(.title2.bold())
                    Text(resultMessage)
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(FawFittTheme.glassStroke, lineWidth: 1)
            )

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Session result")
                        .font(.headline)
                    HStack {
                        statTile(title: "Time", value: formatTime(elapsedSeconds))
                        statTile(title: "Sets", value: "\(completedSets)/\(plan.totalSets)")
                        statTile(title: "Kcal", value: "\(estimatedResultCalories)")
                    }
                    ProgressView(value: completionRatio)
                        .tint(FawFittTheme.neon)
                    Text("Estimated calories are adjusted from the sets you completed. Nice work, and take a short cooldown before moving on.")
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func timerBlock(exercise: PlannedExercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(phase == .rest ? "Rest timer" : (exercise.isTimed ? "Hold timer" : "Target reps"))
                    .font(.caption)
                    .foregroundStyle(FawFittTheme.mutedText)
                Text(phase == .rest || exercise.isTimed
                     ? "\(phaseRemaining)s"
                     : "\(exercise.reps) reps")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(phase == .rest ? FawFittTheme.cyan : FawFittTheme.neon)
                if let last = lastDetectedReps, phase == .rest {
                    Text("Last set: \(last) reps detected")
                        .font(.caption2)
                        .foregroundStyle(FawFittTheme.neon)
                }
            }
            Spacer()
            if phase == .rest {
                Button {
                    advanceSet()
                } label: {
                    Label("Skip rest", systemImage: "forward.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(FawFittTheme.neon, in: Capsule())
                }
                .accessibilityLabel("Skip rest")
            } else {
                Button {
                    showLiveCamera = true
                } label: {
                    Label("Track reps", systemImage: "video.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(FawFittTheme.neon, in: Capsule())
                }
                .accessibilityLabel("Open camera for rep tracking")
            }
        }
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercises").font(.headline)
            ForEach(Array(plan.exercises.enumerated()), id: \.offset) { idx, exercise in
                exerciseRow(index: idx, exercise: exercise)
            }
        }
    }

    private func exerciseRow(index: Int, exercise: PlannedExercise) -> some View {
        let isActive = isRunning && index == exerciseIndex && phase != .done
        let isDone = isRunning ? index < exerciseIndex : false
        return GlassCard {
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : exercise.systemImage)
                    .font(.title3)
                    .foregroundStyle(isDone ? FawFittTheme.neon : (isActive ? FawFittTheme.neon : .white.opacity(0.8)))
                    .frame(width: 36, height: 36)
                    .background((isActive ? FawFittTheme.neon.opacity(0.14) : FawFittTheme.glass), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name).font(.headline)
                    Text(exercise.detailText)
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                    if !exercise.instructions.isEmpty {
                        Text(exercise.instructions)
                            .font(.caption2)
                            .foregroundStyle(FawFittTheme.mutedText.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                Spacer()
                if isActive {
                    Text("Now")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(FawFittTheme.neon, in: Capsule())
                }
            }
        }
    }

    private var actionBar: some View {
        Group {
            if didFinish {
                NeonButton(title: "Done", systemImage: "checkmark.seal.fill") { dismiss() }
            } else if !isRunning {
                NeonButton(title: "Start workout", systemImage: "play.fill") { startWorkout() }
            } else {
                HStack(spacing: 12) {
                    Button {
                        finishWorkout(early: true)
                    } label: {
                        Label("End", systemImage: "stop.fill")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    if phase == .rest {
                        Button {
                            advanceSet()
                        } label: {
                            Label("Skip rest", systemImage: "forward.fill")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FawFittTheme.neon, in: Capsule())
                        }
                    } else {
                        Button {
                            advanceSet()
                        } label: {
                            Label("Complete", systemImage: "checkmark")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FawFittTheme.neon, in: Capsule())
                        }
                        .accessibilityLabel("Mark current set complete")
                        Button {
                            skipExercise()
                        } label: {
                            Label("Skip", systemImage: "forward.end.fill")
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .accessibilityLabel("Skip this exercise")
                    }
                }
            }
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).foregroundStyle(FawFittTheme.neon)
            Text(title).font(.caption).foregroundStyle(FawFittTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var progress: Double {
        plan.totalSets > 0 ? Double(completedSets) / Double(plan.totalSets) : 0
    }

    private var completionRatio: Double {
        plan.totalSets > 0 ? min(1, max(0, Double(completedSets) / Double(plan.totalSets))) : 0
    }

    private var estimatedResultCalories: Int {
        Int(Double(plan.calories) * completionRatio)
    }

    private var resultImageName: String {
        plan.category == .abs ? "WorkoutCore" : "WorkoutStrength"
    }

    private var resultMessage: String {
        if completionRatio >= 1 {
            return "You finished the full plan and logged the session."
        }
        return "You ended early, so the result was logged based on completed sets."
    }

    private func nextLabel() -> String {
        guard let exercise = currentExercise else { return "—" }
        if setIndex + 1 < exercise.sets {
            return "\(exercise.name) · set \(setIndex + 2)"
        }
        let nextIndex = exerciseIndex + 1
        if plan.exercises.indices.contains(nextIndex) {
            return plan.exercises[nextIndex].name
        }
        return "Finish"
    }

    private func startWorkout() {
        isRunning = true
        exerciseIndex = 0
        setIndex = 0
        completedSets = 0
        elapsedSeconds = 0
        didFinish = false
        beginPhase(.work)
    }

    private func tick() {
        guard isRunning, !didFinish else { return }
        elapsedSeconds += 1
        switch phase {
        case .work:
            if let exercise = currentExercise, exercise.isTimed {
                if phaseRemaining > 0 {
                    phaseRemaining -= 1
                    if phaseRemaining == 0 { advanceSet() }
                }
            }
        case .rest:
            if phaseRemaining > 0 {
                phaseRemaining -= 1
                if phaseRemaining == 0 { startNextSet() }
            }
        case .done:
            break
        }
    }

    private func beginPhase(_ next: Phase) {
        phase = next
        guard let exercise = currentExercise else {
            phaseRemaining = 0
            return
        }
        switch next {
        case .work:
            phaseRemaining = exercise.isTimed ? exercise.holdSeconds : 0
        case .rest:
            phaseRemaining = exercise.restSeconds
        case .done:
            phaseRemaining = 0
        }
    }

    private func advanceSet() {
        guard let exercise = currentExercise else { return }
        if phase == .rest {
            startNextSet()
            return
        }
        completedSets = min(plan.totalSets, completedSets + 1)
        let isLastSet = setIndex + 1 >= exercise.sets
        let isLastExercise = exerciseIndex + 1 >= plan.exercises.count
        if isLastSet && isLastExercise {
            finishWorkout(early: false)
            return
        }
        beginPhase(.rest)
    }

    private func startNextSet() {
        guard let exercise = currentExercise else { return }
        if setIndex + 1 < exercise.sets {
            setIndex += 1
        } else {
            exerciseIndex += 1
            setIndex = 0
        }
        beginPhase(.work)
    }

    private func skipExercise() {
        guard isRunning, !didFinish else { return }
        let isLastExercise = exerciseIndex + 1 >= plan.exercises.count
        if isLastExercise {
            finishWorkout(early: false)
            return
        }
        exerciseIndex += 1
        setIndex = 0
        beginPhase(.work)
    }

    private func finishWorkout(early _: Bool) {
        phase = .done
        didFinish = true
        isRunning = false
        let duration = elapsedSeconds
        let sets = completedSets
        let plan = self.plan
        Task { await appModel.logCompletedWorkout(plan: plan, durationSeconds: duration, completedSets: sets) }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Components

struct AnimatedBackground: View {
    var body: some View {
        ZStack {
            FawFittTheme.background.ignoresSafeArea()
            FawFittTheme.dashboardGradient
                .ignoresSafeArea()
        }
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(FawFittTheme.glassStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }
}

struct NeonButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(FawFittTheme.neon, in: Capsule())
                .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        }
        .accessibilityLabel(title)
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(selectedTab == tab ? FawFittTheme.neon : Color.white.opacity(0.58))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? FawFittTheme.neon.opacity(0.12) : .clear, in: Capsule())
                }
                .accessibilityLabel(tab.rawValue)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .background(FawFittTheme.glass, in: Capsule())
        .overlay(Capsule().stroke(FawFittTheme.glassStroke, lineWidth: 1))
    }
}

struct ProgressRing: View {
    let progress: Double
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(FawFittTheme.glassStroke.opacity(0.7), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.5), radius: 10)
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 86, height: 86)
            Text(title)
                .font(.caption)
                .foregroundStyle(FawFittTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

struct PhotoFeatureCard: View {
    let imageName: String
    let eyebrow: String
    let title: String
    let detail: String
    let badge: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(eyebrow)
                        .font(.title3.bold())
                    Spacer()
                    Text(badge)
                        .font(.title2.bold())
                }
                Spacer()
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                        .lineLimit(1)
                    Spacer()
                    Label("Join", systemImage: "arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(FawFittTheme.neon, in: Capsule())
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 188)
        .background {
            Image(imageName)
                .resizable()
                .scaledToFill()
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FawFittTheme.glassStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.32), radius: 18, x: 0, y: 10)
    }
}

struct PhotoProgramTile: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(FawFittTheme.mutedText)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 154)
        .background {
            Image(imageName)
                .resizable()
                .scaledToFill()
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FawFittTheme.glassStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(value).font(.headline)
                    Text(title).font(.caption).foregroundStyle(FawFittTheme.mutedText)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Per-category card art: a real Unsplash photo matching the workout's muscle group,
/// with a scrim + title overlay so every plan in the matrix reads as visually distinct.
struct WorkoutArtwork: View {
    let category: WorkoutCategory
    let title: String
    var height: CGFloat = 132

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(category.rawValue.uppercased())
                    .font(.caption2.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.28), in: Capsule())
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            Image(category.artworkAsset)
                .resizable()
                .scaledToFill()
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(category.rawValue) workout")
    }
}

struct WorkoutPlanCard: View {
    let plan: WorkoutPlan

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                WorkoutArtwork(category: plan.category, title: plan.title)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(FawFittTheme.glassStroke, lineWidth: 1)
                    )
                HStack(alignment: .top) {
                    Text(plan.rationale)
                        .font(.caption)
                        .foregroundStyle(FawFittTheme.mutedText)
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(plan.recoveryScore)")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(FawFittTheme.neon)
                        Text("recovery")
                            .font(.caption2)
                            .foregroundStyle(FawFittTheme.mutedText)
                    }
                }
                HStack {
                    Label("\(plan.duration)m", systemImage: "timer")
                    Label("\(plan.calories) kcal", systemImage: "flame")
                    Label(plan.category.rawValue, systemImage: "square.grid.2x2")
                }
                .font(.caption)
                .foregroundStyle(FawFittTheme.mutedText)
                FlowLayout(items: plan.exercises.map(\.name))
            }
        }
    }
}

struct FlowLayout: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.bold())
                    .foregroundStyle(FawFittTheme.neon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(FawFittTheme.neon.opacity(0.12), in: Capsule())
            }
        }
    }
}

struct CoachBubble: View {
    let message: CoachMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 42) }
            Text(message.text)
                .font(.body)
                .padding(14)
                .background(message.isUser ? FawFittTheme.neon.opacity(0.92) : FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(message.isUser ? .black : .white)
                .accessibilityLabel(message.isUser ? "You said \(message.text)" : "Coach said \(message.text)")
            if !message.isUser { Spacer(minLength: 42) }
        }
        .padding(.horizontal, 16)
    }
}

struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(achievement.unlocked ? FawFittTheme.neon : FawFittTheme.mutedText)
                    .frame(width: 40, height: 40)
                    .background(FawFittTheme.glass, in: Circle())
                VStack(alignment: .leading) {
                    Text(achievement.title).font(.headline)
                    Text(achievement.detail).font(.caption).foregroundStyle(FawFittTheme.mutedText)
                }
                Spacer()
                Image(systemName: achievement.unlocked ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(achievement.unlocked ? FawFittTheme.neon : FawFittTheme.mutedText)
            }
        }
    }
}

struct MealRow: View {
    let meal: MealLog

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(meal.mealType.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(FawFittTheme.neon)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FawFittTheme.neon.opacity(0.14), in: Capsule())
                    Text(meal.name).font(.headline).lineLimit(1)
                    Spacer()
                    Text("\(meal.calories) kcal").foregroundStyle(FawFittTheme.neon)
                }
                HStack {
                    Text("P \(meal.protein)g")
                    Text("C \(meal.carbs)g")
                    Text("F \(meal.fat)g")
                    Spacer()
                    Label("Barcode", systemImage: "barcode.viewfinder")
                }
                .font(.caption)
                .foregroundStyle(FawFittTheme.mutedText)
            }
        }
    }
}

struct MetricInput: View {
    let title: String
    @Binding var value: Double
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(FawFittTheme.mutedText)
            HStack {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.decimalPad)
                Text(suffix).foregroundStyle(FawFittTheme.mutedText)
            }
            .padding(10)
            .background(FawFittTheme.glass, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Mock Data

enum MockData {
    static let appleHealthAgentA2AResponseJSON = #"""
{
  "jsonrpc": "2.0",
  "id": "fawfitt-apple-health-calories-001",
  "result": {
    "agent": {
      "name": "AppleHealthAgent",
      "persona": "Privacy-first Apple Health interpreter for FawFitt calorie signals.",
      "version": "1.0.0"
    },
    "artifact": {
      "type": "health.calorie.sample",
      "unit": "kcal",
      "generatedAt": "2026-05-14T09:00:00Z"
    },
    "calories": {
      "activeEnergyBurned": 684,
      "restingEnergyBurned": 1638,
      "totalBurned": 2322,
      "dailyGoal": 2400,
      "samples": [
        {
          "date": "2026-05-08",
          "active": 420,
          "total": 2060,
          "score": 68
        },
        {
          "date": "2026-05-09",
          "active": 610,
          "total": 2245,
          "score": 72
        },
        {
          "date": "2026-05-10",
          "active": 530,
          "total": 2168,
          "score": 70
        },
        {
          "date": "2026-05-11",
          "active": 740,
          "total": 2384,
          "score": 78
        },
        {
          "date": "2026-05-12",
          "active": 690,
          "total": 2320,
          "score": 81
        },
        {
          "date": "2026-05-13",
          "active": 820,
          "total": 2466,
          "score": 86
        },
        {
          "date": "2026-05-14",
          "active": 760,
          "total": 2415,
          "score": 88
        }
      ]
    },
    "summary": "Mock A2A calorie signal: user is 96.8% toward the daily burn goal with strong active-energy consistency."
  }
}
"""#

    static let weeklyMetrics: [WeeklyMetric] = {
        let calendar = Calendar.current
        return (0..<7).map { offset in
            WeeklyMetric(
                date: calendar.date(byAdding: .day, value: offset - 6, to: Date()) ?? Date(),
                calories: Double([420, 610, 530, 740, 690, 820, 760][offset]),
                workouts: Double([1, 1, 0, 1, 1, 1, 1][offset]),
                score: Double([68, 72, 70, 78, 81, 86, 88][offset])
            )
        }
    }()

    static let meals = [
        MealLog(name: "Protein oats", mealType: "Breakfast", calories: 420, protein: 32, carbs: 46, fat: 11),
        MealLog(name: "Chicken rice bowl", mealType: "Lunch", calories: 680, protein: 51, carbs: 72, fat: 18),
        MealLog(name: "Greek yogurt stack", mealType: "Snack", calories: 260, protein: 24, carbs: 22, fat: 7)
    ]

    static let achievements = [
        Achievement(icon: "flame.fill", title: "12 Day Streak", detail: "Consistency protocol active", unlocked: true),
        Achievement(icon: "figure.run", title: "10K Steps", detail: "Daily movement target reached", unlocked: true),
        Achievement(icon: "moon.stars.fill", title: "Recovery Master", detail: "Hit 7+ hours sleep three times", unlocked: true),
        Achievement(icon: "crown.fill", title: "Monthly Elite", detail: "Complete 24 workouts this month", unlocked: false)
    ]
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppViewModel())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
