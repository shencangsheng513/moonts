///|
/// Property-based tests (core quickcheck, default seed = deterministic).
/// The generator produces (timestamp steps, values, adjust, ignore_na);
/// `qc_series` turns any draw into a legal Series, so every property below
/// is a claim about ALL inputs of that shape, not a claim about the handful
/// of rows the pandas fixtures happen to cover.
fn qc_series(
  steps : Array[Int],
  values : Array[Double],
) -> @moonts.Series raise {
  let n = steps.length()
  let m = values.length()
  let k = if n == 0 || m == 0 { 1 } else if n < m { n } else { m }
  let ts = Array(capacity=k)
  let vals = Array(capacity=k)
  let mut t = 0L
  for i in 0..<k {
    let s = if i < n { (steps[i] % 3600000).abs() + 1 } else { 1000 }
    t = t + s.to_int64()
    ts.push(t)
    let v = if i < m { values[i] } else { 1.0 }
    vals.push(
      if v.is_nan() {
        v
      } else if v > 1000000000.0 {
        1000000000.0
      } else if v < -1000000000.0 {
        -1000000000.0
      } else {
        v
      },
    )
  }
  // The invariant gate must never reject a generated input; if it does,
  // the generator (not the API) is broken.
  @moonts.Series::new(ts, vals) catch {
    e => fail("generated input should pass the invariant gate: \{e}")
  }
}

///|
fn same_values(a : Array[Double], b : Array[Double]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    let x = a[i]
    let y = b[i]
    if x != y && !(x.is_nan() && y.is_nan()) {
      return false
    }
  }
  true
}

///|
test "quickcheck: ewm_mean with alpha=1 is the identity for any flags" {
  @quickcheck.check(
    (input : (Array[Int], Array[Double], Bool, Bool)) => {
      let (steps, vals, adj, ign) = input
      let s = qc_series(steps, vals)
      let g = s.ewm_mean(@moonts.Alpha(1.0), adj, ign) catch {
        e => fail("alpha=1.0 must be valid: \{e}")
      }
      same_values(s.values, g.values)
    },
    filter=(input : (Array[Int], Array[Double], Bool, Bool)) => {
      let (_, vals, _, _) = input
      for v in vals {
        if v.is_nan() {
          return false
        }
      }
      true
    },
  )
}

///|
test "quickcheck: rolling_mean(1, 1) is the identity, NaN holes included" {
  @quickcheck.check((input : (Array[Int], Array[Double])) => {
    let (steps, vals) = input
    let s = qc_series(steps, vals)
    let g = s.rolling_mean(1, 1) catch {
      e => fail("window=1 min_periods=1 must be valid: \{e}")
    }
    same_values(s.values, g.values)
  })
}

///|
test "quickcheck: every rolling_mean(w=3) output lies between global min and max" {
  @quickcheck.check((input : (Array[Int], Array[Double])) => {
    let (steps, vals) = input
    let s = qc_series(steps, vals)
    let g = s.rolling_mean(3, 3) catch {
      e => fail("window=3 min_periods=3 must be valid: \{e}")
    }
    if g.values.length() != s.values.length() {
      return false
    }
    let mut lo = 0.0
    let mut hi = 0.0
    let mut has_valid = false
    for v in s.values {
      if !v.is_nan() {
        if !has_valid {
          lo = v
          hi = v
          has_valid = true
        } else {
          if v < lo {
            lo = v
          }
          if v > hi {
            hi = v
          }
        }
      }
    }
    for v in g.values {
      if !v.is_nan() && (v < lo || v > hi) {
        return false
      }
    }
    true
  })
}

///|
test "quickcheck: interpolate never touches valid data and holes only survive at the front" {
  @quickcheck.check((input : (Array[Int], Array[Double], Bool)) => {
    let (steps, vals, kind) = input
    let s = qc_series(steps, vals)
    let interp = if kind { @moonts.TimeWeighted } else { @moonts.Positional }
    let g = s.interpolate(interp)
    let n = s.values.length()
    let mut first_valid = n
    for i in 0..<n {
      if !s.values[i].is_nan() {
        first_valid = i
        break
      }
    }
    for i in 0..<n {
      if !s.values[i].is_nan() {
        // Valid observations pass through bit-for-bit.
        if g.values[i] != s.values[i] {
          return false
        }
      } else if i >= first_valid {
        // Every hole at or after the first anchor must be filled:
        // between anchors by interpolation, after the last by carry.
        if g.values[i].is_nan() {
          return false
        }
      }
    }
    true
  })
}

///|
test "quickcheck: ffill leaves no hole after the first valid observation" {
  @quickcheck.check((input : (Array[Int], Array[Double])) => {
    let (steps, vals) = input
    let s = qc_series(steps, vals)
    let f = s.ffill()
    if f.values.length() != s.values.length() {
      return false
    }
    let mut seen_valid = false
    for i in 0..<s.values.length() {
      if !s.values[i].is_nan() {
        seen_valid = true
        if f.values[i] != s.values[i] {
          return false
        }
      } else if seen_valid && f.values[i].is_nan() {
        return false
      }
    }
    true
  })
}

///|
test "quickcheck: CSV export re-parses to the identical series" {
  @quickcheck.check((input : (Array[Int], Array[Double])) => {
    let (steps, vals) = input
    let s = qc_series(steps, vals)
    let g = @moonts.Series::from_csv_string(s.to_csv_string()) catch {
      e => fail("csv roundtrip failed to parse: \{e}")
    }
    @test.assert_eq(g.ts, s.ts)
    same_values(g.values, s.values)
  })
}
