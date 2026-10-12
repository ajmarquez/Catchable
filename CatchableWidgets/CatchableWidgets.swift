import SwiftUI
import WidgetKit

@main
struct CatchableWidgets: WidgetBundle {
    var body: some Widget {
        CatchableWidget(style: .badges, title: "Route badges", description: "Your catchable departures with clear route badges.")
        CatchableWidget(style: .timetable, title: "Compact timetable", description: "More departures in a compact typographic grid.")
        CatchableWidget(style: .next, title: "Next departure", description: "Focus on the next service you can reach.")
    }
}

struct CatchableWidget: Widget {
    let style: CatchableWidgetStyle
    let title: String
    let description: String

    init() {
        self.init(style: .badges, title: "Route badges", description: "Your catchable departures.")
    }

    init(style: CatchableWidgetStyle, title: String, description: String) {
        self.style = style
        self.title = title
        self.description = description
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Catchable.\(style.rawValue)", provider: CatchableTimelineProvider()) { entry in
            CatchableWidgetView(entry: entry, style: style)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName(title)
        .description(description)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
