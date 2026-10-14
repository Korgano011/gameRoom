import Foundation

enum Story {
    static let prologue: [Shot] = [
        Shot(scene: .contest, text: "The year is 2025. You are Matt Decker. You build furniture — beautiful furniture — but you've been demoted to maintenance."),
        Shot(scene: .office, text: "Your boss has been on you on numerous occasions to stop building furniture, but you keep on doing it anyway. So he put you on a contract: maintenance only. Any violations will result in your termination."),
        Shot(scene: .office, text: "But the boss makes no progress. You just keep on doing it. Then the boss calls you into the office."),
        Shot(scene: .office, speaker: "Boss", text: "Didn't I put you on a contract?", voice: .boss),
        Shot(scene: .office, speaker: "Matt", text: "Yes, you did.", voice: .matt),
        Shot(scene: .office, speaker: "Boss", text: "What did the contract say?", voice: .boss),
        Shot(scene: .office, speaker: "Matt", text: "It said I cannot do anything other than maintenance work. Any violations will result in my termination.", voice: .matt),
        Shot(scene: .office, speaker: "Boss", text: "Alright. Tell me what happened.", voice: .boss),
        Shot(scene: .contest, speaker: "Matt", text: "There was a contest that allowed us to build the best piece of furniture, and I won it.", voice: .matt),
        Shot(scene: .office, speaker: "Boss", text: "Tell me what you said after the contest.", voice: .boss),
        Shot(scene: .office, speaker: "Matt", text: "The hell with my boss. He is the biggest crab in the world.", voice: .matt),
        Shot(scene: .office, speaker: "Boss", text: "What! What has gotten into you?", voice: .boss),
        Shot(scene: .office, speaker: "Matt", text: "A chance to show you what I can do.", voice: .matt),
        Shot(scene: .office, speaker: "Boss", text: "Matt, I don't know what to say to you. You have really done it this time. I can't allow you back in.", voice: .boss),
        Shot(scene: .office, speaker: "Matt", text: "That's fine.", voice: .matt),
        Shot(scene: .office, speaker: "Boss", text: "I have to tell you. I am very disappointed, and I feel sick that I have to let you go. Your work here is finished, and you're going to be heading out. Take care of yourself. Have a good life.", voice: .boss),
        Shot(scene: .evictionDoor, text: "When you get home to your apartment, there's a notice taped to the door: EVICTION. You need to vacate in two days."),
        Shot(scene: .morningDoor, text: "The next morning, someone materializes outside your door. You open it.", sfx: .transporter),
        Shot(scene: .morningDoor, speaker: "Stranger", text: "So. You had a mean boss that wouldn't let you build furniture anymore.", voice: .stranger),
        Shot(scene: .morningDoor, speaker: "Matt", text: "How did you know about that?", voice: .matt),
        Shot(scene: .morningDoor, speaker: "Stranger", text: "Grab my hand.", voice: .stranger),
        Shot(scene: .timeTunnel, text: "The hallway dissolves into light. Years stream past — 2050… 2150… 2300…", sfx: .warp),
        Shot(scene: .starbaseReveal, speaker: "Stranger", text: "The year is 2355. Starfleet needs builders, Matt — people who won't stop building no matter who tells them to. She's yours.", voice: .stranger),
        Shot(scene: .starbaseReveal, text: "You are assigned to the Sovereign-class U.S.S. Constellation, NCC-1017-A."),
        Shot(scene: .bridge(.stars), speaker: "Chief Okoro", text: "Captain on the bridge! Welcome aboard, Captain Decker.", voice: .man),
        Shot(scene: .bridge(.stars), speaker: "Decker", text: "No more maintenance contracts. Let's see what this ship can do.", voice: .matt),
    ]

