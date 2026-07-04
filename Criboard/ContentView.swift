//
//  ContentView.swift
//  Criboard
//
//  Created by Jiro on 5/26/26.
//

import SwiftUI
import CoreHaptics

// MARK: - Loser Symbols (configurable from settings)

struct LoserSymbol: Identifiable, Hashable {
    let id: String
    let char: String
    let displayName: String
}

let loserSymbols: [LoserSymbol] = [
    .init(id: "skunk",   char: "🦨", displayName: "Skunk"),
    .init(id: "poop",    char: "💩", displayName: "Poop"),
    .init(id: "snail",   char: "🐌", displayName: "Snail"),
    .init(id: "turtle",  char: "🐢", displayName: "Turtle"),
    .init(id: "clown",   char: "🤡", displayName: "Clown"),
    .init(id: "chicken", char: "🐔", displayName: "Chicken"),
    .init(id: "frog",    char: "🐸", displayName: "Frog"),
    .init(id: "rat",     char: "🐀", displayName: "Rat"),
    .init(id: "pig",     char: "🐷", displayName: "Pig"),
    .init(id: "monkey",  char: "🐵", displayName: "Monkey"),
    .init(id: "alien",   char: "👽", displayName: "Alien"),
    .init(id: "ogre",    char: "👹", displayName: "Ogre"),
    .init(id: "ghost",   char: "👻", displayName: "Ghost"),
    .init(id: "snake",   char: "🐍", displayName: "Snake"),
    .init(id: "octopus", char: "🐙", displayName: "Octopus"),
    .init(id: "lizard",  char: "🦎", displayName: "Lizard"),
    .init(id: "worm",    char: "🪱", displayName: "Worm"),
    .init(id: "crab",    char: "🦀", displayName: "Crab"),
    .init(id: "dragon",  char: "🐉", displayName: "Dragon"),
    .init(id: "rabbit",  char: "🐇", displayName: "Rabbit"),
    .init(id: "mouse",   char: "🐭", displayName: "Mouse"),
    .init(id: "panda",   char: "🐼", displayName: "Panda"),
    .init(id: "shark",   char: "🦈", displayName: "Shark"),
    .init(id: "duck",    char: "🦆", displayName: "Duck"),
    .init(id: "owl",     char: "🦉", displayName: "Owl"),
    .init(id: "tomato",  char: "🍅", displayName: "Tomato"),
    .init(id: "skull",   char: "💀", displayName: "Skull"),
]

let randomSymbolID = "random"

func resolvedLoserChar(id: String, sessionChar: String) -> String {
    if id == randomSymbolID {
        // Use the previously rolled session char (or default if empty)
        return sessionChar.isEmpty ? "🦨" : sessionChar
    }
    return loserSymbols.first(where: { $0.id == id })?.char ?? "🦨"
}

func rollRandomLoserChar() -> String {
    loserSymbols.randomElement()?.char ?? "🦨"
}

// MARK: - Haptics

final class WinHaptics {
    static let shared = WinHaptics()
    private var engine: CHHapticEngine?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in }
        } catch {
            engine = nil
        }
    }

    func play(skunk: SkunkLevel) {
        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            // Fallback for devices without Core Haptics
            let n = UINotificationFeedbackGenerator()
            n.notificationOccurred(.success)
            return
        }

        let (duration, ramps): (Double, [(Double, Float)])
        switch skunk {
        case .none:
            duration = 1.2
            ramps = [(0.0, 0.55), (0.6, 0.85), (1.2, 0.0)]
        case .single:
            duration = 1.8
            ramps = [(0.0, 0.7), (0.6, 0.95), (1.2, 1.0), (1.8, 0.0)]
        case .double:
            duration = 2.6
            ramps = [(0.0, 0.7), (0.5, 0.9), (1.0, 1.0), (1.8, 1.0), (2.6, 0.0)]
        }

        var events: [CHHapticEvent] = []

        // Long continuous rumble
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
            ],
            relativeTime: 0,
            duration: duration
        )
        events.append(continuous)

        // Punctuating sharp transients on top of the continuous rumble
        let beats: [Double]
        switch skunk {
        case .none:   beats = [0.0, 0.4, 0.9]
        case .single: beats = [0.0, 0.3, 0.6, 1.0, 1.4]
        case .double: beats = [0.0, 0.25, 0.5, 0.8, 1.1, 1.5, 1.9, 2.3]
        }
        for t in beats {
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: t
                )
            )
        }

        // Dynamic intensity ramp for the rumble
        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: ramps.map { CHHapticParameterCurve.ControlPoint(relativeTime: $0.0, value: $0.1) },
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: [intensityCurve])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            let n = UINotificationFeedbackGenerator()
            n.notificationOccurred(.success)
        }
    }
}

// MARK: - Drag Tick Haptics

/// Per-step feedback for the points slider. Uses Core Haptics so the tick can
/// scale in strength as the number climbs — starting on a firm floor and, at the
/// top, stacking a deep low-sharpness transient so it punches past the ceiling of
/// a single UIKit impact. Falls back to escalating UIImpactFeedbackGenerators.
final class DragTickHaptics {
    static let shared = DragTickHaptics()

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    private let fallbackMedium = UIImpactFeedbackGenerator(style: .medium)
    private let fallbackHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let fallbackRigid = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
            engine?.stoppedHandler = { _ in }
        } catch {
            engine = nil
        }
    }

    func prepare() {
        fallbackMedium.prepare(); fallbackHeavy.prepare(); fallbackRigid.prepare()
        try? engine?.start()
    }

    /// - Parameter progress: 0...1 position of the value along the track.
    func tick(progress: Double) {
        let p = min(1, max(0, progress))

        guard supportsHaptics, let engine else {
            fallbackTick(p)
            return
        }

        // Firm floor (0.85) rising to full; sharpness climbs so high numbers bite.
        let intensity = Float(0.85 + 0.15 * p)
        let sharpness = Float(0.4 + 0.6 * p)
        var events: [CHHapticEvent] = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
        ]
        if p >= 0.85 {
            // Toward the top, stack everything at full intensity for the hardest
            // possible hit: a deep body transient, a short full-strength continuous
            // rumble for weight, and a second sharp crack a hair later.
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.05)
                    ],
                    relativeTime: 0
                )
            )
            events.append(
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0,
                    duration: 0.09
                )
            )
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0.015
                )
            )
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallbackTick(p)
        }
    }

    private func fallbackTick(_ p: Double) {
        if p >= 0.85 {
            fallbackHeavy.impactOccurred(intensity: 1.0)
            fallbackRigid.impactOccurred(intensity: 1.0)
            fallbackHeavy.prepare(); fallbackRigid.prepare()
        } else if p >= 0.5 {
            fallbackHeavy.impactOccurred(intensity: CGFloat(0.85 + 0.15 * p))
            fallbackHeavy.prepare()
        } else {
            fallbackMedium.impactOccurred(intensity: CGFloat(0.85 + 0.15 * p))
            fallbackMedium.prepare()
        }
    }
}

