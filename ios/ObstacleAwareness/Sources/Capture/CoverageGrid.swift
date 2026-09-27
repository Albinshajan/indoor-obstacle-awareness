import SwiftUI

/// Live coverage-per-distance-cell readout for the selected class, so gaps
/// are visible while shooting rather than discovered back at a desk.
struct CoverageGrid: View {
    let counts: [Int: Int]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CaptureProtocol.distancesMM, id: \.self) { mm in
                VStack(spacing: 2) {
                    Text(String(format: "%.1fm", Double(mm) / 1000.0))
                        .font(.system(size: 9))
                    Text("\(counts[mm] ?? 0)")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 20)
                        .background((counts[mm] ?? 0) > 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}
