# MoonTS

[![CI](https://github.com/shencangsheng513/moonts/actions/workflows/ci.yml/badge.svg)](https://github.com/shencangsheng513/moonts/actions/workflows/ci.yml)

Time-series transformation library for [MoonBit](https://www.moonbitlang.com): rolling windows, calendar resampling, and fill strategies — the pandas-style primitives the MoonBit ecosystem is missing.

> 🚧 WIP — 2026 MoonBit Hackathon (September edition) entry. This repository is developed in the open; see the issue tracker for the build plan.

## Status

- [x] `Series`: aligned (timestamp, value) columns with strict-increasing validation
- [x] `rolling` (count windows): `rolling_mean` / `sum` / `min` / `max` / `std` with `min_periods` semantics
- [x] `rolling`: duration-based windows via `rolling_by(window_ms, min_periods, agg)` (half-open, pandas-compatible)
- [x] `resample`: calendar binning (s / min / h / day / week / month) + counted steps (`Counted(5, Minute)` → `5min` bins) with mean / sum / min / max / std
- [x] fill strategies: `ffill` / `bfill` / `fill_constant` / `drop_missing` (pandas semantics)
- [x] demo CLI: `moon run cli` — CSV in (argument), CSV out (stdout)

## Quick example

```moonbit
// timestamps: UTC epoch milliseconds; new(...) raises SeriesError on
// mismatched lengths, empty input, or non-increasing timestamps
let s = Series::new([1000L, 2000L, 3000L], [1.0, 2.0, 3.0])
s.rolling_mean(2, 1).values // [1.0, 1.5, 2.5]
```

## Try the CLI

The core library deliberately has **no file API** (it stays runnable on every
backend), so the CLI takes CSV text as an argument and writes CSV to stdout:

```bash
moon run cli                                  # built-in demo: resample + NaN gap
moon run cli -- rolling 2 mean "1000,1.0
2000,2.0"
moon run cli -- resample d mean --ffill "$(cat series.csv)" > daily.csv
moon run cli -- resample 5min sum "$(< busy_minutes.csv)"   # counted steps
```

## Design notes

- Timestamps are UTC epoch milliseconds as `Int64` (MoonBit's `Int` is 32-bit); timezone handling is out of scope for v0. Week bins start on Monday.
- Fixed-size bins share one formula, `t - floor_mod(t - anchor, step)`: simple frequencies are the step-1 case, counted frequencies scale the step, and `Month` is the only calendar (non-uniform) bucket, handled separately.
- Values are `Double`; `NaN` marks a missing observation.
- Zero third-party dependencies: pure MoonBit, runs on all backends.

## Develop

```bash
moon info && moon fmt && moon test
```

## License

Apache-2.0
