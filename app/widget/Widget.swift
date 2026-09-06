//
//  Widget.swift
//  Albrhi Licences — the home screen's own line about the licences.
//
//  **It reads a file, not the API.** A widget cannot be asked to hold the admin token: an
//  extension is a second binary with its own keychain access, and a token that authorises
//  revoking every licence sold has no business being reachable from a home screen process that
//  iOS launches on its own schedule. The app writes what the widget shows, into the group
//  container, whenever it refreshes.
//
//  So a widget with nothing to show means the app has not been opened yet, and it says exactly
//  that rather than a zero — a zero is a fact about the licences and this one would be a fact
//  about the widget.
//
import WidgetKit
import SwiftUI

struct Counts {
    var waiting = 0
    var soon = 0
    var live = 0
    var known = false      // whether the app has ever written
}

func read() -> Counts {
    guard let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.albrhi.licences"),
          let data = try? Data(contentsOf: container.appendingPathComponent("counts.json")),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return Counts() }

    return Counts(waiting: json["waiting"] as? Int ?? 0,
                  soon: json["soon"] as? Int ?? 0,
                  live: json["live"] as? Int ?? 0,
                  known: true)
}

struct Entry: TimelineEntry {
    let date: Date
    let counts: Counts
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), counts: Counts(waiting: 2, soon: 1, live: 34, known: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), counts: read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // Refreshed on the app's own writes as well; this is the floor, not the plan.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [Entry(date: Date(), counts: read())], policy: .after(next)))
    }
}

struct Face: View {
    var entry: Entry

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if !entry.counts.known {
                Text("افتح التطبيق أوّلاً")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("\(entry.counts.waiting)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundColor(entry.counts.waiting > 0 ? .orange : .primary)
                Text("طلب ينتظر")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Text("\(entry.counts.soon) ينتهي خلال أسبوعين")
                    .font(.caption2)
                    .foregroundColor(entry.counts.soon > 0 ? .orange : .secondary)
                Text("\(entry.counts.live) ترخيص سارٍ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .environment(\.layoutDirection, .rightToLeft)
        .padding(12)
    }
}

@main
struct AlbrhiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.albrhi.licences.widget", provider: Provider()) { entry in
            // iOS 17 wants the background declared inside the widget rather than painted by
            // the system, and iOS 15 has no such modifier at all. The check is on `iOS`, not on
            // `iOSApplicationExtension`: the compiler refuses to narrow the availability of a
            // SwiftUI modifier by the second one.
            if #available(iOS 17.0, *) {
                Face(entry: entry).containerBackground(.fill.tertiary, for: .widget)
            } else {
                Face(entry: entry)
            }
        }
        .configurationDisplayName("تراخيص البرهي")
        .description("الطلبات المنتظرة وما ينتهي قريباً.")
        .supportedFamilies([.systemSmall])
    }
}
