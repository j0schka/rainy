# Notes for App Review — resubmission

## Guideline 1.5 — Support URL (fixed, no action needed in App Store Connect)

The Support URL (`https://github.com/j0schka/rainy`) previously landed on a
developer-facing technical README with no visible support info. The README
now leads with a "Support" section linking to GitHub Issues
(`https://github.com/j0schka/rainy/issues`) for questions and bug reports.
The Support URL field itself doesn't need to change.

## Guideline 2.1(a) — Regenradar error

### Root cause

"Regenradar" uses the German Weather Service's (DWD) precipitation radar via
the free Bright Sky API. That radar has no data outside Germany and its
immediate neighboring countries. The review device was located outside that
coverage area, so the radar screen received an empty response and showed an
error.

### What changed in this build

- The radar screen now shows a clear, friendly message when there's no radar
  coverage for the current location, instead of a generic-looking error.
- The main screen no longer fails outright when only radar data is missing —
  it still shows temperature and falls back to "no rain in sight" so the app
  never looks broken outside the coverage area.

### For the reviewer (paste into "Notes for Review" in App Store Connect)

To fully verify live rain detection and the animated radar map, please set
the test device's location to somewhere in Germany, for example:

    Berlin: 52.5200, 13.4050

(Settings > Privacy & Security > Location Services > System Services >
custom location, or via a GPX file in Xcode if testing in Simulator.)

Outside that coverage area the app is expected to show temperature only and
"no rain in sight" on the main screen, and a "coverage limited to Germany
and neighboring regions" message on the Regenradar screen — this is intended
behavior, not a bug.

### Alternative

If a reviewer note isn't preferred, consider restricting territory
availability under Pricing and Availability to Germany, Austria,
Switzerland, and other DWD-covered countries instead.
