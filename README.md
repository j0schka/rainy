# MinutesToRain

An iOS app that answers one question: **how many minutes until it rains?**

Deep indigo background. A cloud illustration. A number below it.

---

## How it works

On launch, MinutesToRain requests your GPS location and fetches precipitation radar data from [Bright Sky](https://brightsky.dev) — a free, open API powered by the German Weather Service (DWD). The radar has **1 km spatial resolution** and **5-minute time slots**, giving timing accuracy of roughly ±5 minutes.

The current temperature is shown in the glass card at the bottom, fetched from the same service alongside the radar data.

Data refreshes automatically every 5 minutes, and again whenever the app returns to the foreground.

---

## Display states

| Illustration | Number | Background | Meaning |
|---|---|---|---|
| Cloud, pulsing | — | Calm | Loading — waiting for GPS or API |
| Cloud with 3 static drops | **35** min | Calm | Dry — rain expected in 35 minutes |
| Cloud with animated drops | **12** min | Cyan rain streaks | Currently raining — stops in ~12 minutes |
| Cloud with animated drops | **—** | Cyan rain streaks | Currently raining — no stop in the next 2 hours |
| Sun with rotating rays | **—** | Calm | Dry — no rain detected in the next 2 hours |
| Cloud, desaturated | **?** | Calm | Error — location denied or API unreachable |

A condition string appears below the number in every state: *"rain approaching"*, *"currently raining"*, *"no rain in sight"*, *"locating…"*, or *"check location"*.

The temperature in the bottom card shows `—` in the loading and error states.

---

## UI

- **Background** — deep indigo radial gradient (`#12082E` → `#2A1260`)
- **Cloud** — layered SwiftUI shapes with a light-to-dark gradient and a specular highlight
- **Sun** — rotating rays + warm gradient disc, shown when no rain is expected
- **Rain streaks** — full-screen cyan streaks (`#5BC8F5`) animated via `Canvas` + `TimelineView`
- **Pulsing glow** — cyan shadow behind the cloud when raining; gold behind the sun
- **Glass card** — pinned to bottom, shows temperature, refresh cadence, and data source

---

## Requirements

- iOS 17.0+
- Location permission (When In Use) — required to look up local radar data
- Internet connection — data comes from `api.brightsky.dev`

---

## Data source

[Bright Sky](https://brightsky.dev) — free, no API key required. Rain timing uses the `/radar` endpoint (5-minute RADOLAN nowcast + 2-hour forecast). Temperature uses the `/weather` endpoint (DWD MOSMIX forecast). Both are fetched concurrently on each refresh.

Coverage is limited to Germany and neighbouring regions served by the DWD radar network. Outside this area the app will show **?**.

---

## Project structure

```
MinutesToRain/
└── MinutesToRain/
    ├── RainyApp.swift          — app entry point
    ├── ContentView.swift       — all UI: background, illustrations, layout, glass card
    ├── RainViewModel.swift     — state machine, refresh loop
    ├── LocationManager.swift   — CoreLocation wrapper
    └── WeatherService.swift    — Bright Sky API calls
```
