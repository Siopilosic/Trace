import SwiftUI

/// Hours + minutes wheels for editing a duration — an activity entry's actual
/// length, or a goal's target length. Shared so there's one duration input
/// across the app.
struct DurationEditor: View {
    @Binding var seconds: Double

    private var hours: Int { Int(seconds) / 3600 }
    private var minutes: Int { (Int(seconds) % 3600) / 60 }

    var body: some View {
        HStack {
            Picker("Hours", selection: Binding(
                get: { hours },
                set: { seconds = Double($0 * 3600 + minutes * 60) }
            )) {
                ForEach(0..<13) { Text("\($0)h").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Minutes", selection: Binding(
                get: { minutes },
                set: { seconds = Double(hours * 3600 + $0 * 60) }
            )) {
                ForEach(0..<60) { Text("\($0)m").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
    }
}