// MARK: - Game Model

enum CribbagePlayer {
    case one, two

    var key: String {
        switch self {
        case .one: return "one"
        case .two: return "two"
        }
    }
}

struct ScoreMove: Codable, Hashable {
    let player: String  // "one" or "two"
    let amount: Int
}

enum SkunkLevel {
    case none, single, double

    var title: String {
        switch self {
        case .none: return "VICTORY"
        case .single: return "SKUNKED!"
        case .double: return "DOUBLE SKUNK!"
        }
    }

    var subtitle: String {
        switch self {
        case .none: return "Well played"
        case .single: return "A clean sweep"
        case .double: return "An absolute thrashing"
        }
    }

    var accentColors: [Color] {
        switch self {
        case .none: return [.cribGold, Color(red: 1.0, green: 0.85, blue: 0.45)]
        case .single: return [Color(red: 1.0, green: 0.75, blue: 0.25), Color(red: 1.0, green: 0.45, blue: 0.15)]
        case .double: return [Color(red: 1.0, green: 0.35, blue: 0.45), Color(red: 0.85, green: 0.20, blue: 0.65), Color(red: 0.45, green: 0.30, blue: 0.95)]
        }
    }

    var rawKey: String {
        switch self {
        case .none: return "none"
        case .single: return "single"
        case .double: return "double"
        }
    }
}

// MARK: - Palette

extension Color {
    static let feltDark  = Color(red: 0.05, green: 0.13, blue: 0.10)
    static let feltMid   = Color(red: 0.09, green: 0.20, blue: 0.15)
    static let cribGold  = Color(red: 0.94, green: 0.79, blue: 0.45)
    static let skunkRed  = Color(red: 0.96, green: 0.40, blue: 0.32)
    static let skunkOrange = Color(red: 1.0, green: 0.70, blue: 0.30)
}

// MARK: - Player Themes

struct PlayerTheme: Identifiable, Hashable {
    let id: String
    let displayName: String
    let primary: Color
    let deep: Color
}

let playerThemes: [PlayerTheme] = [
    .init(id: "crimson",   displayName: "Crimson",
          primary: Color(red: 1.00, green: 0.18, blue: 0.28),
          deep:    Color(red: 0.78, green: 0.06, blue: 0.14)),
    .init(id: "coral",     displayName: "Coral",
          primary: Color(red: 1.00, green: 0.50, blue: 0.30),
          deep:    Color(red: 0.82, green: 0.30, blue: 0.10)),
    .init(id: "tangerine", displayName: "Tangerine",
          primary: Color(red: 1.00, green: 0.62, blue: 0.10),
          deep:    Color(red: 0.85, green: 0.40, blue: 0.04)),
    .init(id: "gold",      displayName: "Gold",
          primary: Color(red: 1.00, green: 0.85, blue: 0.15),
          deep:    Color(red: 0.78, green: 0.58, blue: 0.02)),
    .init(id: "lime",      displayName: "Lime",
          primary: Color(red: 0.55, green: 0.95, blue: 0.18),
          deep:    Color(red: 0.30, green: 0.65, blue: 0.08)),
    .init(id: "mint",      displayName: "Mint",
          primary: Color(red: 0.16, green: 0.92, blue: 0.50),
          deep:    Color(red: 0.05, green: 0.62, blue: 0.30)),
    .init(id: "teal",      displayName: "Teal",
          primary: Color(red: 0.10, green: 0.88, blue: 0.85),
          deep:    Color(red: 0.02, green: 0.55, blue: 0.62)),
    .init(id: "sky",       displayName: "Sky",
          primary: Color(red: 0.18, green: 0.66, blue: 1.00),
          deep:    Color(red: 0.06, green: 0.36, blue: 0.85)),
    .init(id: "indigo",    displayName: "Indigo",
          primary: Color(red: 0.40, green: 0.36, blue: 1.00),
          deep:    Color(red: 0.20, green: 0.16, blue: 0.80)),
    .init(id: "plum",      displayName: "Plum",
          primary: Color(red: 0.78, green: 0.28, blue: 1.00),
          deep:    Color(red: 0.55, green: 0.10, blue: 0.80)),
    .init(id: "magenta",   displayName: "Magenta",
          primary: Color(red: 1.00, green: 0.22, blue: 0.82),
          deep:    Color(red: 0.78, green: 0.06, blue: 0.58)),
    .init(id: "rose",      displayName: "Rose",
          primary: Color(red: 1.00, green: 0.45, blue: 0.68),
          deep:    Color(red: 0.82, green: 0.20, blue: 0.45)),
]

func playerTheme(for id: String) -> PlayerTheme {
    playerThemes.first(where: { $0.id == id }) ?? playerThemes[0]
}

// MARK: - Root View

struct ContentView: View {
    // Persisted across launches
    @AppStorage("p1Score") private var p1Score: Int = 0
    @AppStorage("p2Score") private var p2Score: Int = 0
    @AppStorage("p1Name") private var p1Name: String = "PLAYER ONE"
    @AppStorage("p2Name") private var p2Name: String = "PLAYER TWO"
    @AppStorage("p1ColorID") private var p1ColorID: String = "coral"
    @AppStorage("p2ColorID") private var p2ColorID: String = "sky"
    @AppStorage("winnerRaw") private var winnerRaw: String = ""
    @AppStorage("skunkRaw") private var skunkRaw: String = "none"
    @AppStorage("movesData") private var movesData: String = "[]"
    @AppStorage("p1Confirm") private var p1Confirm: Bool = false
    @AppStorage("p2Confirm") private var p2Confirm: Bool = false
    @AppStorage("p1PlusConfirm") private var p1PlusConfirm: Bool = false
    @AppStorage("p2PlusConfirm") private var p2PlusConfirm: Bool = false
    @AppStorage("loserSymbolID") private var loserSymbolID: String = "skunk"
    @AppStorage("randomLoserChar") private var randomLoserChar: String = "🦨"
    @AppStorage("replayMoves") private var replayMoves: Bool = true

    // Session-only
    @State private var showSettings: Bool = false
    @State private var isReplaying: Bool = false

    private var loserChar: String {
        resolvedLoserChar(id: loserSymbolID, sessionChar: randomLoserChar)
    }

    private var moves: [ScoreMove] {
        guard let data = movesData.data(using: .utf8),
              let arr = try? JSONDecoder().decode([ScoreMove].self, from: data)
        else { return [] }
        return arr
    }

    private func setMoves(_ newMoves: [ScoreMove]) {
        if let data = try? JSONEncoder().encode(newMoves),
           let str = String(data: data, encoding: .utf8) {
            movesData = str
        }
    }

    private func canUndo(_ player: CribbagePlayer) -> Bool {
        moves.contains(where: { $0.player == player.key })
    }

