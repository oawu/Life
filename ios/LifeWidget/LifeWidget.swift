import WidgetKit
import SwiftUI

struct LifeWidgetEntry: TimelineEntry {
  let date: Date
}

struct LifeWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> LifeWidgetEntry {
    LifeWidgetEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (LifeWidgetEntry) -> Void) {
    completion(LifeWidgetEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<LifeWidgetEntry>) -> Void) {
    let entry = LifeWidgetEntry(date: Date())
    let timeline = Timeline(entries: [entry], policy: .atEnd)
    completion(timeline)
  }
}

struct LifeWidgetView: View {
  var entry: LifeWidgetEntry

  var body: some View {
    Text("Life")
  }
}

@main
struct LifeWidget: Widget {
  let kind = "LifeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: LifeWidgetProvider()) { entry in
      LifeWidgetView(entry: entry)
    }
    .configurationDisplayName("Life")
    .description("Life Widget")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
