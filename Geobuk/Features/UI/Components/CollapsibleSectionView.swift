import SwiftUI

/// 접기/펼치기 가능한 섹션 뷰
struct CollapsibleSectionView<Content: View>: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    var badge: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    Image(systemName: systemImage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.5))
                            .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }
}
