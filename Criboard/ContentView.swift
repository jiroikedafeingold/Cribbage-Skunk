//
//  ContentView.swift
//  Criboard
//
//  Created by Jiro on 5/26/26.
//

import SwiftUI

// MARK: - Game Model

enum CribbagePlayer {
    case one, two
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
    .init(id: "coral",  displayName: "Coral",
          primary: Color(red: 0.98, green: 0.45, blue: 0.28),
          deep:    Color(red: 0.78, green: 0.22, blue: 0.14)),
    .init(id: "sky",    displayName: "Sky",
          primary: Color(red: 0.32, green: 0.74, blue: 0.96),
          deep:    Color(red: 0.16, green: 0.45, blue: 0.78)),
    .init(id: "plum",   displayName: "Plum",
          primary: Color(red: 0.68, green: 0.45, blue: 0.96),
          deep:    Color(red: 0.42, green: 0.22, blue: 0.78)),
    .init(id: "mint",   displayName: "Mint",
          primary: Color(red: 0.40, green: 0.85, blue: 0.55),
          deep:    Color(red: 0.18, green: 0.55, blue: 0.30)),
    .init(id: "rose",   displayName: "Rose",
          primary: Color(red: 0.98, green: 0.50, blue: 0.72),
          deep:    Color(red: 0.75, green: 0.22, blue: 0.50)),
    .init(id: "gold",   displayName: "Gold",
          primary: Color(red: 0.96, green: 0.78, blue: 0.30),
          deep:    Color(red: 0.72, green: 0.52, blue: 0.10)),
    .init(id: "teal",   displayName: "Teal",
          primary: Color(red: 0.25, green: 0.80, blue: 0.78),
          deep:    Color(red: 0.10, green: 0.50, blue: 0.55)),
    .init(id: "ivory",  displayName: "Ivory",
          primary: Color(red: 0.94, green: 0.94, blue: 0.92),
          deep:    Color(red: 0.55, green: 0.55, blue: 0.55)),
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

    // In-memory (undo only spans current session)
    @State private var p1History: [Int] = []
    @State private var p2History: [Int] = []
    @State private var showSettings: Bool = false

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

            GeometryReader { geo in
                let panelW: CGFloat = 82
                let h = geo.size.height

                HStack(spacing: 0) {
                    // Player 1 — left side
                    PlayerPanel(
                        title: p1Name,
                        score: p1Score,
                        primary: p1Theme.primary,
                        deep: p1Theme.deep,
                        disabled: winner != nil,
                        canUndo: !p1History.isEmpty,
                        onAdd: { amount in addPoints(amount, to: .one) },
                        onPlusOne: { addPoints(1, to: .one) },
                        onUndo: { undo(.one) }
                    )
                    .frame(width: h, height: panelW)
                    .rotationEffect(.degrees(90))
                    .frame(width: panelW, height: h)

                    CribbageBoardView(
                        p1Score: p1Score,
                        p2Score: p2Score,
                        p1Name: p1Name,
                        p2Name: p2Name,
                        p1Theme: p1Theme,
                        p2Theme: p2Theme
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 8)

                    // Player 2 — right side
                    PlayerPanel(
                        title: p2Name,
                        score: p2Score,
                        primary: p2Theme.primary,
                        deep: p2Theme.deep,
                        disabled: winner != nil,
                        canUndo: !p2History.isEmpty,
                        onAdd: { amount in addPoints(amount, to: .two) },
                        onPlusOne: { addPoints(1, to: .two) },
                        onUndo: { undo(.two) }
                    )
                    .frame(width: h, height: panelW)
                    .rotationEffect(.degrees(-90))
                    .frame(width: panelW, height: h)
                }
            }

