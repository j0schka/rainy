# Rainy

A minimal iOS app that answers one question: **how many minutes until it rains?**

Dark navy background. A light blue circle. A number inside it.

---

## How it works

On launch, Rainy requests your GPS location and fetches precipitation radar data from [Bright Sky](https://brightsky.dev) — a free, open API powered by the German Weather Service (DWD). The radar has **1 km spatial resolution** and **5-minute time slots**, giving timing accuracy of roughly ±5 minutes.

The current temperature is shown below the circle, fetched from the same service.

Data refreshes automatically every 5 minutes, and again whenever the app returns to the foreground.

---

## Display states

| Circle shows | Meaning |
|---|---|
| Pulsing circle | App is loading — waiting for GPS or the API response |
| **42** min | Rain expected in 42 minutes |
| **0** min | It is raining right now |
| **—** | No rain detected in the next 2 hours ("no rain in sight" appears below) |
| **?** | Something went wrong — location permission was denied, or the API could not be reached |

The temperature below the circle disappears in the `?` and loading states, since no data was retrieved.

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
    ├── ContentView.swift       — UI: background, circle, labels, rain animation
    ├── RainViewModel.swift     — state machine, refresh loop
    ├── LocationManager.swift   — CoreLocation wrapper
    └── WeatherService.swift    — Bright Sky API calls
```
