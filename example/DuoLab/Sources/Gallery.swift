import SwiftUI

/// Vertical-bar gallery pages, chosen by launch argument (-bar1 … -bar7). Every item is `.verticalPreferred`
/// unless the page says otherwise.
@available(iOS 27.1, *)
struct Gallery: View {
    let page: String
    @State private var on = false
    @State private var query = ""

    var body: some View {
        if page == "-bar7" {
            TabView {
                Tab("Home", systemImage: "house") { stack }
                Tab("Stats", systemImage: "chart.bar") { Text("Stats") }
                Tab("Settings", systemImage: "gear") { Text("Settings") }
            }
        } else {
            stack
        }
    }

    private var stack: some View {
        NavigationStack {
            List(0..<30, id: \.self) { Text("Row \($0)") }
                .navigationTitle(page)
                .searchable(text: $query, isPresented: .constant(false))
                .toolbar { items }
        }
    }

    private func btn(_ name: String) -> some View {
        Button { } label: { Label(name, systemImage: name) }
    }

    @ToolbarContentBuilder private var overflowA: some ToolbarContent {
        ToolbarItem { btn("1.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("2.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("3.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("4.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("5.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("6.circle") }.axisBehavior(.verticalPreferred)
    }
    @ToolbarContentBuilder private var overflowB: some ToolbarContent {
        ToolbarItem { btn("7.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("8.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("9.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("10.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("11.circle") }.axisBehavior(.verticalPreferred)
        ToolbarItem { btn("12.circle") }.axisBehavior(.verticalPreferred)
    }

    @ToolbarContentBuilder private var items: some ToolbarContent {
        switch page {
        case "-bar1":   // grouping: adjacent = one bubble; fixed spacer splits; group; bottomBar pins
            ToolbarItem { btn("house") }.axisBehavior(.verticalPreferred)
            ToolbarSpacer(.fixed).axisBehavior(.verticalPreferred)
            ToolbarItem { btn("sparkles") }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("character.bubble") }.axisBehavior(.verticalPreferred)
            ToolbarSpacer(.fixed).axisBehavior(.verticalPreferred)
            ToolbarItemGroup { btn("square.and.arrow.up"); btn("trash") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .bottomBar) { btn("pause.fill") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .bottomBar) { btn("stop.fill").tint(.red) }.axisBehavior(.verticalPreferred)

        case "-bar2":   // button styles and shapes
            ToolbarItem { btn("1.circle") }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("2.circle").buttonStyle(.glass) }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("3.circle").buttonStyle(.glassProminent) }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("4.circle").buttonStyle(.bordered) }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("5.circle").buttonStyle(.borderedProminent) }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("6.circle").buttonBorderShape(.roundedRectangle) }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("7.circle").buttonBorderShape(.roundedRectangle).buttonStyle(.glassProminent) }.axisBehavior(.verticalPreferred)
            ToolbarItem {
                Button { } label: {
                    Image(systemName: "8.square.fill").foregroundStyle(.white)
                        .padding(8).background(.blue, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .sharedBackgroundVisibility(.hidden)
            .axisBehavior(.verticalPreferred)

        case "-bar3":   // content kinds
            ToolbarItem { Button("Done") { } }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("square.and.arrow.down").labelStyle(.titleAndIcon) }.axisBehavior(.verticalPreferred)
            ToolbarItem {
                Button { on.toggle() } label: { Label("Star", systemImage: "star").symbolVariant(on ? .fill : .none) }
            }
            .axisBehavior(.verticalPreferred)
            ToolbarItem { btn("mic").tint(.red) }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("xmark").disabled(true) }.axisBehavior(.verticalPreferred)
            ToolbarItem {
                Menu { Button("One") { }; Button("Two") { } } label: { Label("More", systemImage: "ellipsis") }
            }
            .axisBehavior(.verticalPreferred)
            ToolbarItem { Text("12:34").font(.caption.monospacedDigit()) }
                .sharedBackgroundVisibility(.hidden).axisBehavior(.verticalPreferred)
            ToolbarItem { ProgressView().controlSize(.small) }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("bell").badge(3) }.axisBehavior(.verticalPreferred)

        case "-bar4":   // overflow: 12 separate items (builder max is 10 per block, so two halves)
            overflowA
            overflowB

        case "-bar5":   // placements, all verticalPreferred
            ToolbarItem(placement: .topBarLeading) { btn("1.circle") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .principal) { Text("principal") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .topBarTrailing) { btn("3.circle") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .primaryAction) { btn("4.circle") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .secondaryAction) { btn("5.circle") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .confirmationAction) { Button("OK") { } }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { } }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .status) { Text("status") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .navigation) { btn("0.circle") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .bottomBar) { btn("9.circle") }.axisBehavior(.verticalPreferred)

        case "-bar6":   // automatic axis (no axisBehavior) + horizontalOnly + flexible spacer + search
            ToolbarItem { btn("house") }
            ToolbarItem { btn("gear") }.axisBehavior(.horizontalOnly)
            ToolbarItem { btn("sparkles") }.axisBehavior(.verticalPreferred)
            ToolbarSpacer(.flexible).axisBehavior(.verticalPreferred)
            ToolbarItem { btn("stop.fill").tint(.red) }.axisBehavior(.verticalPreferred)
            DefaultToolbarItem(kind: .search, placement: .bottomBar)

        case "-bar8":   // square buttons, few items so nothing overflows
            ToolbarItem { btn("1.circle") }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("2.circle").buttonStyle(.bordered).buttonBorderShape(.roundedRectangle) }.axisBehavior(.verticalPreferred)
            ToolbarItem {
                Button { } label: {
                    Image(systemName: "3.square.fill").foregroundStyle(.white)
                        .frame(width: 36, height: 36).background(.blue, in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .sharedBackgroundVisibility(.hidden).axisBehavior(.verticalPreferred)
            ToolbarItem {
                Button { } label: {
                    Image(systemName: "4.square").frame(width: 36, height: 36)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .sharedBackgroundVisibility(.hidden).axisBehavior(.verticalPreferred)

        default:        // -bar7: tab bar + items
            ToolbarItem { btn("house") }.axisBehavior(.verticalPreferred)
            ToolbarItem { btn("sparkles") }.axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .bottomBar) { btn("stop.fill").tint(.red) }.axisBehavior(.verticalPreferred)
        }
    }
}
