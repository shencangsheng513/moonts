///|
pub(all) enum Decay {
  Alpha(Double)
  Span(Double)
  Halflife(Double)
  Com(Double)
} derive(Eq, Debug)

///|
pub extend Decay with Eq::{not_equal, equal}

///|
pub extend Decay with @debug.Debug::{to_repr}

///|
pub suberror EwmError {
  AlphaOutOfRange(Double)
  SpanTooSmall(Double)
  HalflifeNotPositive(Double)
  ComNegative(Double)
}

///|
pub impl Show for EwmError with fn output(self : EwmError, logger) {
  match self {
    AlphaOutOfRange(a) =>
      logger.write_string("alpha must satisfy 0 < a <= 1, got \{a}")
    SpanTooSmall(s) => logger.write_string("span must be at least 1, got \{s}")
    HalflifeNotPositive(h) =>
      logger.write_string("halflife must be positive, got \{h}")
    ComNegative(c) => logger.write_string("com must be at least 0, got \{c}")
  }
}

///|
pub extend EwmError with Show::{to_string, output}

///|
/// Every decay kind collapses to the smoothing factor `alpha` with the
/// conversions pandas uses: span -> 2/(s+1), halflife -> 1-exp(-ln2/h),
/// com -> 1/(1+c).
fn Decay::to_alpha(self : Decay) -> Double raise EwmError {
  match self {
    Alpha(a) => if a > 0.0 && a <= 1.0 { a } else { raise AlphaOutOfRange(a) }
    Span(s) => if s >= 1.0 { 2.0 / (s + 1.0) } else { raise SpanTooSmall(s) }
    Halflife(h) =>
      if h > 0.0 {
        1.0 - @math.exp(-@math.ln(2.0) / h)
      } else {
        raise HalflifeNotPositive(h)
      }
    Com(c) => if c >= 0.0 { 1.0 / (1.0 + c) } else { raise ComNegative(c) }
  }
}

///|
/// Exponentially weighted mean, reproducing the full pandas `ewm` semantics
/// for all four combinations of `adjust` and `ignore_na`.
///
/// A single O(n) recursion over (numerator, denominator) accumulators covers
/// every combination: `adjust=false` scales the new observation's weight to
/// `alpha` instead of 1, `ignore_na=true` freezes the decay on NaN steps,
/// and leading NaNs stay NaN until the first valid observation seeds the
/// state. Trailing NaNs carry the last weighted mean forward (pandas'
/// documented behavior), they do not yield NaN.
pub fn Series::ewm_mean(
  self : Series,
  decay : Decay,
  adjust : Bool,
  ignore_na : Bool,
) -> Series raise EwmError {
  let alpha = decay.to_alpha()
  let old_factor = 1.0 - alpha
  let new_wt = if adjust { 1.0 } else { alpha }
  let n = self.values.length()
  let out = Array(capacity=n)
  let mut num = 0.0
  let mut den = 0.0
  let mut started = false
  for i in 0..<n {
    let v = self.values[i]
    let valid = !v.is_nan()
    if started && (valid || !ignore_na) {
      num *= old_factor
      den *= old_factor
    }
    if valid {
      if !started {
        num = v
        den = 1.0
        started = true
      } else {
        num += new_wt * v
        den += new_wt
      }
    }
    out.push(if started { num / den } else { nan })
  }
  Series::{ ts: self.ts.copy(), values: out, }
}
