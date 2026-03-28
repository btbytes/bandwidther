import SwiftUI

struct BarView: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.1))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.5))
                    .frame(width: max(0, geo.size.width * CGFloat(min(fraction, 1.0))))
            }
        }
        .frame(height: 4)
    }
}
