import SwiftUI

/// Classic handheld-era front-sprite inspired Pokémon buddies.
/// Priority: recognizability at tiny notch size (silhouette + palette + key organs).
enum PokemonBuddyKind: Sendable {
    case snorlax
    case gengar
    case psyduck
}

struct PokemonBuddyPixelView: View {
    let kind: PokemonBuddyKind

    private static let gridSize = 20
    private static let P: CGFloat = 2.4
    static let canvasSize: CGFloat = CGFloat(gridSize) * P

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, _ in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let bob = sin(t * 3.2) * 0.28
                drawSprite(context: &context, yOffset: bob)
            }
            .frame(width: Self.canvasSize, height: Self.canvasSize)
        }
    }

    private func px(_ ctx: inout GraphicsContext, x: Int, y: Int, c: Color, yOffset: Double = 0) {
        guard x >= 0, x < Self.gridSize, y >= 0, y < Self.gridSize else { return }
        let rect = CGRect(
            x: Double(x) * Double(Self.P),
            y: (Double(y) + yOffset) * Double(Self.P),
            width: Double(Self.P),
            height: Double(Self.P)
        )
        ctx.fill(Path(rect), with: .color(c))
    }

    private func drawMapped(
        _ context: inout GraphicsContext,
        rows: [String],
        palette: [Character: Color],
        yOffset: Double
    ) {
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                if let c = palette[ch] {
                    px(&context, x: x, y: y, c: c, yOffset: yOffset)
                }
            }
        }
    }

    private func drawSprite(context: inout GraphicsContext, yOffset: Double) {
        switch kind {
        case .snorlax: drawSnorlax(context: &context, yOffset: yOffset)
        case .gengar: drawGengar(context: &context, yOffset: yOffset)
        case .psyduck: drawPsyduck(context: &context, yOffset: yOffset)
        }
    }

    private func drawSnorlax(context: inout GraphicsContext, yOffset: Double) {
        let p: [Character: Color] = [
            "K": Color(red: 0.10, green: 0.11, blue: 0.13), // outline
            "N": Color(red: 0.19, green: 0.36, blue: 0.41), // body navy/teal
            "L": Color(red: 0.29, green: 0.50, blue: 0.56), // body light
            "B": Color(red: 0.92, green: 0.83, blue: 0.67), // belly
            "E": Color(red: 0.98, green: 0.94, blue: 0.86), // belly highlight
            "M": Color(red: 0.27, green: 0.20, blue: 0.18)  // mouth
        ]

        let rows = [
            "....................",
            ".......KKKKKK.......",
            ".....KKNNNNNNKK.....",
            "....KNNNNNNNNNNK....",
            "...KNNLNNNNNNLNNK...",
            "..KNNNNNNKKNNNNNNK..",
            "..KNNNNNBBBBNNNNNK..",
            "..KNNNBBBBBBBBNNNK..",
            ".KNNNBBBBEEBBBBNNNK.",
            ".KNNBBBBBBBBBBBBNNK.",
            ".KNNBBBBBMMBBBBBNNK.",
            ".KNNBBBBBBBBBBBBNNK.",
            "..KNNBBBBBBBBBBNNK..",
            "..KNNNBBBBBBBBNNNK..",
            "...KNNNNBBBBNNNNK...",
            "....KNNNNNNNNNNK....",
            ".....KNNNKKNNNK.....",
            "......KNNK..KNNK....",
            ".......KK....KK.....",
            "...................."
        ]

        drawMapped(&context, rows: rows, palette: p, yOffset: yOffset)
    }

    private func drawGengar(context: inout GraphicsContext, yOffset: Double) {
        let p: [Character: Color] = [
            "A": Color(red: 0.361, green: 0.400, blue: 0.620),
            "B": Color(red: 0.400, green: 0.435, blue: 0.655),
            "C": Color(red: 0.439, green: 0.463, blue: 0.690),
            "D": Color(red: 0.510, green: 0.533, blue: 0.765),
            "E": Color(red: 0.494, green: 0.514, blue: 0.745),
            "F": Color(red: 0.827, green: 0.843, blue: 0.839),
            "G": Color(red: 0.580, green: 0.608, blue: 0.812),
            "H": Color(red: 0.659, green: 0.694, blue: 0.890),
            "I": Color(red: 0.569, green: 0.592, blue: 0.804),
            "J": Color(red: 0.624, green: 0.659, blue: 0.859),
            "K": Color(red: 0.627, green: 0.635, blue: 0.847),
            "L": Color(red: 0.620, green: 0.643, blue: 0.851),
            "M": Color(red: 0.435, green: 0.463, blue: 0.686),
            "N": Color(red: 0.424, green: 0.451, blue: 0.675),
            "O": Color(red: 0.627, green: 0.631, blue: 0.847),
            "P": Color(red: 0.404, green: 0.439, blue: 0.663)
        ]

        let rows = [
            "....D...............",
            "....G...............",
            "....EJH.....OK......",
            "....BILDABABNF......",
            "....EDECEDCADA...FFF",
            ".DIGFIGLJHEDAABGHJDA",
            ".BNCADGJJHIDAAAHHEE.",
            "..ACBEDJJHICAAANCB..",
            "...ABDKIKIEAAAAME...",
            "D..LPPFAMAAAAEAN....",
            "...LCBAAAAAGFAABPCMG",
            "...LC.BAAACFEBABACEI",
            "...GC..HAAABBAAAEK..",
            "...GEA.F....AABF....",
            "..KMBAAAF.FAAAA.....",
            "..HOAAAAAAAAGA......",
            "..AIAAAAAAAKOK......",
            "...FB.AAAALLCC......",
            ".......AADDCCC......",
            "..........CAAM......"
        ]

        drawMapped(&context, rows: rows, palette: p, yOffset: yOffset)
    }

    private func drawPsyduck(context: inout GraphicsContext, yOffset: Double) {
        let p: [Character: Color] = [
            "K": Color(red: 0.220, green: 0.165, blue: 0.106), // dark brown (outline/eyes)
            "Y": Color(red: 0.784, green: 0.584, blue: 0.169), // yellow (beak)
            "W": Color(red: 0.992, green: 0.992, blue: 0.969), // white/cream (face)
            "L": Color(red: 0.733, green: 0.686, blue: 0.510)  // light brown (skin)
        ]

        let rows = [
            "WWWWWWWWWWWWWWWWWWWW",
            "WWWWWWW.LWWWWWWWWWWW",
            "WWWWWWW.KWWWWWWWWWWW",
            "WWWWWWYYYYYYYWWWWWWW",
            "WWWWYYYYYYYYWLWWWWWW",
            "WWWYYYWWWYYWWYYWWWWW",
            "WWYYYYYYYWWWWYYWWWWW",
            "W.YYYYY.WWWWWWYWWWWW",
            "WYYYYY.YWWWWWWWWWWWW",
            "WWYYYYYYWWWWWWWWWWWW",
            "WWYYYYYYYLWWWWLWWWWW",
            "WWYYYYYYYYYYYYWWWWWW",
            "WWYYYYYYYYYYYYWWWWWW",
            "WWWYYYYYYYYYYYYYWWWW",
            "WWWWWYYYYYYYYYYWWWWW",
            "WWWWWYYYYYYYYWWWWWWW",
            "WWW.WWWWYYLWWWWWWWWW",
            "WWWWWWWWWWWWWWWWWWWW",
            "WWWWWWWWWWWWWWWWWWWW",
            "WWWWWWWWWWWWWWWWWWWW"
        ]

        drawMapped(&context, rows: rows, palette: p, yOffset: yOffset)
    }
}
