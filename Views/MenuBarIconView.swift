import SwiftUI

struct MenuBarIconView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let mid = h * 0.5

            let upArrow = Path { p in
                p.move(to: CGPoint(x: w * 0.2, y: mid - 1))
                p.addLine(to: CGPoint(x: w * 0.3, y: h * 0.15))
                p.addLine(to: CGPoint(x: w * 0.4, y: mid - 1))
            }
            context.stroke(upArrow, with: .foreground, lineWidth: 1.5)
            let upStem = Path { p in
                p.move(to: CGPoint(x: w * 0.3, y: h * 0.2))
                p.addLine(to: CGPoint(x: w * 0.3, y: h * 0.75))
            }
            context.stroke(upStem, with: .foreground, lineWidth: 1.5)

            let downArrow = Path { p in
                p.move(to: CGPoint(x: w * 0.6, y: mid + 1))
                p.addLine(to: CGPoint(x: w * 0.7, y: h * 0.85))
                p.addLine(to: CGPoint(x: w * 0.8, y: mid + 1))
            }
            context.stroke(downArrow, with: .foreground, lineWidth: 1.5)
            let downStem = Path { p in
                p.move(to: CGPoint(x: w * 0.7, y: h * 0.25))
                p.addLine(to: CGPoint(x: w * 0.7, y: h * 0.8))
            }
            context.stroke(downStem, with: .foreground, lineWidth: 1.5)
        }
        .frame(width: 18, height: 18)
    }
}