    static func mission1Intro(klingons: Int, days: Int, bases: Int) -> [Shot] {
        [
            Shot(scene: .klingonFleet, text: "Mission 1 — The Klingon Incursion.", sfx: .alert),
            Shot(scene: .bridge(.admiral), speaker: "Admiral Harlan", text: "Captain Decker, a renegade Klingon armada has crossed into Federation space. Long-range sensors count \(klingons) warships.", voice: .man, sfx: .chirp),
            Shot(scene: .bridge(.admiral), speaker: "Admiral Harlan", text: "You have \(days) stardates to destroy every one of them. There \(bases == 1 ? "is 1 starbase" : "are \(bases) starbases") in the sector to dock for energy, torpedoes and repairs.", voice: .man),
            Shot(scene: .bridge(.admiral), speaker: "Admiral Harlan", text: "Watch your life support. If it's knocked out, you'll have only a few stardates of reserves to fix it or reach a starbase.", voice: .man),
            Shot(scene: .bridge(.stars), speaker: "Decker", text: "Raise shields before we warp into anything. Helm — short-range scan.", voice: .matt),
        ]
    }

    static let mission1Won: [Shot] = [
        Shot(scene: .victory, text: "The last Klingon warship breaks apart. The sector is secure."),
        Shot(scene: .bridge(.admiral), speaker: "Admiral Harlan", text: "Outstanding work, Captain. Not bad for a furniture builder.", voice: .man),
    ]

    static let mission2Intro: [Shot] = [
        Shot(scene: .quarters, text: "Mission 2 — The Doomsday Machine. You are at home resting in your quarters aboard the Constellation."),
        Shot(scene: .pkEatsPlanet, text: "Meanwhile, somewhere in space… an enormous machine — a planet killer — is reducing a world to rubble.", sfx: .ray),
        Shot(scene: .pkVsExeter, speaker: "U.S.S. Exeter", text: "All phasers, fire! … No effect! Its hull is solid neutronium!", voice: .man, sfx: .phaser),
        Shot(scene: .pkVsExeter, text: "The machine turns its beam on the Exeter.", sfx: .explosion),
        Shot(scene: .escapePods, speaker: "U.S.S. Exeter", text: "Hull breach on every deck — abandon ship! All hands to the escape pods!", voice: .man, sfx: .alert),
        Shot(scene: .bridge(.planetKiller), speaker: "Commander Ruiz", text: "Captain to the bridge. Starfleet is calling us to service — the Exeter is gone and the machine is heading into the Rigel colonies.", voice: .woman, sfx: .alert),
        Shot(scene: .bridge(.planetKiller), speaker: "Decker", text: "Red alert. Set course for the Exeter's last position, maximum warp.", voice: .matt),
    ]

    static let mission2FirstTry: [Shot] = [
        Shot(scene: .saucerHit, text: "The machine's antiproton beam rakes the Constellation from bow to stern.", sfx: .explosion),
        Shot(scene: .bridge(.planetKiller), speaker: "Chief Okoro", text: "Heavy damage to the saucer section! Decks four through eleven are venting. Captain, we can't take another hit like that!", voice: .man, sfx: .hit),
        Shot(scene: .bridge(.planetKiller), speaker: "Decker", text: "Break off. Get us to Starbase 11 — whatever speed she can hold.", voice: .matt),
    ]

    static let mission2Starbase: [Shot] = [
        Shot(scene: .starbaseBriefing, speaker: "Commodore Hayes", text: "Your saucer section is going to need a week in spacedock, Captain. That machine won't wait a week.", voice: .man),
        Shot(scene: .starbaseBriefing, speaker: "Dr. Imani Sato", text: "There may be a way. The Daystrom Institute built a prototype — a theta-band disruptor ray. It destabilizes the neutronium lattice. Weaken the hull, and your weapons will finally bite.", voice: .woman),
        Shot(scene: .starbaseBriefing, speaker: "Commodore Hayes", text: "The prototype was aboard the science vessel Copernicus. She went silent in the Mutara Nebula three days ago.", voice: .man),
        Shot(scene: .starbaseBriefing, speaker: "Decker", text: "Then we separate the saucer, leave it here for repairs, and take the stardrive section to find that ray — before the machine eats any more planets.", voice: .matt),
    ]

    static let mission2Separation: [Shot] = [
        Shot(scene: .separation, speaker: "Decker", text: "All hands, prepare for saucer separation.", voice: .matt),
        Shot(scene: .separation, text: "Docking latches release. The saucer drifts free toward the starbase while the stardrive section swings about.", sfx: .warp),
    ]

