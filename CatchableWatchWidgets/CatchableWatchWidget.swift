import SwiftUI
import WidgetKit

@main
struct CatchableWatchWidgetBundle: WidgetBundle {
    var body: some Widget { CatchableWatchWidget() }
}

struct CatchableWatchWidget: Widget {
    let kind = "CatchableWatchDepartures"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CatchableTimelineProvider()) { entry in
            WatchWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "catchable://now"))
        }
        .configurationDisplayName("Catchable departures")
        .description("Your next catchable departures from saved stations.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