    private var p1Theme: PlayerTheme { playerTheme(for: p1ColorID) }
    private var p2Theme: PlayerTheme { playerTheme(for: p2ColorID) }

    private var winner: CribbagePlayer? {
        switch winnerRaw {
        case "one": return .one
        case "two": return .two
        default:    return nil
        }
    }

    private var skunk: SkunkLevel {
        switch skunkRaw {
        case "single": return .single
        case "double": return .double
        default:       return .none
        }
    }

    var body: some View {
        GeometryReader { rootGeo in
            let landscape = rootGeo.size.width > rootGeo.size.height

            ZStack {
                // Felt table background
                LinearGradient(
                    colors: [.feltDark, .feltMid, .feltDark],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.white.opacity(0.06), .clear],
                    center: .center, startRadius: 30, endRadius: 500
                )
                .ignoresSafeArea()
                .blendMode(.plusLighter)

                Group {
                    if landscape {
                        landscapeLayout(height: rootGeo.size.height)
                    } else {
                        portraitLayout(height: rootGeo.size.height)
                    }
                }

                // Settings entry point — positioned at the "0" end of the tracks, between the two pegs
                Group {
                    if landscape {
                        // Tracks start at the left edge; both pegs sit at x=0 stacked vertically.
                        // Place the gear at the left-center of the board, between them.
                        HStack {
                            settingsButton(large: true)
                                .padding(.leading, 30)
                            Spacer()
                        }
                    } else {
                        // Tracks start at the bottom; both pegs sit at y=0 side by side.
                        VStack {
                            Spacer()
                            settingsButton(large: false)
                                .padding(.bottom, 18)
                        }
                    }
                }
                .zIndex(5)

                if let winner, !isReplaying {
                    WinnerOverlay(
                        winner: winner,
                        skunk: skunk,
                        winnerTheme: winner == .one ? p1Theme : p2Theme,
                        winnerName: winner == .one ? p1Name : p2Name,
                        loserChar: loserChar,
                        landscape: landscape,
                        onPlayAgain: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                reset()
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .zIndex(10)
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                p1Name: $p1Name,
                p2Name: $p2Name,
                p1ColorID: $p1ColorID,
                p2ColorID: $p2ColorID,
                p1Confirm: $p1Confirm,
                p2Confirm: $p2Confirm,
                p1PlusConfirm: $p1PlusConfirm,
                p2PlusConfirm: $p2PlusConfirm,
                loserSymbolID: $loserSymbolID,
                randomLoserChar: $randomLoserChar,
                replayMoves: $replayMoves,
                onResetScores: {
                    reset()
                    showSettings = false
                },
                onDismiss: { showSettings = false }
            )
        }
    }

    // MARK: - Layouts

    private func settingsButton(large: Bool) -> some View {
        let iconSize: CGFloat = large ? 28 : 14
        let frameSize: CGFloat = large ? 60 : 32
        return Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: frameSize, height: frameSize)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.6))
                )
        }
    }

    @ViewBuilder
    private func portraitLayout(height: CGFloat) -> some View {
        let panelW: CGFloat = 82
        HStack(spacing: 0) {
            // Player 1 — left side
            PlayerPanel(
                title: p1Name,
                score: p1Score,
                primary: p1Theme.primary,
                deep: p1Theme.deep,
                disabled: winner != nil || isReplaying,
                canUndo: canUndo(.one),
                requireConfirm: p1Confirm,
                requirePlusConfirm: p1PlusConfirm,
                onAdd: { amount in addPoints(amount, to: .one) },
                onPlusOne: { addPoints(1, to: .one) },
                onUndo: { undo(.one) }
            )
            .frame(width: height, height: panelW)
            .rotationEffect(.degrees(90))
            .frame(width: panelW, height: height)

            CribbageBoardView(
                p1Score: p1Score,
                p2Score: p2Score,
                p1Theme: p1Theme,
                p2Theme: p2Theme,
                loserChar: loserChar
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)

            // Player 2 — right side
            PlayerPanel(
                title: p2Name,
                score: p2Score,
                primary: p2Theme.primary,
                deep: p2Theme.deep,
                disabled: winner != nil || isReplaying,
                canUndo: canUndo(.two),
                requireConfirm: p2Confirm,
                requirePlusConfirm: p2PlusConfirm,
                onAdd: { amount in addPoints(amount, to: .two) },
                onPlusOne: { addPoints(1, to: .two) },
                onUndo: { undo(.two) }
            )
            .frame(width: height, height: panelW)
            .rotationEffect(.degrees(-90))
            .frame(width: panelW, height: height)
        }
    }

    @ViewBuilder
    private func landscapeLayout(height: CGFloat) -> some View {
        // Player panels sized as a portion of the screen height for tablet-friendly tap targets
        let panelH: CGFloat = max(110, min(150, height * 0.16))
        VStack(spacing: 8) {
            // Player 2 — top edge, rotated 180° to face the player sitting at the top
            PlayerPanel(
                title: p2Name,
                score: p2Score,
                primary: p2Theme.primary,
                deep: p2Theme.deep,
                disabled: winner != nil || isReplaying,
                canUndo: canUndo(.two),
                requireConfirm: p2Confirm,
                requirePlusConfirm: p2PlusConfirm,
                onAdd: { amount in addPoints(amount, to: .two) },
                onPlusOne: { addPoints(1, to: .two) },
                onUndo: { undo(.two) }
            )
            .frame(height: panelH)
            .rotationEffect(.degrees(180))

            HorizontalCribbageBoardView(
                p1Score: p1Score,
                p2Score: p2Score,
                p1Theme: p1Theme,
                p2Theme: p2Theme,
                loserChar: loserChar
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)

            // Player 1 — bottom edge, normal orientation
            PlayerPanel(
                title: p1Name,
                score: p1Score,
                primary: p1Theme.primary,
                deep: p1Theme.deep,
                disabled: winner != nil || isReplaying,
                canUndo: canUndo(.one),
                requireConfirm: p1Confirm,
                requirePlusConfirm: p1PlusConfirm,
                onAdd: { amount in addPoints(amount, to: .one) },
                onPlusOne: { addPoints(1, to: .one) },
                onUndo: { undo(.one) }
            )
            .frame(height: panelH)
        }
    }

    // MARK: - Game state mutations

    private func addPoints(_ amount: Int, to player: CribbagePlayer) {
        guard winner == nil, !isReplaying, amount > 0 else { return }

        // Compute how much we can actually apply (capped at 121).
        let applied: Int
        switch player {
        case .one: applied = min(121 - p1Score, amount)
        case .two: applied = min(121 - p2Score, amount)
        }
        guard applied > 0 else { return }

        // Apply the score and record the move
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            switch player {
            case .one: p1Score += applied
            case .two: p2Score += applied
            }
        }
        var current = moves
        current.append(ScoreMove(player: player.key, amount: applied))
        setMoves(current)

        // Win check
        let didWin = (player == .one ? p1Score : p2Score) >= 121
        if didWin {
            let loserScore = player == .one ? p2Score : p1Score
            winnerRaw = player.key
            skunkRaw = computeSkunk(loserScore: loserScore).rawKey

            // Replay the entire game on the board before showing the winner card
            if replayMoves {
                Task { await runReplay() }
            }
        }
    }

    private func undo(_ player: CribbagePlayer) {
        guard winner == nil, !isReplaying else { return }
        var current = moves
        guard let idx = current.lastIndex(where: { $0.player == player.key }) else { return }
        let removed = current.remove(at: idx)
        setMoves(current)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            switch player {
            case .one: p1Score = max(0, p1Score - removed.amount)
            case .two: p2Score = max(0, p2Score - removed.amount)
            }
        }
    }

    private func runReplay() async {
        isReplaying = true
        // Let the player see the winning peg position for a beat
        try? await Task.sleep(for: .milliseconds(750))

        let snapshot = moves

        // Reset pegs to 0 — the replay starts from the opening hand
        withAnimation(.easeInOut(duration: 0.45)) {
            p1Score = 0
            p2Score = 0
        }
        try? await Task.sleep(for: .milliseconds(550))

        let tick = UIImpactFeedbackGenerator(style: .light)
        tick.prepare()

        for move in snapshot {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                if move.player == "one" {
                    p1Score = min(121, p1Score + move.amount)
                } else {
                    p2Score = min(121, p2Score + move.amount)
                }
            }
            tick.impactOccurred(intensity: 0.55)
            tick.prepare()
            try? await Task.sleep(for: .milliseconds(180))
        }

        // Pause on the final position before the celebration takes over
        try? await Task.sleep(for: .milliseconds(700))
        isReplaying = false
    }

    private func computeSkunk(loserScore: Int) -> SkunkLevel {
        if loserScore < 61 { return .double }
        if loserScore < 91 { return .single }
        return .none
    }

    private func reset() {
        p1Score = 0
        p2Score = 0
        winnerRaw = ""
        skunkRaw = "none"
        setMoves([])
        if loserSymbolID == randomSymbolID {
            randomLoserChar = rollRandomLoserChar()
        }
    }
}

