import SwiftUI

struct SectionHeader: View {
  let title: String
  let icon: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
      Text(title)
        .font(.system(size: 13, weight: .semibold))
    }
    .foregroundColor(.primary)
  }
}
