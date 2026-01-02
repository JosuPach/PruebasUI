import SwiftUI

struct SliderWithLabel: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChangedFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(label).foregroundColor(.white)
            Slider(value: $value, in: range, step: 1) { editing in
                if !editing {
                    onEditingChangedFinished()
                }
            }
        }
    }
}