// MARK: - Player Panel

struct PlayerPanel: View {
    let title: String
    let score: Int
    let primary: Color
    let deep: Color
    let disabled: Bool
    let canUndo: Bool
    let requireConfirm: Bool
    let requirePlusConfirm: Bool
    let onAdd: (Int) -> Void
    let onPlusOne: () -> Void
    let onUndo: () -> Void

    @State private var pending: Int = 0
    @State private var sliderIsDragging: Bool = false

    // +1 taps accumulate here. With "confirm after +1" the score isn't applied
    // until the batch is committed (by tapping the settled number, or auto-accept);
    // otherwise the score is added per tap and this is just the running display count.
    @State private var plusPending: Int = 0
    @State private var plusSettled: Bool = false   // confirm mode: taps paused, a tap now commits
    @State private var plusTask: Task<Void, Never>? = nil

    // Firmer feedback for the +1 button.
    @State private var plusHeavy = UIImpactFeedbackGenerator(style: .heavy)
    @State private var plusRigid = UIImpactFeedbackGenerator(style: .rigid)

    // Drives the slow, refined "breathing" glow while a number is on show.
    @State private var glowPulse: Bool = false

    private let plusSettleDelay: TimeInterval = 0.8      // pause after which a tap commits
    private let plusAutoAcceptDelay: TimeInterval = 2.2  // total idle before auto-accept

    // True when the slider has settled on a value and we're waiting for the user to confirm it.
    private var awaitingConfirm: Bool {
        requireConfirm && pending > 0 && !sliderIsDragging
    }

    // True when +1 taps are staged and waiting to be committed.
    private var awaitingPlusConfirm: Bool {
        requirePlusConfirm && plusPending > 0
    }

    // The number rendered on the combined left button.
    private var displayValue: Int {
        if sliderIsDragging || awaitingConfirm { return pending }
        if plusPending > 0 { return plusPending }
        return 1
    }

    // The button reads bright/high-contrast whenever it shows anything but "+1".
    private var showingElevatedValue: Bool { displayValue != 1 }
    // Identical high-contrast treatment during a drag, the slider's settled state,
    // and a staged +1 batch, so the look never shifts between them.
    private var highlighted: Bool { showingElevatedValue || awaitingConfirm || awaitingPlusConfirm }

    // A firmer press than the old light tick.
    private func firePlusHaptic() {
        plusHeavy.impactOccurred(intensity: 1.0)
        plusHeavy.prepare()
    }

    // A heavier "locked in" thump for a commit.
    private func fireCommitHaptic() {
        plusHeavy.impactOccurred(intensity: 1.0)
        plusRigid.impactOccurred(intensity: 1.0)
        plusHeavy.prepare(); plusRigid.prepare()
    }

    private func handlePlusTap() {
        if requirePlusConfirm {
            // Once the batch has settled, a tap confirms it rather than adding more.
            if plusSettled {
                commitPlus()
                return
            }
            firePlusHaptic()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { plusPending += 1 }
            schedulePlusConfirm()
        } else {
            // Add immediately; the running count is display-only.
            firePlusHaptic()
            onPlusOne()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { plusPending += 1 }
            scheduleStreakReset()
        }
    }

