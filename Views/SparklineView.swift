import SwiftUI

struct SparklineView: View {
  let data: [Double]
  let color: Color

  var body: some View {
    GeometryReader { geo in
      let maxVal = data.max() ?? 0
      let hasData = maxVal > 0
      let w = geo.size.width
      let h = geo.size.height

      if data.count > 1 {
        Path { path in
          for (i, val) in data.enumerated() {
            let x = w * CGFloat(i) / CGFloat(data.count - 1)
            let y = hasData ? h - (h * CGFloat(val / maxVal)) : h
            if i == 0 {
              path.move(to: CGPoint(x: x, y: y))
            } else {
              path.addLine(to: CGPoint(x: x, y: y))
            }
          }
        }
        .stroke(color, lineWidth: 1.5)

        Path { path in
          path.move(to: CGPoint(x: 0, y: h))
          for (i, val) in data.enumerated() {
            let x = w * CGFloat(i) / CGFloat(data.count - 1)
            let y = hasData ? h - (h * CGFloat(val / maxVal)) : h
            if i == 0 {
              path.addLine(to: CGPoint(x: x, y: y))
            } else {
              path.addLine(to: CGPoint(x: x, y: y))
            }
          }
          path.addLine(to: CGPoint(x: w, y: h))
          path.closeSubpath()
        }
        .fill(color.opacity(0.15))
      }
    }
  }
}
