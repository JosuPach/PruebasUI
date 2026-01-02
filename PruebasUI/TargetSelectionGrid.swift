import SwiftUI

struct TargetSelectionGrid: View {
    @Binding var targetC: Int
    @Binding var targetD: Int
    let onTargetSelected: (Int, Int) -> Void

    let dValues: [Int] = [255,127,0]
    let cValues: [Int] = [0,64,127,191,255]

    @State private var selectedRow: Int = 1
    @State private var selectedCol: Int = 2

    var body: some View {
        VStack(spacing: 8) {
            ForEach(dValues.indices, id: \.self) { row in
                HStack {
                    Text("D:\(String(format: "%03d", dValues[row]))").frame(width: 44)
                    ForEach(cValues.indices, id: \.self) { col in
                        Circle()
                            .frame(width: 30, height: 30)
                            .overlay(
                                Group {
                                    if selectedRow == row && selectedCol == col {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            )
                            .onTapGesture {
                                selectedRow = row
                                selectedCol = col
                                let newD = dValues[row]
                                let newC = cValues[col]
                                targetD = newD
                                targetC = newC
                                onTargetSelected(newC, newD)
                            }
                    }
                }
            }
        }
    }
}
