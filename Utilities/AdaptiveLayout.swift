//
//  AdaptiveLayout.swift
//  Bullet Tracker
//
//  Size-class-aware helpers (bt-0009). HIG → Layout: design for the full-size
//  window first and only fall back to the compact layout when the full one no
//  longer fits; adapt with size classes, never with device or screen checks.
//  On iPhone Duo the window flips between compact (folded) and regular
//  (unfolded) while the app is running, so these read the environment live.
//

import SwiftUI

/// Lays a collection out as `List` rows: one item per row in a compact
/// width, two side by side (separated by a divider) in a regular width.
///
/// Keeps the system `List` as the container — separators, insets and the
/// grouped style stay exactly as iOS draws them — instead of swapping in a
/// custom card grid. In compact width the output is identical to a plain
/// `ForEach`, so folded-phone layouts don't change.
struct PairedRows<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            ForEach(pairs) { pair in
                HStack(alignment: .center, spacing: 16) {
                    content(pair.first)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let second = pair.second {
                        Divider()
                        content(second)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        // Odd item count: a hidden twin keeps the column widths
                        // and row height identical to a full pair. Verified on
                        // iPad sim: tapping the empty half does nothing, the
                        // visible half navigates. (List still reports the lone
                        // button's accessibility frame as the whole row; that's
                        // List's own behaviour, not a hit-testing problem.)
                        Divider()
                            .hidden() // same width as a real pair → columns stay aligned
                        content(pair.first)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .hidden()
                    }
                }
            }
        } else {
            ForEach(items) { item in
                content(item)
            }
        }
    }

    // MARK: - Pairing

    private struct Pair: Identifiable {
        let first: Item
        let second: Item?
        var id: Item.ID { first.id }
    }

    private var pairs: [Pair] {
        stride(from: 0, to: items.count, by: 2).map { index in
            Pair(
                first: items[index],
                second: index + 1 < items.count ? items[index + 1] : nil
            )
        }
    }
}
