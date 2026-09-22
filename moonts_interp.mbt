///|
/// How the interpolation parameter `t` between two valid anchors is
/// measured.
///
/// - `TimeWeighted`: pandas `interpolate(method='time')` - `t` is the
///   fraction of real elapsed time between the anchors, so a hole in a
///   sparse region gets a value proportionate to how long the gap lasted.
/// - `Positional`: pandas `interpolate(method='linear')` on a `RangeIndex`
///   - `t` is the fraction of index positions, ignoring the timestamps.
///
/// Which one is right is a business judgment (the coffee-shop Saturday
/// question again): evenly spaced sensors want positional; irregular
/// sampling wants time-weighted.
pub(all) enum Interpolation {
  TimeWeighted
  Positional
} derive(Eq, Debug)

///|
pub extend Interpolation with Eq::{not_equal, equal}

///|
pub extend Interpolation with @debug.Debug::{to_repr}

///|
/// Linear interpolation of missing observations, pandas-compatible:
/// leading NaNs have no left anchor and stay NaN, trailing NaNs have no
/// right anchor and carry the last valid observation forward (pandas does
/// not extrapolate slopes), and internal gaps are filled between the
/// nearest valid observations on each side. A series that is all NaN is
/// returned unchanged.
pub fn Series::interpolate(self : Series, kind : Interpolation) -> Series {
  let values = self.values.copy()
  let n = values.length()
  // Indices of the valid (non-NaN) observations; the fill only ever
  // happens between two consecutive entries of this array.
  let anchors = Array(capacity=n)
  for i in 0..<n {
    if !values[i].is_nan() {
      anchors.push(i)
    }
  }
  let a_len = anchors.length()
  if a_len > 0 {
    // Trailing NaNs: no right anchor, so pandas forward-fills the last
    // valid value rather than extrapolating the final slope.
    let last = anchors[a_len - 1]
    let tail = last + 1
    for k in tail..<n {
      values[k] = values[last]
    }
    let mut j = 0
    while j < a_len - 1 {
      let lo = anchors[j]
      let hi = anchors[j + 1]
      if hi - lo > 1 {
        let v_lo = values[lo]
        let v_hi = values[hi]
        let span = hi - lo
        let mut k = lo + 1
        while k < hi {
          let t = if kind == Positional {
            (k - lo).to_double() / span.to_double()
          } else {
            let dt = (self.ts[k] - self.ts[lo]).to_double()
            let full = (self.ts[hi] - self.ts[lo]).to_double()
            dt / full
          }
          values[k] = v_lo + (v_hi - v_lo) * t
          k += 1
        }
      }
      j += 1
    }
  }
  Series::{ ts: self.ts.copy(), values, }
}
