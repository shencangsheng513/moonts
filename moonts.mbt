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
/// Timestamps are UTC epoch milliseconds, strictly increasing.
/// Values are 64-bit floats (NaN allowed: it signals a missing observation
/// to later fill strategies, and aggregates skip or propagate it by policy).
pub struct Series {
  ts : Array[Int]
  values : Array[Double]
}

///|
/// Build a Series from aligned columns.
///
/// Rejects mismatched lengths, empty input, and non-increasing timestamps:
/// all downstream windowing algorithms assume strict ordering.
pub fn Series::new(
  ts : Array[Int],
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
  self.rolling_agg(window, min_periods, buf => {
    let mut acc = 0.0
    for v in buf {
      acc = acc + v
    }
    acc / buf.length().to_double()
  })
}

///|
/// Rolling sum over count-based windows; NaN observations are skipped.
pub fn Series::rolling_sum(
  self : Series,
  window : Int,
  min_periods : Int,
) -> Series raise RollingError {
  self.rolling_agg(window, min_periods, buf => {
    let mut acc = 0.0
    for v in buf {
      acc = acc + v
    }
    acc
  })
}

///|
/// Rolling minimum over count-based windows.
pub fn Series::rolling_min(
  self : Series,
  window : Int,
  min_periods : Int,
) -> Series raise RollingError {
  self.rolling_agg(window, min_periods, buf => {
    let mut m = buf[0]
    for v in buf {
      if v < m {
        m = v
      }
    }
    m
  })
}

///|
/// Rolling maximum over count-based windows.
pub fn Series::rolling_max(
  self : Series,
  window : Int,
  min_periods : Int,
) -> Series raise RollingError {
  self.rolling_agg(window, min_periods, buf => {
    let mut m = buf[0]
    for v in buf {
      if v > m {
        m = v
      }
    }
    m
  })
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
  self.rolling_agg(window, min_periods, buf => {
    let n = buf.length()
    if n < 2 {
      nan
    } else {
      let mut sum = 0.0
      for v in buf {
        sum = sum + v
      }
      let mean = sum / n.to_double()
      let mut sq = 0.0
      for v in buf {
        let d = v - mean
        sq = sq + d * d
      }
      (sq / (n - 1).to_double()).sqrt()
    }
  })
}