    // Confirm mode: after a short pause the batch becomes tap-to-commit; after a
    // longer idle it auto-accepts on its own.
    private func schedulePlusConfirm() {
        plusTask?.cancel()
        plusSettled = false
        plusTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(plusSettleDelay))
            guard !Task.isCancelled else { return }
            plusSettled = true
            try? await Task.sleep(for: .seconds(plusAutoAcceptDelay - plusSettleDelay))
            guard !Task.isCancelled else { return }
            commitPlus()
        }
    }

    // Non-confirm mode: just fade the running count away; the score is already in.
    private func scheduleStreakReset() {
        plusTask?.cancel()
        plusTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { plusPending = 0 }
        }
    }

    private func commitPlus() {
        plusTask?.cancel()
        let amount = plusPending
        plusSettled = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { plusPending = 0 }
        if amount > 0 {
            onAdd(amount)
            fireCommitHaptic()
        }
    }

    private func cancelPlus() {
        plusTask?.cancel()
        plusSettled = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { plusPending = 0 }
    }

    var body: some View {
        ZStack {
            // Translucent watermark of the player's name behind the controls
            Text(title.uppercased())
                .font(.system(size: 110, weight: .black, design: .rounded))
                .tracking(10)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(primary.opacity(0.42))
                .shadow(color: primary.opacity(0.55), radius: 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            HStack(spacing: 12) {
                // Combined +1 / +N display button (on the left)
                Button {
                    if awaitingConfirm {
                        let value = pending
                        onAdd(value)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { pending = 0 }
                        fireCommitHaptic()
                    } else if !sliderIsDragging {
                        handlePlusTap()
                    }
                } label: {
                    Text("+\(displayValue)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(
                            highlighted
                            ? AnyShapeStyle(.white)
                            : AnyShapeStyle(LinearGradient(colors: [primary, deep], startPoint: .top, endPoint: .bottom))
                        )
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(displayValue)))
                        .frame(minWidth: 56, minHeight: 44)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(primary.opacity(highlighted ? 0.42 : 0.16))
                                .overlay(
                                    Capsule().stroke(
                                        primary.opacity(highlighted ? 0.95 : 0.55),
                                        lineWidth: highlighted ? 1.6 : 1
                                    )
                                )
                        )
                        .scaleEffect(highlighted ? 1.05 : 1.0)
                        // Tight base halo whenever the button is lit, plus a slow,
                        // refined "breathing" bloom while a number is on show.
                        .shadow(color: primary.opacity(highlighted ? 0.75 : 0.0), radius: 10)
                        .shadow(
                            color: primary.opacity(highlighted ? (glowPulse ? 0.9 : 0.35) : 0.0),
                            radius: highlighted ? (glowPulse ? 24 : 12) : 0
                        )
                        .animation(.easeInOut(duration: 0.22), value: highlighted)
                        .onChange(of: highlighted) { _, isShowing in
                            if isShowing {
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    glowPulse = true
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    glowPulse = false
                                }
                            }
                        }
                }
                .buttonStyle(.plain)
                // Only disabled for real (game over) — NOT during a drag, so the
                // number keeps full brightness. Mid-drag taps are already ignored
                // by the action's `!sliderIsDragging` guard.
                .disabled(disabled)
                .opacity(disabled ? 0.4 : 1.0)
                .onAppear { plusHeavy.prepare(); plusRigid.prepare() }

                // Slider (flex)
                PointsSlider(
                    value: $pending,
                    isDragging: $sliderIsDragging,
                    primary: primary,
                    deep: deep
                ) { committed in
                    if !requireConfirm {
                        // Auto-commit and reset
                        onAdd(committed)
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            pending = 0
                        }
                    }
                    // In confirm mode, keep `pending` set; the left button becomes the commit
                }
                .frame(height: 44)
                .disabled(disabled)
                .opacity(disabled ? 0.4 : 1.0)

                // Undo (also clears any pending confirmation)
                Button {
                    if pending > 0 {
                        // Cancel a pending slider confirmation instead of undoing
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { pending = 0 }
                    } else if awaitingPlusConfirm {
                        // Cancel a staged +1 batch before it's committed
                        cancelPlus()
                    } else {
                        onUndo()
                    }
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        )
                }
                .disabled((!canUndo && pending == 0 && !awaitingPlusConfirm) || disabled)
                .opacity(((!canUndo && pending == 0 && !awaitingPlusConfirm) || disabled) ? 0.30 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 8)
    }
}

// MARK: - Points Slider

struct PointsSlider: View {
    @Binding var value: Int
    @Binding var isDragging: Bool
    let primary: Color
    let deep: Color
    let onCommit: (Int) -> Void

    @State private var dragStartValue: Int = 0

    private let maxValue = 29

    var body: some View {
        GeometryReader { geo in
            let knobSize: CGFloat = 32
            let trackHeight: CGFloat = 10
            let usable = geo.size.width - knobSize
            let progress = CGFloat(value) / CGFloat(maxValue)
            let knobX = progress * usable

            ZStack(alignment: .leading) {
                // Track background — flat modern
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: trackHeight)

                // Tick marks — minimal
                HStack(spacing: 0) {
                    ForEach(0...maxValue, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(i % 5 == 0 ? 0.28 : 0.0))
                            .frame(width: 1, height: i % 5 == 0 ? 6 : 0)
                        if i < maxValue { Spacer(minLength: 0) }
                    }
                }
                .padding(.horizontal, knobSize / 2)

                // Filled portion — clean gradient
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [deep, primary],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(trackHeight, knobX + knobSize / 2), height: trackHeight)

                // Knob — modern flat circle with subtle glow
                ZStack {
                    Circle()
                        .fill(.white)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [primary.opacity(0.0), primary.opacity(0.25)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                .frame(width: knobSize, height: knobSize)
                .scaleEffect(isDragging ? 1.12 : 1.0)
                .shadow(color: primary.opacity(0.5), radius: isDragging ? 14 : 8)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                .offset(x: knobX)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: value)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !isDragging {
                            // Track relative to where the knob was when the drag began, so
                            // the knob follows the finger 1:1 (no teleport) and fast flicks
                            // stay put — translation is reliable at any speed and survives
                            // the panel's rotation, unlike an absolute-location hit test.
                            isDragging = true
                            dragStartValue = value
                            DragTickHaptics.shared.prepare()
                        }
                        let stepWidth = usable / CGFloat(maxValue)
                        let delta = Int((g.translation.width / max(stepWidth, 1)).rounded())
                        let newValue = min(maxValue, max(0, dragStartValue + delta))
                        if newValue != value {
                            value = newValue
                            DragTickHaptics.shared.tick(progress: Double(newValue) / Double(maxValue))
                        }
                    }
                    .onEnded { _ in
                        guard isDragging else { return }
                        isDragging = false
                        // Commit exactly where the knob was released — no snap-back.
                        if value > 0 {
                            onCommit(value)
                        }
                    }
            )
        }
        .onAppear { DragTickHaptics.shared.prepare() }
    }
}

// MARK: - Cribbage Board (vertical)

struct CribbageBoardView: View {
    let p1Score: Int
    let p2Score: Int
    let p1Theme: PlayerTheme
    let p2Theme: PlayerTheme
    let loserChar: String

    @State private var symbolFaceAngle: Double = 90

    private var doubleLoser: String { loserChar + loserChar }