            // Settings entry point — small gear at top center, a comfortable distance from the board
            VStack {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.35))
                                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.6))
                        )
                }
                .padding(.top, 28)
                Spacer()
            }
            .zIndex(5)

            if let winner {
                WinnerOverlay(
                    winner: winner,
                    skunk: skunk,
                    winnerTheme: winner == .one ? p1Theme : p2Theme,
                    winnerName: winner == .one ? p1Name : p2Name,
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
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                p1Name: $p1Name,
                p2Name: $p2Name,
                p1ColorID: $p1ColorID,
                p2ColorID: $p2ColorID,
                onResetScores: {
                    reset()
                    showSettings = false
                },
                onDismiss: { showSettings = false }
            )
        }
    }

    private func addPoints(_ amount: Int, to player: CribbagePlayer) {
        guard winner == nil, amount > 0 else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            switch player {
            case .one:
                let applied = min(121 - p1Score, amount)
                guard applied > 0 else { return }
                p1Score += applied
                p1History.append(applied)
                if p1Score >= 121 {
                    winnerRaw = "one"
                    skunkRaw = computeSkunk(loserScore: p2Score).rawKey
                }
            case .two:
                let applied = min(121 - p2Score, amount)
                guard applied > 0 else { return }
                p2Score += applied
                p2History.append(applied)
                if p2Score >= 121 {
                    winnerRaw = "two"
                    skunkRaw = computeSkunk(loserScore: p1Score).rawKey
                }
            }
        }
    }

    private func undo(_ player: CribbagePlayer) {
        guard winner == nil else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            switch player {
            case .one:
                guard let last = p1History.popLast() else { return }
                p1Score = max(0, p1Score - last)
            case .two:
                guard let last = p2History.popLast() else { return }
                p2Score = max(0, p2Score - last)
            }
        }
    }

    private func computeSkunk(loserScore: Int) -> SkunkLevel {
        if loserScore < 61 { return .double }
        if loserScore < 91 { return .single }
        return .none
    }

    private func reset() {
        p1Score = 0
        p2Score = 0
        p1History.removeAll()
        p2History.removeAll()
        winnerRaw = ""
        skunkRaw = "none"
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
    let onAdd: (Int) -> Void
    let onPlusOne: () -> Void
    let onUndo: () -> Void

    @State private var pending: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            // Name
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize()

            // +N pending pill
            Text("+\(pending)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [primary, deep], startPoint: .top, endPoint: .bottom)
                )
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(pending)))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(primary.opacity(0.16))
                        .overlay(Capsule().stroke(primary.opacity(0.5), lineWidth: 1))
                )
                .fixedSize()

            // Slider (flex)
            PointsSlider(value: $pending, primary: primary, deep: deep) { amount in
                onAdd(amount)
            }
            .frame(height: 40)
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1.0)

            // +1
            Button {
                onPlusOne()
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            } label: {
                Text("+1")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(primary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(primary.opacity(0.16))
                            .overlay(Circle().stroke(primary.opacity(0.55), lineWidth: 1))
                    )
            }
            .disabled(disabled)
            .opacity(disabled ? 0.35 : 1.0)

            // Undo
            Button {
                onUndo()
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
            .disabled(!canUndo || disabled)
            .opacity((!canUndo || disabled) ? 0.30 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        .padding(.horizontal, 8)
    }
}

// MARK: - Points Slider

struct PointsSlider: View {
    @Binding var value: Int
    let primary: Color
    let deep: Color
    let onCommit: (Int) -> Void

    @State private var isDragging: Bool = false
    @State private var tickHaptic = UIImpactFeedbackGenerator(style: .light)

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
                            isDragging = true
                            tickHaptic.prepare()
                        }
                        let x = max(0, min(usable, g.location.x - knobSize / 2))
                        let p = x / max(usable, 1)
                        let newValue = Int((p * CGFloat(maxValue)).rounded())
                        if newValue != value {
                            value = newValue
                            tickHaptic.impactOccurred(intensity: 0.75)
                            tickHaptic.prepare()
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        let committed = value
                        if committed > 0 {
                            onCommit(committed)
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                                value = 0
                            }
                        }
                    }
            )
        }
        .onAppear { tickHaptic.prepare() }
    }
}

// MARK: - Cribbage Board (vertical)

struct CribbageBoardView: View {
    let p1Score: Int
    let p2Score: Int
    let p1Name: String
    let p2Name: String
    let p1Theme: PlayerTheme
    let p2Theme: PlayerTheme

    @State private var symbolFaceAngle: Double = 90

