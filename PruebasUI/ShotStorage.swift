import Foundation

class ShotStorage: ObservableObject {

    @Published var shots: [Int : ShotConfig] = [:]

    private let storageKey = "SAVED_SHOTS_V1"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("ShotStorage: No saved data, using empty dictionary.")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([Int : ShotConfig].self, from: data)
            self.shots = decoded
            print("ShotStorage: Loaded \(decoded.count) shots.")
        } catch {
            print("ShotStorage load error: \(error)")
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(shots)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("ShotStorage: Saved OK.")
        } catch {
            print("ShotStorage save error: \(error)")
        }
    }

    func updateShot(_ shot: ShotConfig) {
        shots[shot.shotNumber] = shot
        save()
    }
}