    var body: some View {
        GeometryReader { geo in
            let padV: CGFloat = 16
            let padH: CGFloat = 12
            let pegSize: CGFloat = 22
            let trackSpacing: CGFloat = 64
            let trackH = geo.size.height - padV * 2

            ZStack {
                // Lighter board surface for stronger skunk contrast
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.32), Color(white: 0.20)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 18, y: 8)

                ZStack {
                    Group {
                        SkunkMarker(
                            progress: 60.0 / 121.0,
                            trackHeight: trackH,
                            pegSize: pegSize,
                            symbol: doubleLoser,
                            color: .skunkRed,
                            symbolRotation: symbolFaceAngle
                        )
                        SkunkMarker(
                            progress: 90.0 / 121.0,
                            trackHeight: trackH,
                            pegSize: pegSize,
                            symbol: loserChar,
                            color: .skunkOrange,
                            symbolRotation: symbolFaceAngle
                        )
                        SkunkMarker(
                            progress: 1.0,
                            trackHeight: trackH,
                            pegSize: pegSize,
                            symbol: "👑",
                            color: .cribGold,
                            isFinish: true,
                            symbolRotation: symbolFaceAngle
                        )
                    }
                    .padding(.horizontal, padH)

                    HStack(spacing: trackSpacing) {
                        PlayerTrack(
                            score: p1Score,
                            rotation: 90,
                            color: p1Theme.primary,
                            deep: p1Theme.deep,
                            trackHeight: trackH,
                            pegSize: pegSize,
                            scoreOnLeading: true
                        )
                        PlayerTrack(
                            score: p2Score,
                            rotation: -90,
                            color: p2Theme.primary,
                            deep: p2Theme.deep,
                            trackHeight: trackH,
                            pegSize: pegSize,
                            scoreOnLeading: false
                        )
                    }
                }
                .padding(.vertical, padV)
            }
            .task {
                // Periodically flip the board's symbols so they face each player in turn
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3.5))
                    withAnimation(.easeInOut(duration: 0.7)) {
                        symbolFaceAngle = (symbolFaceAngle == 90) ? -90 : 90
                    }
                }
            }
        }
    }
}

struct PlayerTrack: View {
    let score: Int
    let rotation: Double
    let color: Color
    let deep: Color
    let trackHeight: CGFloat
    let pegSize: CGFloat
    let scoreOnLeading: Bool

    var body: some View {
        let progress = CGFloat(min(score, 121)) / 121.0
        let usable = trackHeight - pegSize

        ZStack(alignment: .bottom) {
            // Track groove
            Capsule()
                .fill(Color.white.opacity(0.10))
                .frame(width: 6)

            // Filled trail (grows upward from bottom)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [deep, color],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: 6, height: max(0, progress * usable + pegSize / 2))
                .shadow(color: color.opacity(0.55), radius: 6)

            // Peg + floating score (constrained so the score doesn't expand layout)
            ZStack {
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: pegSize + 14, height: pegSize + 14)
                    .blur(radius: 8)
                Circle()
                    .fill(color)
                    .frame(width: pegSize, height: pegSize)
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 2)
                    .frame(width: pegSize, height: pegSize)

                Text("\(score)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(score)))
                    .shadow(color: color.opacity(0.85), radius: 10)
                    .shadow(color: .black.opacity(0.65), radius: 5)
                    .fixedSize()
                    .rotationEffect(.degrees(rotation))
                    .offset(x: scoreOnLeading ? -46 : 46)
            }
            .frame(width: pegSize, height: pegSize)
            .offset(y: -progress * usable)
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: score)
        }
        .frame(width: pegSize, height: trackHeight)
    }
}

struct SkunkMarker: View {
    let progress: CGFloat
    let trackHeight: CGFloat
    let pegSize: CGFloat
    let symbol: String
    let color: Color
    var isFinish: Bool = false
    let symbolRotation: Double

    var body: some View {
        let usable = trackHeight - pegSize
        let yFromTop = trackHeight - (pegSize / 2 + progress * usable)

        VStack(spacing: 0) {
            Spacer().frame(height: yFromTop)

            ZStack {
                Rectangle()
                    .fill(color.opacity(isFinish ? 0.85 : 0.55))
                    .frame(height: isFinish ? 2 : 1)

                Text(symbol)
                    .font(.system(size: isFinish ? 30 : 24))
                    .shadow(color: .black.opacity(0.55), radius: 5, y: 2)
                    .rotationEffect(.degrees(symbolRotation))
            }
            .frame(height: 38)
            .offset(y: -19)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Horizontal Cribbage Board (iPad landscape)

struct HorizontalCribbageBoardView: View {
    let p1Score: Int
    let p2Score: Int
    let p1Theme: PlayerTheme
    let p2Theme: PlayerTheme
    let loserChar: String

    @State private var symbolFaceAngle: Double = 0  // 0 = bottom player, 180 = top player

    private var doubleLoser: String { loserChar + loserChar }

    var body: some View {
        GeometryReader { geo in
            let padH: CGFloat = 48
            let padV: CGFloat = 28
            let pegSize: CGFloat = 36
            let scoreFontSize: CGFloat = 64
            let scoreOffset: CGFloat = 72
            let symbolFontSize: CGFloat = 68
            let crownFontSize: CGFloat = 80
            let trackW = geo.size.width - padH * 2

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.32), Color(white: 0.20)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 18, y: 8)

                ZStack {
                    Group {
                        HorizontalSkunkMarker(
                            progress: 60.0 / 121.0,
                            trackWidth: trackW,
                            pegSize: pegSize,
                            symbol: doubleLoser,
                            color: .skunkRed,
                            symbolFontSize: symbolFontSize,
                            symbolRotation: symbolFaceAngle
                        )
                        HorizontalSkunkMarker(
                            progress: 90.0 / 121.0,
                            trackWidth: trackW,
                            pegSize: pegSize,
                            symbol: loserChar,
                            color: .skunkOrange,
                            symbolFontSize: symbolFontSize,
                            symbolRotation: symbolFaceAngle
                        )
                        HorizontalSkunkMarker(
                            progress: 1.0,
                            trackWidth: trackW,
                            pegSize: pegSize,
                            symbol: "👑",
                            color: .cribGold,
                            isFinish: true,
                            symbolFontSize: crownFontSize,
                            symbolRotation: symbolFaceAngle
                        )
                    }
                    .padding(.vertical, padV)

                    // Player 2 on top, Player 1 on bottom — pushed apart with Spacer so they
                    // use the board's full vertical extent proportionally.
                    VStack(spacing: 0) {
                        HorizontalPlayerTrack(
                            score: p2Score,
                            rotation: 180,
                            color: p2Theme.primary,
                            deep: p2Theme.deep,
                            trackWidth: trackW,
                            pegSize: pegSize,
                            scoreFontSize: scoreFontSize,
                            scoreOffset: scoreOffset,
                            scoreAbove: false
                        )
                        Spacer(minLength: scoreOffset * 2 + pegSize)
                        HorizontalPlayerTrack(
                            score: p1Score,
                            rotation: 0,
                            color: p1Theme.primary,
                            deep: p1Theme.deep,
                            trackWidth: trackW,
                            pegSize: pegSize,
                            scoreFontSize: scoreFontSize,
                            scoreOffset: scoreOffset,
                            scoreAbove: true
                        )
                    }
                    .padding(.vertical, padV)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, padH)
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3.5))
                    withAnimation(.easeInOut(duration: 0.7)) {
                        symbolFaceAngle = (symbolFaceAngle == 0) ? 180 : 0
                    }
                }
            }
        }
    }
}