    var body: some View {
        GeometryReader { geo in
            let padV: CGFloat = 16
            let padH: CGFloat = 12
            let nameZoneH: CGFloat = 88
            let pegSize: CGFloat = 22
            let trackSpacing: CGFloat = 64
            let trackH = geo.size.height - padV * 2 - nameZoneH - 8

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

                VStack(spacing: 8) {
                    // Player name labels at the top of each track, rotated toward each player
                    HStack(spacing: trackSpacing) {
                        Text(p1Name)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(p1Theme.primary.opacity(0.95))
                            .shadow(color: p1Theme.primary.opacity(0.5), radius: 6)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize()
                            .rotationEffect(.degrees(90))
                            .frame(width: 18, height: nameZoneH)
                        Text(p2Name)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(p2Theme.primary.opacity(0.95))
                            .shadow(color: p2Theme.primary.opacity(0.5), radius: 6)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize()
                            .rotationEffect(.degrees(-90))
                            .frame(width: 18, height: nameZoneH)
                    }

                    // Tracks + skunk markers
                    ZStack {
                        Group {
                            SkunkMarker(
                                progress: 60.0 / 121.0,
                                trackHeight: trackH,
                                pegSize: pegSize,
                                symbol: "🦨🦨",
                                color: .skunkRed,
                                symbolRotation: symbolFaceAngle
                            )
                            SkunkMarker(
                                progress: 90.0 / 121.0,
                                trackHeight: trackH,
                                pegSize: pegSize,
                                symbol: "🦨",
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
                    .frame(height: trackH)
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

// MARK: - Winner Overlay

struct WinnerOverlay: View {
    let winner: CribbagePlayer
    let skunk: SkunkLevel
    let winnerTheme: PlayerTheme
    let winnerName: String
    let onPlayAgain: () -> Void

    @State private var animateIn = false
    @State private var rotate = false
    @State private var pulse = false
    @State private var faceAngle: Double = 90  // alternates between +90 (left player) and -90 (right player)

    private var winnerColor: Color { winnerTheme.primary }
    private var winnerLabel: String {
        "\(winnerName.uppercased()) WINS"
    }

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
                    Text(winnerLabel)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(3.2)
                        .foregroundStyle(.white.opacity(0.75))

                    Text(skunk.title)
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

                    Text(skunk.subtitle)
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateIn = true
            }
            rotate = true
            pulse = true
            playHaptics()
        }
        .task {
            // Periodically flip the card so it faces each player in turn
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                faceAngle = (faceAngle == 90) ? -90 : 90
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
            Text("🦨")
                .font(.system(size: 132))
                .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
                .rotationEffect(.degrees(rotate ? 10 : -10))
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: rotate)
        case .double:
            HStack(spacing: -18) {
                Text("🦨")
                    .font(.system(size: 110))
                    .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
                    .rotationEffect(.degrees(rotate ? -18 : -8))
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: rotate)
                Text("🦨")
                    .font(.system(size: 110))
                    .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
                    .rotationEffect(.degrees(rotate ? 18 : 8))
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: rotate)
            }
        }
    }

    private func playHaptics() {
        switch skunk {
        case .none:
            Task {
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
                try? await Task.sleep(for: .milliseconds(140))
                impact.impactOccurred()
                try? await Task.sleep(for: .milliseconds(220))
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
            }
        case .single:
            Task {
                let heavy = UIImpactFeedbackGenerator(style: .heavy)
                let rigid = UIImpactFeedbackGenerator(style: .rigid)
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(110))
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(160))
                rigid.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(260))
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(380))
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
            }
        case .double:
            Task {
                let heavy = UIImpactFeedbackGenerator(style: .heavy)
                let rigid = UIImpactFeedbackGenerator(style: .rigid)
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(90))
                rigid.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(110))
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(130))
                rigid.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(150))
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(180))
                rigid.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(240))
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(320))
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(for: .milliseconds(450))
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
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
                } header: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(playerTheme(for: p2ColorID).primary)
                            .frame(width: 12, height: 12)
                        Text("PLAYER TWO")
                    }
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
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