    static let mission2Won: [Shot] = [
        Shot(scene: .pkDestroyed, text: "The weakened neutronium hull fractures. The planet killer tears itself apart from within.", sfx: .explosion),
        Shot(scene: .reunion, text: "Back at Starbase 11, the repaired saucer section locks into place. The Constellation is whole again."),
        Shot(scene: .bridge(.admiral), speaker: "Admiral Harlan", text: "The Rigel colonies owe you their lives, Captain Decker.", voice: .man),
    ]

    static let mission3Intro: [Shot] = [
        Shot(scene: .halcyonCruise, text: "Mission 3 — Resistance. The U.S.S. Halcyon, crewed entirely by women, is on a quiet survey run near the Typhon Expanse."),
        Shot(scene: .halcyonDeck, speaker: "Captain Vasquez", text: "Not a ripple in subspace all week. I could get used to this.", voice: .woman),
        Shot(scene: .halcyonDeck, speaker: "Lt. Park", text: "The tomatoes in the arboretum finally came in, Captain. Lunch is on me.", voice: .woman),
        Shot(scene: .halcyonDeck, speaker: "Dr. Lindqvist", text: "And for once, sickbay is empty. A peaceful day.", voice: .woman),
        Shot(scene: .borgArrives, speaker: "Ensign Reyes", text: "Captain — a vessel dropping out of transwarp, dead ahead. It's… a cube.", voice: .woman, sfx: .alert),
        Shot(scene: .borgArrives, speaker: "The Borg", text: "We are the Borg. Lower your shields and surrender your ship. We will add your biological and technological distinctiveness to our own. Resistance is futile.", voice: .borg),
        Shot(scene: .borgChase, speaker: "Captain Vasquez", text: "Helm, maximum warp! Engage!", voice: .woman, sfx: .warp),
        Shot(scene: .borgChase, text: "Warp 9.6 — the Halcyon's engines scream past their limits. The cube doesn't even strain. It's gaining."),
        Shot(scene: .tractorBeam, text: "A green tractor beam locks on. The Halcyon is dragged backward into the cube.", sfx: .ray),
    ] + halcyonCrew.indices.map { i in
        Shot(scene: .assimilation(i), text: i == 0
             ? "Drones beam aboard. One by one, the crew is taken. Captain Elena Vasquez is first."
             : "\(halcyonCrew[i].rank) \(halcyonCrew[i].name)…", sfx: .transporter)
    } + [
        Shot(scene: .allDrones, speaker: "The Borg", text: "Six of six. The Halcyon is assimilated.", voice: .borg),
        Shot(scene: .bridge(.halcyonCaptain), speaker: "Distress call", text: "…Halcyon to any Federation ship… Borg… they're taking us one by one… please…", voice: .woman, sfx: .chirp),
        Shot(scene: .bridge(.cube), speaker: "Decker", text: "That's six of ours on that cube. Red alert. We're going to get them back.", voice: .matt, sfx: .alert),
    ]

    static func mission3Won(rescued: Int) -> [Shot] {
        var s: [Shot] = [
            Shot(scene: .cubeDestroyed, text: "The cube buckles, then erupts in a chain of green-white explosions.", sfx: .explosion),
        ]
        if rescued > 0 {
            s.append(Shot(scene: .sickbay(rescued), text: rescued == halcyonCrew.count
                          ? "In sickbay at Starbase 74, the last implants come out. All six women of the Halcyon are themselves again."
                          : "In sickbay at Starbase 74, the implants come out. \(rescued) of the Halcyon's six are themselves again."))
            s.append(Shot(scene: .sickbay(rescued), speaker: "Captain Vasquez", text: "Captain Decker… I remember everything. Thank you for not giving up on us.", voice: .woman))
        } else {
            s.append(Shot(scene: .bridge(.stars), speaker: "Decker", text: "The cube is gone… but so is the Halcyon's crew. Log it, and let's go home.", voice: .matt))
        }
        return s
    }
}