struct HorizontalPlayerTrack: View {
    let score: Int
    let rotation: Double
    let color: Color
    let deep: Color
    let trackWidth: CGFloat
    let pegSize: CGFloat
    let scoreFontSize: CGFloat
    let scoreOffset: CGFloat
    let scoreAbove: Bool

    var body: some View {
        let progress = CGFloat(min(score, 121)) / 121.0
        let usable = trackWidth - pegSize
        let trackThickness: CGFloat = max(8, pegSize * 0.22)

        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.10))
                .frame(width: trackWidth, height: trackThickness)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [deep, color],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: max(0, progress * usable + pegSize / 2), height: trackThickness)
                .shadow(color: color.opacity(0.55), radius: 8)

            ZStack {
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: pegSize + 20, height: pegSize + 20)
                    .blur(radius: 10)
                Circle()
                    .fill(color)
                    .frame(width: pegSize, height: pegSize)
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 2.5)
                    .frame(width: pegSize, height: pegSize)

                Text("\(score)")
                    .font(.system(size: scoreFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(score)))
                    .shadow(color: color.opacity(0.85), radius: 12)
                    .shadow(color: .black.opacity(0.65), radius: 6)
                    .fixedSize()
                    .rotationEffect(.degrees(rotation))
                    .offset(y: scoreAbove ? -scoreOffset : scoreOffset)
            }
            .frame(width: pegSize, height: pegSize)
            .offset(x: progress * usable)
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: score)
        }
        .frame(width: trackWidth, height: pegSize)
    }
}

struct HorizontalSkunkMarker: View {
    let progress: CGFloat
    let trackWidth: CGFloat
    let pegSize: CGFloat
    let symbol: String
    let color: Color
    var isFinish: Bool = false
    let symbolFontSize: CGFloat
    let symbolRotation: Double

    var body: some View {
        let usable = trackWidth - pegSize
        let xFromLeading = pegSize / 2 + progress * usable
        let cellWidth: CGFloat = symbolFontSize + 24

        HStack(spacing: 0) {
            Spacer().frame(width: xFromLeading)

            ZStack {
                Rectangle()
                    .fill(color.opacity(isFinish ? 0.85 : 0.55))
                    .frame(width: isFinish ? 3 : 1.5)

                Text(symbol)
                    .font(.system(size: symbolFontSize))
                    .shadow(color: .black.opacity(0.55), radius: 8, y: 3)
                    .rotationEffect(.degrees(symbolRotation))
            }
            .frame(width: cellWidth)
            .offset(x: -cellWidth / 2)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Winner Overlay

struct WinnerOverlay: View {
    let winner: CribbagePlayer
    let skunk: SkunkLevel
    let winnerTheme: PlayerTheme
    let winnerName: String
    let loserChar: String
    let landscape: Bool
    let onPlayAgain: () -> Void

    @State private var animateIn = false
    @State private var rotate = false
    @State private var pulse = false
    @State private var faceAngle: Double = 0  // initialized in .onAppear to face the winner first

    // The two angles the card flips between, given the current layout.
    private var winnerAngle: Double {
        if landscape {
            return (winner == .one) ? 0 : 180     // P1 on bottom (0°), P2 on top (180°)
        } else {
            return (winner == .one) ? 90 : -90    // P1 on left (+90°), P2 on right (-90°)
        }
    }
    private var loserAngle: Double {
        if landscape {
            return (winner == .one) ? 180 : 0
        } else {
            return (winner == .one) ? -90 : 90
        }
    }

    private var winnerColor: Color { winnerTheme.primary }

    var body: some View {
        ZStack {
            // Backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(animateIn ? 1 : 0)

            // Animated rays for double skunk
            if skunk == .double {
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let rayCount = 18
                    for i in 0..<rayCount {
                        let angle = Double(i) / Double(rayCount) * .pi * 2 + (rotate ? .pi / 6 : 0)
                        var path = Path()
                        let r1 = 80.0
                        let r2 = max(size.width, size.height)
                        let w = 0.06
                        let p1 = CGPoint(x: center.x + cos(angle - w) * r1, y: center.y + sin(angle - w) * r1)
                        let p2 = CGPoint(x: center.x + cos(angle + w) * r1, y: center.y + sin(angle + w) * r1)
                        let p3 = CGPoint(x: center.x + cos(angle + w * 2) * r2, y: center.y + sin(angle + w * 2) * r2)
                        let p4 = CGPoint(x: center.x + cos(angle - w * 2) * r2, y: center.y + sin(angle - w * 2) * r2)
                        path.move(to: p1)
                        path.addLine(to: p2)
                        path.addLine(to: p3)
                        path.addLine(to: p4)
                        path.closeSubpath()
                        let colors = skunk.accentColors
                        let color = colors[i % colors.count]
                        ctx.fill(path, with: .color(color.opacity(0.18)))
                    }
                }
                .ignoresSafeArea()
                .blendMode(.plusLighter)
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: rotate)
            }

            // Confetti
            ConfettiBurst(colors: skunk == .none ? [winnerColor, .cribGold, .white] : skunk.accentColors)
                .opacity(animateIn ? 1 : 0)

            // Trophy card — content rotates to face each player in turn
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    winnerColor.opacity(0.6),
                                    winnerColor.opacity(0.0)
                                ],
                                center: .center, startRadius: 10, endRadius: 110
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulse ? 1.08 : 0.95)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                    iconView
                }

                VStack(spacing: 6) {
                    Text("\(winnerName.uppercased()) WINS")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(3.2)
                        .foregroundStyle(.white.opacity(0.75))

                    Text(LocalizedStringKey(skunk.title))
                        .font(.system(size: skunk == .double ? 36 : 44, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: skunk == .none ? [.white, .cribGold] : skunk.accentColors,
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .shadow(color: winnerColor.opacity(0.5), radius: 10)

                    Text(LocalizedStringKey(skunk.subtitle))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .italic()
                }

                Button(action: onPlayAgain) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("PLAY AGAIN")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .tracking(2.2)
                    }
                    .foregroundStyle(.black.opacity(0.88))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 13)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cribGold, Color(red: 0.78, green: 0.55, blue: 0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.black.opacity(0.20)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: skunk == .none ? [winnerColor.opacity(0.7), winnerColor.opacity(0.2)] : skunk.accentColors,
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: winnerColor.opacity(0.45), radius: 30, y: 10)
            )
            .scaleEffect(animateIn ? 1 : 0.8)
            .opacity(animateIn ? 1 : 0)
            .rotationEffect(.degrees(faceAngle))
            .animation(.easeInOut(duration: 0.85), value: faceAngle)
        }
        .onAppear {
            // Start facing the player who actually won, then flip back and forth from there.
            faceAngle = winnerAngle
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateIn = true
            }
            rotate = true
            pulse = true
            WinHaptics.shared.play(skunk: skunk)
        }
        .task {
            // Periodically flip the card so it faces each player in turn
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                faceAngle = (faceAngle == winnerAngle) ? loserAngle : winnerAngle
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch skunk {
        case .none:
            Image(systemName: "crown.fill")
                .font(.system(size: 96, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cribGold, Color(red: 0.85, green: 0.65, blue: 0.20)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .rotationEffect(.degrees(rotate ? 6 : -6))
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: rotate)
        case .single:
            Text(loserChar)
                .font(.system(size: 132))
                .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
                .rotationEffect(.degrees(rotate ? 10 : -10))
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: rotate)
        case .double:
            HStack(spacing: -18) {
                Text(loserChar)
                    .font(.system(size: 110))
                    .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
                    .rotationEffect(.degrees(rotate ? -18 : -8))
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: rotate)
                Text(loserChar)
                    .font(.system(size: 110))
                    .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
                    .rotationEffect(.degrees(rotate ? 18 : 8))
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: rotate)
            }
        }
    }
}

