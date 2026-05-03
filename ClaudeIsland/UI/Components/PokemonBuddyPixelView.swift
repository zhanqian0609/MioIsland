import SwiftUI

/// Classic handheld-era front-sprite inspired Pokémon buddies.
/// Priority: recognizability at tiny notch size (silhouette + palette + key organs).
enum PokemonBuddyKind: Sendable {
    case snorlax
    case pikachu
    case bulbasaur
    case charmander
    case squirtle
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
        case .pikachu: drawPikachu(context: &context, yOffset: yOffset)
        case .bulbasaur: drawBulbasaur(context: &context, yOffset: yOffset)
        case .charmander: drawCharmander(context: &context, yOffset: yOffset)
        case .squirtle: drawSquirtle(context: &context, yOffset: yOffset)
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

    private func drawPikachu(context: inout GraphicsContext, yOffset: Double) {
        let p: [Character: Color] = [
            "K": Color(red: 0.10, green: 0.10, blue: 0.10),   // outline / ear tips
            "Y": Color(red: 0.98, green: 0.86, blue: 0.27),   // base yellow
            "L": Color(red: 1.00, green: 0.93, blue: 0.58),   // highlight
            "R": Color(red: 0.90, green: 0.26, blue: 0.30),   // cheeks
            "B": Color(red: 0.56, green: 0.36, blue: 0.22)    // tail brown root
        ]

        let rows = [
            "....................",
            "....K.........K.....",
            "....KK.......KK.....",
            ".....KYYYYYYYK......",
            "....KYYYYYYYYYK.....",
            "....YYYYYYYYYYY.....",
            "...KYYYYYYYYYYYK....",
            "...YYYYLYYYLYYYY....",
            "..KYYYKYYYYYKYYYK...",
            "..YYYYYYK.KYYYYYY...",
            "..YYYRYYYYYYYRYYY...",
            "...YYYYYYYYYYYYY....",
            "....YYYYYYYYYYY.....",
            ".....YYYYYYYYY......",
            "......YY...YY.......",
            "......YY...YY.......",
            "...BB.BB............",
            "..BBBBBB............",
            "....BBBB............",
            "...................."
        ]

        drawMapped(&context, rows: rows, palette: p, yOffset: yOffset)
    }

    private func drawBulbasaur(context: inout GraphicsContext, yOffset: Double) {
        let p: [Character: Color] = [
            "K": Color(red: 0.11, green: 0.12, blue: 0.12),
            "S": Color(red: 0.45, green: 0.78, blue: 0.73),   // skin
            "L": Color(red: 0.62, green: 0.88, blue: 0.82),   // skin light
            "D": Color(red: 0.29, green: 0.58, blue: 0.54),   // spots/shadow
            "U": Color(red: 0.43, green: 0.70, blue: 0.37),   // bulb
            "V": Color(red: 0.58, green: 0.82, blue: 0.50),   // bulb light
            "R": Color(red: 0.82, green: 0.22, blue: 0.27)    // eyes
        ]

        let rows = [
            "....................",
            ".......UUUUU........",
            "......UUVVVUU.......",
            "......UUUUUUU.......",
            ".....KUSSSSSUK......",
            "....KSSSSSSSSSK.....",
            "...KSSSLSSSLSSSK....",
            "...SSSSSSSSSSSSS....",
            "..KSSSKSSRSSKSSSK...",
            "..SSSDSSSKSSSDSSS...",
            "..SSSSSSSSSSSSSSS...",
            "...SSSDSSSSSDSSS....",
            "....SSSSSSSSSSS.....",
            ".....SSSSSSSSS......",
            "......SSS..SS.......",
            "......SS....SS......",
            "....................",
            "....................",
            "....................",
            "...................."
        ]

        drawMapped(&context, rows: rows, palette: p, yOffset: yOffset)
    }

    private func drawCharmander(context: inout GraphicsContext, yOffset: Double) {
        let p: [Character: Color] = [
            "K": Color(red: 0.11, green: 0.10, blue: 0.10),
            "O": Color(red: 0.95, green: 0.56, blue: 0.28),
            "L": Color(red: 0.99, green: 0.69, blue: 0.41),
            "B": Color(red: 0.99, green: 0.87, blue: 0.65),
            "F": Color(red: 0.99, green: 0.78, blue: 0.22),
            "I": Color(red: 1.00, green: 0.95, blue: 0.72)
        ]

        let rows = [
            "....................",
            "........OO..........",
            "......KOOOOK........",
            ".....KOOOLOOK.......",
            ".....OOOOOOOOK......",
            "....KOOOOOOOOO......",
            "....OOOOK.OOOO......",
            "...KOOOBBBBOOOK.....",
            "...OOOOBBBBOOOO.....",
            "...OOOOBBBBOOOO.....",
            "....OOOOOOOOOO......",
            ".....OOOOOOOO.......",
            "......OOOOOO........",
            ".......OOO..........",
            ".......OO...........",
            "........OOO....F....",
            ".........OOOO.FFI...",
            "..........OOO..F....",
            "....................",
            "...................."
        ]

        drawMapped(&context, rows: rows, palette: p, yOffset: yOffset)
    }

    private func drawSquirtle(context: inout GraphicsContext, yOffset: Double) {
        let p: [Character: Color] = [
            "K": Color(red: 0.11, green: 0.12, blue: 0.13),
            "C": Color(red: 0.50, green: 0.79, blue: 0.93),
            "L": Color(red: 0.68, green: 0.89, blue: 0.97),
            "H": Color(red: 0.74, green: 0.53, blue: 0.34),
            "E": Color(red: 0.56, green: 0.40, blue: 0.27),
            "B": Color(red: 0.94, green: 0.88, blue: 0.73)
        ]

        let rows = [
            "....................",
            "........CCC.........",
            "......KCCCCCK.......",
            ".....KCCCLLCCK......",
            ".....CCCHHHCCC......",
            "....KCCHEEEHCCK.....",
            "....CCCHEB EHCCC....",
            "...KCCCHEBBEHCCCK...",
            "...CCCCHBBBBHCCCC...",
            "...CCCCHEEEHCCCC....",
            "....CCCCCHHCCCCC....",
            ".....CCCCCCCCCC.....",
            "......CCCCCCCC......",
            ".......CC..CC.......",
            ".......CC...CC......",
            "............CCC.....",
            ".............CCC....",
            "..............CC....",
            "....................",
            "...................."
        ].map { $0.replacingOccurrences(of: " ", with: "") }

        drawMapped(&context, rows: rows, palette: p, yOffset: yOffset)
    }
}
