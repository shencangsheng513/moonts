///|
/// The missing-observation marker: a quiet NaN.
///
/// Series carry NaN where an observation is absent; rolling aggregates skip
/// it, and the fill strategies in this library key off it.
pub let nan : Double = @double.not_a_number

///|
pub suberror SeriesError {
  LengthMismatch(Int, Int)
  Empty
  NonIncreasingTimestamps
}

///|
pub impl Show for SeriesError with fn output(self : SeriesError, logger) {
  match self {
    LengthMismatch(a, b) =>
      logger.write_string("length mismatch: ts has \{a}, values has \{b}")
    Empty => logger.write_string("series must not be empty")
    NonIncreasingTimestamps =>
      logger.write_string("timestamps must be strictly increasing")
  }
}

///|
pub extend SeriesError with Show::{to_string, output}

///|
/// An aligned (timestamp, value) sequence.
///
/// Timestamps are UTC epoch milliseconds as `Int64` (MoonBit's `Int` is
/// 32-bit and cannot hold them), strictly increasing.
/// Values are 64-bit floats (NaN allowed: it signals a missing observation
/// to later windowing algorithms, and aggregates skip it by policy).
pub struct Series {
  ts : Array[Int64]
  values : Array[Double]
}

///|
/// Build a Series from aligned columns.
///
/// Rejects mismatched lengths, empty input, and non-increasing timestamps:
/// all downstream windowing algorithms assume strict ordering.
pub fn Series::new(
  ts : Array[Int64],
  values : Array[Double],
) -> Series raise SeriesError {
  if ts.length() != values.length() {
    raise LengthMismatch(ts.length(), values.length())
  }
  if ts.length() == 0 {
    raise Empty
  }
  for i = 1; i < ts.length(); i = i + 1 {
    if ts[i] <= ts[i - 1] {
      raise NonIncreasingTimestamps
    }
  }
  Series::{ ts, values, }
}

///|
pub suberror RollingError {
  InvalidWindow(Int)
  InvalidMinPeriods(Int)
}

///|
pub impl Show for RollingError with fn output(self : RollingError, logger) {
  match self {
    InvalidWindow(w) =>
      logger.write_string("window must be at least 1, got \{w}")
    InvalidMinPeriods(m) =>
      logger.write_string("min_periods must satisfy 1 <= m <= window, got \{m}")
  }
}

///|
pub extend RollingError with Show::{to_string, output}

///|
/// Shared engine for count-based rolling aggregations.
///
/// Output position i covers input positions (i - window + 1) to i, clipped
/// at the start of the series (windows do not extend before data begins).
/// `agg` receives only the non-NaN observations of each window; a window
/// with fewer than `min_periods` of them yields NaN.
///
/// O(n * window) by design: batch workloads here stay far below the size
/// where running-sum tricks pay off in readability.
fn Series::rolling_agg(
  self : Series,
  window : Int,
  min_periods : Int,
  agg : (Array[Double]) -> Double,
) -> Series raise RollingError {
  if window < 1 {
    raise InvalidWindow(window)
  }
  if min_periods < 1 || min_periods > window {
    raise InvalidMinPeriods(min_periods)
  }
  let n = self.values.length()
  let out = Array(capacity=n)
  let buf = Array(capacity=window)
  for i = 0; i < n; i = i + 1 {
    buf.clear()
    let start = if i - window + 1 < 0 { 0 } else { i - window + 1 }
    for j = start; j <= i; j = j + 1 {
      let v = self.values[j]
      if !v.is_nan() {
        buf.push(v)
      }
    }
    out.push(if buf.length() >= min_periods { agg(buf) } else { nan })
  }
  Series::{ ts: self.ts.copy(), values: out, }
}

///|
/// Rolling mean over count-based windows, pandas-compatible NaN skipping.
///
/// Example: values [1.0, 2.0, 3.0, 4.0] with window=2, min_periods=2
/// produce [nan, 1.5, 2.5, 3.5].
pub fn Series::rolling_mean(
  self : Series,
  window : Int,
  min_periods : Int,
) -> Series raise RollingError {
  self.rolling_agg(window, min_periods, buf => agg_values(buf, Mean))
}

