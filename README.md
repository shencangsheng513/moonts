# MoonTS

Time-series transformation library for [MoonBit](https://www.moonbitlang.com): rolling windows, calendar resampling, and fill strategies — the pandas-style primitives the MoonBit ecosystem is missing.

> 🚧 WIP — 2026 MoonBit Hackathon (September edition) entry. This repository is developed in the open; see the issue tracker for the build plan.

## Status

- [x] `Series`: aligned (timestamp, value) columns with strict-increasing validation
- [ ] `rolling`: window aggregations (mean / sum / min / max / std), `min_periods` semantics
- [ ] `resample`: calendar binning (s / min / h / day / week / month) with downcast aggregations
- [ ] fill strategies: forward / backward / constant / drop
- [ ] demo CLI: CSV in → resampled CSV out

## Design notes

- Timestamps are UTC epoch milliseconds (`Int`); timezone handling is out of scope for v0.
- Values are `Double`; `NaN` marks a missing observation.
- Zero third-party dependencies: pure MoonBit, runs on all backends.

## Develop

```bash
moon info && moon fmt && moon test
```

## License

Apache-2.0
