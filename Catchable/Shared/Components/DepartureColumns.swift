import SwiftUI

struct DepartureColumns: View {
    let departures: [Departure]
    let now: Date
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                if index > 0 { Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 1, height: 36) }
                VStack(spacing: 2) {
                    if index < departures.count {
                        Text("\(max(0, Int(ceil(departures[index].date.timeIntervalSince(now) / 60))))")
                            .font(.system(size: 25, weight: .bold)).monospacedDigit()
                        Text("min").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("—").font(.title3)
                        Text(" ").font(.caption)
                    }
                }.frame(maxWidth: .infinity)
            }
        }.accessibilityElement(children: .combine)
    }
}
