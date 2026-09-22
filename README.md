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
- [x] `ewm_mean`: exponentially weighted mean with the full pandas `adjust` × `ignore_na` semantics and alpha / span / halflife / com decays
- [x] `interpolate`: linear gap filling, pandas `method='time'` (time-weighted) or `method='linear'` (positional)
- [x] tests: 82 total — numeric behavior pinned against pandas 2.3.3 ground truth, plus 6 quickcheck property tests
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
moon run cli -- ewm span=3 false false "0,1.0
1000,2.0
2000,3.0"                          # pandas ewm(adjust=False) semantics
moon run cli -- interp time "0,1.0
21600000,
86400000,24.0"                     # -> 6.75: fill by elapsed time
moon run cli -- interp pos  "0,1.0
21600000,
86400000,24.0"                     # -> 12.5: fill by index position
```

The last two commands answer the same hole in the data with two different
business judgments — time-weighted says "the value drifts with the clock",
positional says "samples are conceptually evenly spaced". Pick deliberately.

## Design notes

- Timestamps are UTC epoch milliseconds as `Int64` (MoonBit's `Int` is 32-bit); timezone handling is out of scope for v0. Week bins start on Monday.
- Fixed-size bins share one formula, `t - floor_mod(t - anchor, step)`: simple frequencies are the step-1 case, counted frequencies scale the step, and `Month` is the only calendar (non-uniform) bucket, handled separately.
- Values are `Double`; `NaN` marks a missing observation.
- Zero third-party dependencies: pure MoonBit; CI runs the whole suite on the default, JavaScript (`--target js`) and `wasm-gc` backends.

## Develop

```bash
moon info && moon fmt && moon test
```

## License

Apache-2.0
