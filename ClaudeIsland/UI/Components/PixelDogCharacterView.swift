import SwiftUI

/// Pixel dog face animation engine.
/// Reuses the same 13x11 canvas and AnimationState contract as PixelCharacterView
/// so it can plug into all existing buddy rendering call-sites.
struct PixelDogCharacterView: View {
    let state: AnimationState

    private static let gridW = 13
    private static let gridH = 11
    private static let P: CGFloat = 4
    static let canvasW: CGFloat = CGFloat(gridW) * P
    static let canvasH: CGFloat = CGFloat(gridH) * P

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, _ in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let frame = Int(elapsed * 60)

                drawDogBase(context: &context)
                switch state {
                case .idle:
                    drawIdleEyes(context: &context, frame: frame)
                case .working:
                    drawWorkingEyes(context: &context, frame: frame)
                case .needsYou:
                    drawNeedsYouEyes(context: &context)
                    drawEarWag(context: &context, frame: frame)
                case .thinking:
                    drawThinkingEyes(context: &context)
                    drawBreathingNose(context: &context, frame: frame)
                case .error:
                    drawErrorEyes(context: &context)
                case .done:
                    drawDoneEyes(context: &context)
                }
            }
            .frame(width: Self.canvasW, height: Self.canvasH)
        }
    }

    private func px(_ ctx: inout GraphicsContext, _ x: Int, _ y: Int, _ color: Color, _ alpha: Double = 1.0) {
        guard x >= 0 && x < Self.gridW && y >= 0 && y < Self.gridH else { return }
        let p = Self.P
        let rect = CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: p, height: p)
        ctx.fill(Path(rect), with: .color(color.opacity(alpha)))
    }

    private static let BK = Color(red: 0.10, green: 0.10, blue: 0.10)
    private static let BR = Color(red: 0.90, green: 0.53, blue: 0.24) // shiba orange
    private static let BR2 = Color(red: 0.74, green: 0.40, blue: 0.17) // shadow fur
    private static let CR = Color(red: 0.99, green: 0.94, blue: 0.84) // cream muzzle
    private static let PK = Color(red: 0.98, green: 0.64, blue: 0.66) // nose
    private static let BL = Color(red: 0.97, green: 0.69, blue: 0.75) // blush
    private static let RD = Color(red: 0.93, green: 0.27, blue: 0.27)
    private static let GN = Color(red: 0.29, green: 0.87, blue: 0.50)

    private func drawDogBase(context: inout GraphicsContext) {
        // ears + crown (taller ears + rounder crown)
        // ear tips (taller but not needle-sharp)
        px(&context, 2, 0, Self.BR2)
        px(&context, 10, 0, Self.BR2)

        // ear upper
        px(&context, 1, 1, Self.BR2); px(&context, 2, 1, Self.BR); px(&context, 3, 1, Self.BR2)
        px(&context, 9, 1, Self.BR2); px(&context, 10, 1, Self.BR); px(&context, 11, 1, Self.BR2)

        // ear mid + forehead bridge
        px(&context, 1, 2, Self.BR2); px(&context, 2, 2, Self.BR); px(&context, 3, 2, Self.BR)
        px(&context, 4, 2, Self.BR); px(&context, 5, 2, Self.BR); px(&context, 6, 2, Self.BR)
        px(&context, 7, 2, Self.BR); px(&context, 8, 2, Self.BR)
        px(&context, 9, 2, Self.BR); px(&context, 10, 2, Self.BR); px(&context, 11, 2, Self.BR2)

        // head dome (less flat)
        px(&context, 1, 3, Self.BR2); for x in 2...10 { px(&context, x, 3, Self.BR) }; px(&context, 11, 3, Self.BR2)
        px(&context, 0, 4, Self.BR2); for x in 1...11 { px(&context, x, 4, Self.BR) }; px(&context, 12, 4, Self.BR2)

        // eyes row base
        px(&context, 0, 5, Self.BR2); for x in 1...11 { px(&context, x, 5, Self.BR) }; px(&context, 12, 5, Self.BR2)

        // muzzle + cheeks (wider cream area)
        px(&context, 0, 6, Self.BR2); px(&context, 1, 6, Self.BR); px(&context, 2, 6, Self.CR); px(&context, 3, 6, Self.CR)
        px(&context, 4, 6, Self.CR); px(&context, 5, 6, Self.CR); px(&context, 6, 6, Self.CR); px(&context, 7, 6, Self.CR)
        px(&context, 8, 6, Self.CR); px(&context, 9, 6, Self.CR); px(&context, 10, 6, Self.CR); px(&context, 11, 6, Self.BR); px(&context, 12, 6, Self.BR2)
        px(&context, 2, 6, Self.BL, 0.45)
        px(&context, 10, 6, Self.BL, 0.45)

        // nose row (rounder cheeks, softer side corners)
        px(&context, 1, 7, Self.CR); px(&context, 2, 7, Self.CR); px(&context, 3, 7, Self.CR); px(&context, 4, 7, Self.CR); px(&context, 5, 7, Self.CR)
        px(&context, 6, 7, Self.PK); px(&context, 7, 7, Self.CR); px(&context, 8, 7, Self.CR); px(&context, 9, 7, Self.CR); px(&context, 10, 7, Self.CR); px(&context, 11, 7, Self.CR)

        // chin (rounder arc)
        px(&context, 1, 8, Self.BR2); px(&context, 2, 8, Self.CR); px(&context, 3, 8, Self.CR); px(&context, 4, 8, Self.CR); px(&context, 5, 8, Self.CR)
        px(&context, 7, 8, Self.CR); px(&context, 8, 8, Self.CR); px(&context, 9, 8, Self.CR); px(&context, 10, 8, Self.CR); px(&context, 11, 8, Self.BR2)
        px(&context, 2, 9, Self.BR2); px(&context, 10, 9, Self.BR2)

        // tiny smile corners (Q style)
        px(&context, 5, 8, Self.BK, 0.45)
        px(&context, 7, 8, Self.BK, 0.45)

        // bottom
        px(&context, 3, 9, Self.BR2); px(&context, 4, 9, Self.BR2); px(&context, 5, 9, Self.BR2); px(&context, 6, 9, Self.BR2); px(&context, 7, 9, Self.BR2); px(&context, 8, 9, Self.BR2); px(&context, 9, 9, Self.BR2)
    }

    private func drawIdleEyes(context: inout GraphicsContext, frame: Int) {
        if frame % 90 < 4 {
            px(&context, 5, 5, Self.BR2)
            px(&context, 7, 5, Self.BR2)
        } else {
            px(&context, 5, 5, Self.BK)
            px(&context, 7, 5, Self.BK)
            px(&context, 5, 4, Self.BK, 0.35)
            px(&context, 7, 4, Self.BK, 0.35)
        }
    }

    private func drawWorkingEyes(context: inout GraphicsContext, frame: Int) {
        let dir = (frame / 15) % 3
        switch dir {
        case 0:
            px(&context, 4, 5, Self.BK); px(&context, 6, 5, Self.BK)
        case 2:
            px(&context, 6, 5, Self.BK); px(&context, 8, 5, Self.BK)
        default:
            px(&context, 5, 5, Self.BK); px(&context, 7, 5, Self.BK)
        }
    }

    private func drawNeedsYouEyes(context: inout GraphicsContext) {
        px(&context, 5, 5, Self.BK)
        px(&context, 7, 5, Self.BK)
        px(&context, 5, 4, Self.BK, 0.35)
        px(&context, 7, 4, Self.BK, 0.35)
    }

    private func drawEarWag(context: inout GraphicsContext, frame: Int) {
        if (frame / 14) % 2 == 1 {
            px(&context, 11, 1, Self.BR) // small right-ear wag highlight
        }
    }

    private func drawThinkingEyes(context: inout GraphicsContext) {
        px(&context, 5, 5, Self.BR2)
        px(&context, 7, 5, Self.BR2)
    }

    private func drawBreathingNose(context: inout GraphicsContext, frame: Int) {
        let breathe = 0.5 + sin(Double(frame) * 0.04) * 0.3
        px(&context, 6, 7, Self.PK, breathe)
    }

    private func drawErrorEyes(context: inout GraphicsContext) {
        px(&context, 4, 4, Self.RD, 0.7); px(&context, 6, 4, Self.RD, 0.7)
        px(&context, 5, 5, Self.RD)
        px(&context, 4, 6, Self.RD, 0.7); px(&context, 6, 6, Self.RD, 0.7)

        px(&context, 6, 4, Self.RD, 0.7); px(&context, 8, 4, Self.RD, 0.7)
        px(&context, 7, 5, Self.RD)
        px(&context, 6, 6, Self.RD, 0.7); px(&context, 8, 6, Self.RD, 0.7)
    }

    private func drawDoneEyes(context: inout GraphicsContext) {
        for y in 0..<Self.gridH {
            for x in 0..<Self.gridW {
                px(&context, x, y, Self.GN, 0.08)
            }
        }

        px(&context, 4, 5, Self.GN); px(&context, 6, 5, Self.GN)
        px(&context, 4, 4, Self.GN, 0.6); px(&context, 6, 4, Self.GN, 0.6)
        px(&context, 5, 6, Self.GN)

        px(&context, 6, 5, Self.GN); px(&context, 8, 5, Self.GN)
        px(&context, 6, 4, Self.GN, 0.6); px(&context, 8, 4, Self.GN, 0.6)
        px(&context, 7, 6, Self.GN)
    }
}
