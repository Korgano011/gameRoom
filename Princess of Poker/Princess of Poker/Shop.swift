import SwiftUI

/// Salon and table enhancements bought with the salon's cash box and bank account.
enum Upgrade: String, CaseIterable, Codable, Identifiable {
    case goldMirror, velvetFelt, clayChips, neonSign, shuffler, plushChairs, snackBar, turboBeam, chandelier, champagne

    var id: String { rawValue }

    var name: String {
        switch self {
        case .goldMirror: "Gold Vanity Mirror"
        case .velvetFelt: "Purple Velvet Felt"
        case .clayChips: "Gold Clay Chips"
        case .neonSign: "Neon Salon Sign"
        case .shuffler: "Automatic Shuffler"
        case .plushChairs: "Plush Styling Chairs"
        case .snackBar: "Snack Bar"
        case .turboBeam: "Turbo Tractor Beam"
        case .chandelier: "Crystal Chandelier"
        case .champagne: "Champagne Fountain"
        }
    }

    var price: Int {
        switch self {
        case .goldMirror: 90
        case .velvetFelt: 80
        case .clayChips: 100
        case .neonSign: 120
        case .shuffler: 140
        case .plushChairs: 150
        case .snackBar: 160
        case .turboBeam: 180
        case .chandelier: 200
        case .champagne: 300
        }
    }

    var salon: Bool {
        switch self {
        case .velvetFelt, .clayChips, .shuffler, .snackBar: false
        default: true
        }
    }

    var blurb: String {
        switch self {
        case .goldMirror: "An ornate gold frame for the salon's wall mirror."
        case .velvetFelt: "Swap the green felt for royal purple velvet."
        case .clayChips: "Heavy gold clay chips that clack just right."
        case .neonSign: "A glowing sign on the salon — more men say yes (+15%)."
        case .shuffler: "Cards fly faster; hands deal quicker."
        case .plushChairs: "Purple velvet chairs under the machines."
        case .snackBar: "Well-fed newcomers play looser — and lose more."
        case .turboBeam: "Beam passers-by up in half the time."
        case .chandelier: "Crystal sparkle over the salon floor."
        case .champagne: "Word gets around — two extra passers-by every night."
        }
    }

    var icon: String {
        switch self {
        case .goldMirror: "oval.portrait"
        case .velvetFelt: "rectangle.fill"
        case .clayChips: "circle.circle.fill"
        case .neonSign: "lightbulb.max.fill"
        case .shuffler: "shuffle"
        case .plushChairs: "chair.fill"
        case .snackBar: "fork.knife"
        case .turboBeam: "bolt.fill"
        case .chandelier: "sparkles"
        case .champagne: "wineglass.fill"
        }
    }
}

/// Progress in the salon, kept across launches.
struct SaveData: Codable {
    var reachedSalon = false
    var night = 0
    var cash = 100
    var bank = 0
    var totalProfit = 0
    var owned: Set<Upgrade> = []

    private static let key = "PrincessOfPokerSave"

    static func load() -> SaveData {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(SaveData.self, from: data) else { return SaveData() }
        return s
    }

    func store() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func erase() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func has(_ u: Upgrade) -> Bool { owned.contains(u) }
}

struct ShopView: View {
    @Binding var save: SaveData
    var onBuy: (Upgrade) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Cash box $\(save.cash)", systemImage: "banknote")
                        Spacer()
                        Label("Bank $\(save.bank)", systemImage: "building.columns")
                    }
                    .font(.system(.headline, design: .rounded))
                }
                Section("Salon") { rows(salon: true) }
                Section("Poker Table") { rows(salon: false) }
            }
            .navigationTitle("Princess's Shop")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func rows(salon: Bool) -> some View {
        ForEach(Upgrade.allCases.filter { $0.salon == salon }) { u in
            HStack(spacing: 12) {
                Image(systemName: u.icon)
                    .font(.title2)
                    .foregroundStyle(.pink)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.name).font(.system(.headline, design: .rounded))
                    Text(u.blurb).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if save.has(u) {
                    Label("Owned", systemImage: "checkmark.seal.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                        .font(.title2)
                } else {
                    Button("$\(u.price)") { onBuy(u) }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        .disabled(save.cash + save.bank < u.price)
                }
            }
        }
    }
}
