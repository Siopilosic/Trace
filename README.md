# Trace

A frictionless personal logging app for iOS. Something happens → you tell Trace in
a few seconds → Trace remembers it and turns your entries into quiet statistics.

MVP focus: **money**, with a lightweight general‑purpose entry model underneath
(expense · income · activity · note).

---

## Requirements

- Xcode 16 or newer (SwiftData, `@Observable`, Swift Charts)
- iOS 17 deployment target
- No third‑party dependencies, no backend, no account

Open `Trace.xcodeproj` and run the **Trace** scheme on an iOS 17+ simulator or device.

## Architecture

Local‑first. One SwiftData store, no network layer. Pure logic (parser,
statistics, category inference) is kept free of SwiftUI/SwiftData so it is
directly unit‑testable and easy to evolve.

```
Trace/
  TraceApp.swift            App entry, ModelContainer setup
  Models/
    Entry.swift             @Model — the single persisted record
    EntryKind.swift         expense | income | activity | note
    ExpenseCategory.swift    food | transport | … | other
    ParsedDraft.swift       value type: parser output / editor input
    StatEntry.swift         protocol the stats engine consumes
  Parser/
    QuickEntryParser.swift  "lunch 150" -> ParsedDraft   (deterministic, no AI)
    CategoryInferencer.swift keyword -> category
  Statistics/
    StatisticsEngine.swift  pure engine: totals, net, averages, trend, breakdown
    StatisticsPeriod.swift  day | week | month | year  (Calendar boundaries)
  Services/
    EntryActions.swift      the only place that writes to ModelContext
  Design/
    Theme.swift             spacing / radius / colour / type tokens
    Haptics.swift           thin UIKit feedback wrapper
  Utilities/
    Formatters.swift        money / duration / date strings
    Date+Trace.swift        greeting, period labels
    AppSettings.swift       currency, appearance, week start (UserDefaults)
    PreviewData.swift       in‑memory sample data — previews only, never shipped
  Components/               EntryRow, StatFigure, EmptyStateView, QuickAddButton,
                            CategoryBreakdownRow, TrendChart
  Views/
    RootView.swift          tab bar: Today · History · Stats · Settings
    Today/HomeView.swift
    QuickAdd/QuickAddView.swift + QuickAddModel.swift
    History/HistoryView.swift + EntryDetailView.swift
    Stats/StatisticsView.swift
    Settings/SettingsView.swift

TraceTests/                  parser, category, statistics unit tests
```

### Data / iCloud

`Entry` has a default value for every attribute and no unique constraints, so a
CloudKit‑backed `ModelConfiguration(cloudKitDatabase:)` can be added later with no
model changes or migration. Not enabled for the MVP.

### The parser

`QuickEntryParser.parse(_:)` recognises, in priority order:

| Input | Result |
|---|---|
| `Gym 1h`, `Python 45m`, `Run 1h 30m` | activity + duration |
| `McDonald's 320`, `Coffee 90` | expense + amount (+ inferred category) |
| `Got paid 20000`, `salary 20k` | income + amount |
| `Rent 4,500`, `Snack 12.50`, `Groceries 250 EGP` | amount parsing: separators, `k`/`m`, currency tokens |
| `Today was actually a really good day` | note |

Ambiguous fragments (`Gym` with no amount/duration) are returned with
`isConfident == false` and the UI asks the user to pick the kind.

## Tests

`TraceTests` covers the parser, category inference and the statistics engine
(month/week/year boundaries, elapsed‑day averaging, category ordering, trend
bucketing). Run with **⌘U** or:

```
xcodebuild test -scheme Trace -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Build verification note

This project was authored in an environment without a full Xcode install, so the
final `xcodebuild` compile/run/test cycle must be done on your machine. The
platform‑independent logic (parser, category inference, statistics engine — the
`TraceTests` assertions) was compiled and executed standalone via the Swift
toolchain: **61 checks, 0 failures**. The SwiftUI view layer and components were
type‑checked against the real SwiftUI / Swift Charts SDK.
