import SwiftUI

struct SortButton: View {
  let label: String
  let key: ProcessSortKey
  @Binding var currentKey: ProcessSortKey
  @Binding var ascending: Bool
  let action: () -> Void

  var body: some View {
    Button {
      if currentKey == key {
        ascending.toggle()
      } else {
        currentKey = key
        ascending = false
      }
      action()
    } label: {
      HStack(spacing: 2) {
        Text(label)
          .font(.system(size: 10, weight: currentKey == key ? .bold : .medium))
        if currentKey == key {
          Image(systemName: ascending ? "chevron.up" : "chevron.down")
            .font(.system(size: 8))
        }
      }
      .foregroundColor(currentKey == key ? .primary : .secondary)
    }
    .buttonStyle(.plain)
  }
}
