import SwiftUI

struct RateCardView: View {
  let title: String
  let rate: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .foregroundColor(color)
          .font(.system(size: 11))
        Text(title)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.secondary)
      }
      Text(rate)
        .font(.system(size: 20, weight: .bold, design: .monospaced))
        .foregroundColor(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(color.opacity(0.08))
    .cornerRadius(8)
  }
}
