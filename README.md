# MoonTS

Time-series transformation library for [MoonBit](https://www.moonbitlang.com): rolling windows, calendar resampling, and fill strategies — the pandas-style primitives the MoonBit ecosystem is missing.

> 🚧 WIP — 2026 MoonBit Hackathon (September edition) entry. This repository is developed in the open; see the issue tracker for the build plan.

## Status

- [x] `Series`: aligned (timestamp, value) columns with strict-increasing validation
- [x] `rolling` (count windows): `rolling_mean` / `rolling_sum` with `min_periods` semantics
- [ ] `rolling`: min / max / std aggregations, duration-based windows
- [ ] `resample`: calendar binning (s / min / h / day / week / month) with downcast aggregations
- [ ] fill strategies: forward / backward / constant / drop
- [ ] demo CLI: CSV in → resampled CSV out

## Quick example

```moonbit
// timestamps: UTC epoch milliseconds; new(...) raises SeriesError on
// mismatched lengths, empty input, or non-increasing timestamps
let s = Series::new([1000, 2000, 3000], [1.0, 2.0, 3.0])
s.rolling_mean(2, 1).values // [1.0, 1.5, 2.5]
```

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
