///|
test "Series::new accepts aligned sorted columns" {
  let s = try @moonts.Series::new([1, 2, 3], [1.0, 2.0, 3.0]) catch {
    e => fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  @test.assert_eq(s.values.length(), 3)
}

///|
test "Series::new rejects mismatched lengths" {
  try (@moonts.Series::new([1, 2], [1.0]) : @moonts.Series) catch {
    _ => ()
  } noraise {
    _ => fail("expected LengthMismatch")
  }
}

///|
test "Series::new rejects empty input" {
  try (@moonts.Series::new([], []) : @moonts.Series) catch {
    _ => ()
  } noraise {
    _ => fail("expected Empty")
  }
}

///|
test "Series::new rejects unsorted timestamps" {
  try (@moonts.Series::new([2, 2, 3], [1.0, 2.0, 3.0]) : @moonts.Series) catch {
    _ => ()
  } noraise {
    _ => fail("expected NonIncreasingTimestamps")
  }
}

///|
let nan : Double = @moonts.nan

///|
fn series_of(values : Array[Double]) -> @moonts.Series raise {
  let n = values.length()
  let ts = Array(capacity=n)
  for i = 0; i < n; i = i + 1 {
    ts.push(i)
  }
  @moonts.Series::new(ts, values) catch {
    e => fail("unexpected error: \{e}")
  }
}

///|
/// Element-wise comparison that treats NaN positions as "must also be NaN",
/// since NaN != NaN makes plain array equality useless here.
fn assert_doubles_eq(got : Array[Double], want : Array[Double]) -> Unit raise {
  @test.assert_eq(got.length(), want.length())
  for i in 0..<got.length() {
    if want[i].is_nan() {
      if !got[i].is_nan() {
        @test.fail("index \{i}: expected NaN, got \{got[i]}")
      }
    } else {
      @test.assert_eq(got[i], want[i])
    }
  }
}

///|
test "rolling_mean matches pandas rolling(3).mean()" {
  // pandas: pd.Series([1,2,3,4,5]).rolling(3, min_periods=3).mean()
  let got = try series_of([1.0, 2.0, 3.0, 4.0, 5.0]).rolling_mean(3, 3) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_eq(got.values, [nan, nan, 2.0, 3.0, 4.0])
}

///|
test "rolling_mean with min_periods=1 matches pandas" {
  // pandas: pd.Series([1,2,3,4,5]).rolling(3, min_periods=1).mean()
  let got = try series_of([1.0, 2.0, 3.0, 4.0, 5.0]).rolling_mean(3, 1) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_eq(got.values, [1.0, 1.5, 2.0, 3.0, 4.0])
}

///|
test "rolling_mean skips NaN observations like pandas skipna=True" {
  // pandas: pd.Series([1, None, 3]).rolling(2, min_periods=1).mean()
  let got = try series_of([1.0, nan, 3.0]).rolling_mean(2, 1) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_eq(got.values, [1.0, 1.0, 3.0])
}

///|
test "rolling_mean yields NaN when valid count < min_periods" {
  // pandas: pd.Series([1, None, None]).rolling(2, min_periods=2).mean()
  let got = try series_of([1.0, nan, nan]).rolling_mean(2, 2) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_eq(got.values, [nan, nan, nan])
}

///|
test "rolling_sum matches pandas rolling(2).sum()" {
  // pandas: pd.Series([1,2,3,4,5]).rolling(2, min_periods=2).sum()
  let got = try series_of([1.0, 2.0, 3.0, 4.0, 5.0]).rolling_sum(2, 2) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_eq(got.values, [nan, 3.0, 5.0, 7.0, 9.0])
}

///|
/// Like assert_doubles_eq but compares non-NaN positions within a tolerance,
/// for results that go through sqrt and cannot be bit-exact.
fn assert_doubles_close(
  got : Array[Double],
  want : Array[Double],
  eps : Double,
) -> Unit raise {
  @test.assert_eq(got.length(), want.length())
  for i in 0..<got.length() {
    if want[i].is_nan() {
      if !got[i].is_nan() {
        @test.fail("index \{i}: expected NaN, got \{got[i]}")
      }
    } else if (got[i] - want[i]).abs() > eps {
      @test.fail("index \{i}: expected \{want[i]}, got \{got[i]}")
    }
  }
}

///|
test "rolling_min matches pandas rolling(3).min()" {
  // pandas: pd.Series([1,5,2,4,3]).rolling(3, min_periods=3).min()
  let got = try series_of([1.0, 5.0, 2.0, 4.0, 3.0]).rolling_min(3, 3) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_eq(got.values, [nan, nan, 1.0, 2.0, 2.0])
}

///|
test "rolling_max matches pandas rolling(3).max()" {
  // pandas: pd.Series([1,5,2,4,3]).rolling(3, min_periods=3).max()
  let got = try series_of([1.0, 5.0, 2.0, 4.0, 3.0]).rolling_max(3, 3) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_eq(got.values, [nan, nan, 5.0, 5.0, 4.0])
}

///|
test "rolling_std matches pandas rolling(3).std() with ddof=1" {
  // pandas: pd.Series([1,2,4]).rolling(3, min_periods=3).std()
  //       -> [nan, nan, 1.5275252316519468]
  let got = try series_of([1.0, 2.0, 4.0]).rolling_std(3, 3) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_close(got.values, [nan, nan, 1.5275252316519468], 0.000000001)
}

///|
test "rolling_std is NaN below two valid observations, like pandas" {
  // pandas: pd.Series([1,2]).rolling(2, min_periods=1).std()
  //       -> [nan, 0.7071067811865476]
  let got = try series_of([1.0, 2.0]).rolling_std(2, 1) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_close(got.values, [nan, 0.7071067811865476], 0.000000001)
}

///|
test "rolling_std skips NaN observations like pandas skipna=True" {
  // pandas: pd.Series([1,None,3,4]).rolling(3, min_periods=2).std()
  //       -> [nan, nan, 1.4142135623730951, 0.7071067811865476]
  let got = try series_of([1.0, nan, 3.0, 4.0]).rolling_std(3, 2) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  assert_doubles_close(
    got.values,
    [nan, nan, 1.4142135623730951, 0.7071067811865476],
    0.000000001,
  )
}

///|
test "rolling output keeps timestamps and length" {
  let s = series_of([4.0, 5.0, 6.0])
  let got = try s.rolling_sum(2, 1) catch {
    e => @test.fail("unexpected error: \{e}")
  } noraise {
    v => v
  }
  @test.assert_eq(got.ts, [0, 1, 2])
  @test.assert_eq(got.values.length(), 3)
}

///|
test "rolling rejects window < 1" {
  try (series_of([1.0]).rolling_mean(0, 1) : @moonts.Series) catch {
    @moonts.InvalidWindow(0) => ()
    e => @test.fail("expected InvalidWindow(0), got \{e}")
  } noraise {
    _ => @test.fail("expected InvalidWindow")
  }
}

///|
test "rolling rejects min_periods out of range" {
  try (series_of([1.0]).rolling_mean(2, 0) : @moonts.Series) catch {
    @moonts.InvalidMinPeriods(0) => ()
    e => @test.fail("expected InvalidMinPeriods(0), got \{e}")
  } noraise {
    _ => @test.fail("expected InvalidMinPeriods")
  }
  try (series_of([1.0]).rolling_sum(2, 3) : @moonts.Series) catch {
    @moonts.InvalidMinPeriods(3) => ()
    e => @test.fail("expected InvalidMinPeriods(3), got \{e}")
  } noraise {
    _ => @test.fail("expected InvalidMinPeriods")
  }
}