// MARK: - Confetti

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let startX: CGFloat
    let endX: CGFloat
    let startRotation: Double
    let endRotation: Double
    let size: CGFloat
    let duration: Double
    let delay: Double
    let shape: Int  // 0 = rect, 1 = circle, 2 = capsule
}

struct ConfettiBurst: View {
    let colors: [Color]
    @State private var animate = false

    private let pieces: [ConfettiPiece]

    init(colors: [Color]) {
        self.colors = colors
        var arr: [ConfettiPiece] = []
        for _ in 0..<70 {
            arr.append(
                ConfettiPiece(
                    color: colors.randomElement() ?? .white,
                    startX: CGFloat.random(in: 0.2...0.8),
                    endX: CGFloat.random(in: 0.0...1.0),
                    startRotation: Double.random(in: 0...360),
                    endRotation: Double.random(in: 360...720),
                    size: CGFloat.random(in: 6...14),
                    duration: Double.random(in: 2.5...4.5),
                    delay: Double.random(in: 0...0.6),
                    shape: Int.random(in: 0...2)
                )
            )
        }
        self.pieces = arr
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    confettiPiece(p)
                        .frame(width: p.size, height: p.size * (p.shape == 0 ? 0.55 : 1.0))
                        .rotationEffect(.degrees(animate ? p.endRotation : p.startRotation))
                        .position(
                            x: (animate ? p.endX : p.startX) * geo.size.width,
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeIn(duration: p.duration).delay(p.delay),
                            value: animate
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }

    @ViewBuilder
    private func confettiPiece(_ p: ConfettiPiece) -> some View {
        switch p.shape {
        case 0: Rectangle().fill(p.color)
        case 1: Circle().fill(p.color)
        default: Capsule().fill(p.color)
        }
    }
}

// MARK: - Settings

struct SettingsSheet: View {
    @Binding var p1Name: String
    @Binding var p2Name: String
    @Binding var p1ColorID: String
    @Binding var p2ColorID: String
    @Binding var p1Confirm: Bool
    @Binding var p2Confirm: Bool
    @Binding var p1PlusConfirm: Bool
    @Binding var p2PlusConfirm: Bool
    @Binding var loserSymbolID: String
    @Binding var randomLoserChar: String
    @Binding var replayMoves: Bool
    let onResetScores: () -> Void
    let onDismiss: () -> Void

    // Local drafts so typing doesn't re-render the whole app on every keystroke
    @State private var draftP1Name: String = ""
    @State private var draftP2Name: String = ""
    @State private var confirmReset: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("Player One", text: $draftP1Name)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit { commitNames() }
                    }
                    ColorSwatchRow(selection: $p1ColorID, opposing: p2ColorID)
                    Toggle("Confirm score after release", isOn: $p1Confirm)
                    Toggle("Confirm score after +1", isOn: $p1PlusConfirm)
                } header: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(playerTheme(for: p1ColorID).primary)
                            .frame(width: 12, height: 12)
                        Text("PLAYER ONE")
                    }
                }

                Section {
                    LabeledContent("Name") {
                        TextField("Player Two", text: $draftP2Name)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit { commitNames() }
                    }
                    ColorSwatchRow(selection: $p2ColorID, opposing: p1ColorID)
                    Toggle("Confirm score after release", isOn: $p2Confirm)
                    Toggle("Confirm score after +1", isOn: $p2PlusConfirm)
                } header: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(playerTheme(for: p2ColorID).primary)
                            .frame(width: 12, height: 12)
                        Text("PLAYER TWO")
                    }
                }

                Section {
                    LoserSymbolPicker(
                        selection: $loserSymbolID,
                        randomChar: $randomLoserChar
                    )
                } header: {
                    Text("LOSER SYMBOL")
                } footer: {
                    Text("Shown on the board at the skunk lines and in the celebration. \"Random\" picks a fresh icon each time you Reset Scores.")
                }

                Section {
                    Toggle("Replay moves after a win", isOn: $replayMoves)
                } header: {
                    Text("END OF GAME")
                } footer: {
                    Text("When on, the board re-pegs the whole game before the winner card appears.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle")
                            Text("Reset Scores")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitNames()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Reset both scores to 0?",
                isPresented: $confirmReset,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive, action: onResetScores)
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                draftP1Name = p1Name
                draftP2Name = p2Name
            }
            .onDisappear { commitNames() }
        }
    }

    private func commitNames() {
        let trimmedOne = draftP1Name.trimmingCharacters(in: .whitespaces)
        let trimmedTwo = draftP2Name.trimmingCharacters(in: .whitespaces)
        if !trimmedOne.isEmpty, trimmedOne != p1Name { p1Name = trimmedOne }
        if !trimmedTwo.isEmpty, trimmedTwo != p2Name { p2Name = trimmedTwo }
    }
}

struct ColorSwatchRow: View {
    @Binding var selection: String
    let opposing: String  // disable picking the other player's color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(playerThemes) { theme in
                        Button {
                            if theme.id != opposing {
                                selection = theme.id
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(theme.primary)
                                    .frame(width: 32, height: 32)
                                    .opacity(theme.id == opposing ? 0.25 : 1.0)
                                if selection == theme.id {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2.5)
                                        .frame(width: 38, height: 38)
                                }
                                if theme.id == opposing {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .disabled(theme.id == opposing)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LoserSymbolPicker: View {
    @Binding var selection: String
    @Binding var randomChar: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                symbolCell(id: randomSymbolID, char: "🎲", label: "Random")
                ForEach(loserSymbols) { sym in
                    symbolCell(id: sym.id, char: sym.char, label: sym.displayName)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }

    private func symbolCell(id: String, char: String, label: String) -> some View {
        let isSelected = selection == id
        return Button {
            selection = id
            if id == randomSymbolID {
                randomChar = rollRandomLoserChar()
            }
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Text(char)
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(isSelected ? 0.22 : 0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(isSelected ? 0.9 : 0.0), lineWidth: 2)
                            )
                    )
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
