import SwiftUI

struct ProcessRow: View {
  let name: String
  let count: Int
  let color: Color

  var body: some View {
    HStack {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text(name)
        .font(.system(size: 12, design: .monospaced))
      Spacer()
      Text("\(count)")
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundColor(.secondary)
    }
  }
}
