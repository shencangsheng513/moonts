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