///|
/// Rolling sum over count-based windows; NaN observations are skipped.
pub fn Series::rolling_sum(
  self : Series,
  window : Int,
  min_periods : Int,
) -> Series raise RollingError {
  self.rolling_agg(window, min_periods, buf => agg_values(buf, Sum))
}

///|
/// Rolling minimum over count-based windows.
pub fn Series::rolling_min(
  self : Series,
  window : Int,
  min_periods : Int,
) -> Series raise RollingError {
  self.rolling_agg(window, min_periods, buf => agg_values(buf, Min))
}

///|
/// Rolling maximum over count-based windows.
pub fn Series::rolling_max(
  self : Series,
  window : Int,
  min_periods : Int,
) -> Series raise RollingError {
  self.rolling_agg(window, min_periods, buf => agg_values(buf, Max))
}

///|
/// Rolling standard deviation, matching pandas' default `ddof=1`
/// (sample std). A window with fewer than two valid observations has an
/// undefined sample std and yields NaN even when min_periods is 1.
pub fn Series::rolling_std(
  self : Series,
  window : Int,
  min_periods : Int,
) -> Series raise RollingError {
  self.rolling_agg(window, min_periods, buf => agg_values(buf, Std))
}

///|
/// A down-sampling aggregation used by `resample`.
pub(all) enum Agg {
  Mean
  Sum
  Min
  Max
  Std
} derive(Eq, Debug)

///|
/// Calendar frequency for `resample`, evaluated in UTC.
///
/// Second/Minute/Hour/Day align to the Unix epoch, which coincides with UTC
/// calendar boundaries; Week bins start on Monday; Month bins span one
/// calendar month.
pub(all) enum Frequency {
  Second
  Minute
  Hour
  Day
  Week
  Month
} derive(Eq, Debug)

///|
pub extend Agg with Eq::{not_equal, equal}

///|
pub extend Agg with @debug.Debug::{to_repr}

///|
pub extend Frequency with Eq::{not_equal, equal}

///|
pub extend Frequency with @debug.Debug::{to_repr}

///|
/// Parse a pandas-style frequency alias.
///
/// Accepts `s`, `min`, `h`, `d`, `w`, and `me` (case-insensitive). Counted
/// forms like `5min` are not supported yet and return None. `me` maps to
/// calendar-month buckets (pandas' month-end labeling is out of v0 scope).
pub fn Frequency::from_string(s : String) -> Frequency? {
  match s.to_lower() {
    "s" => Some(Second)
    "min" => Some(Minute)
    "h" => Some(Hour)
    "d" => Some(Day)
    "w" => Some(Week)
    "me" | "month" => Some(Month)
    _ => None
  }
}

///|
pub suberror ResampleError {
  TooManyBins(Int)
}

///|
pub impl Show for ResampleError with fn output(self : ResampleError, logger) {
  match self {
    TooManyBins(n) =>
      logger.write_string(
        "resample reached \{n} bins (limit 10000000); the input range looks corrupted",
      )
  }
}

///|
pub extend ResampleError with Show::{to_string, output}

///|
let day_ms : Int64 = 86400000L

///|
let max_bins : Int = 10000000

///|
fn floor_div(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  if a % b != 0 && (a < 0) != (b < 0) {
    q - 1
  } else {
    q
  }
}

///|
fn floor_mod(a : Int64, b : Int64) -> Int64 {
  a - floor_div(a, b) * b
}

