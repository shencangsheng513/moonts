# MoonTS

Time-series transformation library for [MoonBit](https://www.moonbitlang.com): rolling windows, calendar resampling, and fill strategies — the pandas-style primitives the MoonBit ecosystem is missing.

> 🚧 WIP — 2026 MoonBit Hackathon (September edition) entry. This repository is developed in the open; see the issue tracker for the build plan.

## Status

- [x] `Series`: aligned (timestamp, value) columns with strict-increasing validation
- [x] `rolling` (count windows): `rolling_mean` / `sum` / `min` / `max` / `std` with `min_periods` semantics
- [ ] `rolling`: duration-based windows
- [x] `resample`: calendar binning (s / min / h / day / week / month) with mean / sum / min / max / std
- [x] fill strategies: `ffill` / `bfill` / `fill_constant` / `drop_missing` (pandas semantics)
- [ ] demo CLI: CSV in → resampled CSV out

## Quick example

```moonbit
// timestamps: UTC epoch milliseconds; new(...) raises SeriesError on
// mismatched lengths, empty input, or non-increasing timestamps
let s = Series::new([1000L, 2000L, 3000L], [1.0, 2.0, 3.0])
s.rolling_mean(2, 1).values // [1.0, 1.5, 2.5]
```

## Design notes

- Timestamps are UTC epoch milliseconds as `Int64` (MoonBit's `Int` is 32-bit); timezone handling is out of scope for v0. Week bins start on Monday.
- Values are `Double`; `NaN` marks a missing observation.
- Zero third-party dependencies: pure MoonBit, runs on all backends.

## Develop

```bash
moon info && moon fmt && moon test
```

## License

Apache-2.0
