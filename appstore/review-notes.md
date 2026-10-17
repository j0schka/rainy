# Notes for App Review — resubmission (build 8)

## Guideline 1.5 — Support URL

**Action in App Store Connect:** change the Support URL to

    https://j0schka.github.io/rainy/support.html

This is a dedicated support page with a contact email, a link to GitHub
Issues, an FAQ and the privacy policy. Its source is in `docs/support.html`.
Optionally, set the Privacy Policy URL to
`https://j0schka.github.io/rainy/privacy.html`.

## Guideline 2.1(a) — "radar data wasn't available"

### Root cause

The app only used radar data from the German Weather Service (DWD), which
covers Germany and neighboring countries. On the review device (outside that
area), both the rain countdown and the radar map had no data.

### Fix in this build

- **Rain countdown:** outside DWD coverage, the app now uses Open-Meteo's
  worldwide 15-minute precipitation forecast. It shows real "minutes until
  rain/rain stops" values and temperature everywhere. The source label at the
  bottom of the screen shows which provider is active.
- **Radar map:** outside DWD coverage, the radar screen now shows RainViewer's
  global radar composite (last 2 hours, animated).
- Tested in the iOS Simulator with the location set to Cupertino, CA and to
  Berlin, Germany.

### "Notes for Review" text (paste into App Store Connect)

> Thank you for the feedback. This build fixes both issues:
>
> 1. Support URL: updated to https://j0schka.github.io/rainy/support.html,
>    a support page with contact email, FAQ and privacy policy.
>
> 2. Radar data: previously the app only used German Weather Service radar,
>    which is not available outside Germany. The app now works worldwide.
>    Outside Germany it uses a global precipitation forecast (Open-Meteo) for
>    the rain countdown and a global radar map (RainViewer). No special
>    location setup is needed. The minute countdown only appears when rain is
>    forecast within the next 2 hours. Otherwise the app shows "no rain in
>    sight", which is the correct result for dry weather.