///|
/// Days-since-1970 to (year, month, day), Howard Hinnant's civil_from_days.
/// Every division below acts on non-negative values, so MoonBit's truncating
/// `/` matches the algorithm's floor-division requirement.
fn civil_from_days(days : Int64) -> (Int64, Int64, Int64) {
  let z = days + 719468L
  let era = (if z >= 0 { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = if mp < 10L { mp + 3L } else { mp - 9L }
  let y = if m <= 2L { yoe + era * 400L + 1L } else { yoe + era * 400L }
  (y, m, d)
}

///|
fn days_from_civil(y : Int64, m : Int64, d : Int64) -> Int64 {
  let y = if m <= 2L { y - 1L } else { y }
  let era = (if y >= 0 { y } else { y - 399L }) / 400L
  let yoe = y - era * 400L
  let mp = if m > 2L { m - 3L } else { m + 9L }
  let doy = (153L * mp + 2L) / 5L + d - 1L
  let doe = yoe * 365L + yoe / 4L - yoe / 100L + doy
  era * 146097L + doe - 719468L
}

///|
fn bucket_start(t : Int64, freq : Frequency) -> Int64 {
  match freq {
    Second => t - floor_mod(t, 1000L)
    Minute => t - floor_mod(t, 60000L)
    Hour => t - floor_mod(t, 3600000L)
    Day => t - floor_mod(t, day_ms)
    Week => {
      // Epoch day 0 (1970-01-01) was a Thursday, i.e. 3 days into a
      // Monday-started week.
      let day = floor_div(t, day_ms)
      (day - floor_mod(day + 3L, 7L)) * day_ms
    }
    Month => {
      let (y, m, _) = civil_from_days(floor_div(t, day_ms))
      days_from_civil(y, m, 1L) * day_ms
    }
  }
}

///|
fn next_bucket_start(start : Int64, freq : Frequency) -> Int64 {
  match freq {
    Second => start + 1000L
    Minute => start + 60000L
    Hour => start + 3600000L
    Day => start + day_ms
    Week => start + 7L * day_ms
    Month => {
      let (y, m, _) = civil_from_days(floor_div(start, day_ms))
      if m == 12L {
        days_from_civil(y + 1L, 1L, 1L) * day_ms
      } else {
        days_from_civil(y, m + 1L, 1L) * day_ms
      }
    }
  }
}

///|
fn agg_values(buf : Array[Double], agg : Agg) -> Double {
  match agg {
    Mean | Sum => {
      let mut acc = 0.0
      for v in buf {
        acc = acc + v
      }
      match agg {
        Sum => acc
        _ => acc / buf.length().to_double()
      }
    }
    Min | Max => {
      let mut m = buf[0]
      for v in buf {
        if (agg == Min && v < m) || (agg == Max && v > m) {
          m = v
        }
      }
      m
    }
    Std =>
      if buf.length() < 2 {
        nan
      } else {
        let mut sum = 0.0
        for v in buf {
          sum = sum + v
        }
        let mean = sum / buf.length().to_double()
        let mut sq = 0.0
        for v in buf {
          let d = v - mean
          sq = sq + d * d
        }
        (sq / (buf.length() - 1).to_double()).sqrt()
      }
  }
}

///|
fn finish_bucket(buf : Array[Double], agg : Agg) -> Double {
  if buf.length() == 0 {
    nan
  } else {
    agg_values(buf, agg)
  }
}

///|
/// Down-sample to fixed calendar buckets, like pandas' `resample(freq)`.
///
/// The output covers the full grid from the first bucket to the last bucket
/// of the input (both ends included); buckets without any valid observation
/// get NaN so gaps stay visible for the fill strategies to repair. NaN input
/// values are skipped inside each bucket.
///
/// Bin count is capped at ten million so a corrupted range (one timestamp in
/// 1970, the next in year 3000, monthly frequency) errors out instead of
/// exhausting memory.
pub fn Series::resample(
  self : Series,
  freq : Frequency,
  agg : Agg,
) -> Series raise ResampleError {
  let n = self.values.length()
  let last_bin = bucket_start(self.ts[n - 1], freq)
  let out_ts = Array(capacity=n)
  let out_vals = Array(capacity=n)
  let buf = Array(capacity=4)
  let mut bin = bucket_start(self.ts[0], freq)
  for idx in 0..<n {
    let b = bucket_start(self.ts[idx], freq)
    while bin != b {
      out_ts.push(bin)
      out_vals.push(finish_bucket(buf, agg))
      buf.clear()
      if out_ts.length() > max_bins {
        raise TooManyBins(out_ts.length())
      }
      bin = next_bucket_start(bin, freq)
    }
    let v = self.values[idx]
    if !v.is_nan() {
      buf.push(v)
    }
  }
  out_ts.push(bin)
  out_vals.push(finish_bucket(buf, agg))
  while bin != last_bin {
    bin = next_bucket_start(bin, freq)
    out_ts.push(bin)
    out_vals.push(nan)
    if out_ts.length() > max_bins {
      raise TooManyBins(out_ts.length())
    }
  }
  Series::{ ts: out_ts, values: out_vals, }
}
