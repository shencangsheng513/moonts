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
    ts.push(i.to_int64())
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

///|
fn series_at(ts : Array[Int64], values : Array[Double]) -> @moonts.Series raise {
  @moonts.Series::new(ts, values) catch {
    e => fail("unexpected error: \{e}")
  }
}

///|
test "resample(day, mean) bins points by UTC calendar day" {
  let s = series_at([0, 3600000, 7200000, 86400000], [1.0, 2.0, 3.0, 10.0])
  let got = s.resample(@moonts.Day, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [0, 86400000])
  assert_doubles_eq(got.values, [2.0, 10.0])
}

///|
test "resample emits NaN for empty buckets inside the range" {
  // pandas: two daily points one day apart produce three bins, middle NaN
  let s = series_at([0, 172800000], [7.0, 9.0])
  let got = s.resample(@moonts.Day, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [0, 86400000, 172800000])
  assert_doubles_eq(got.values, [7.0, nan, 9.0])
}

///|
test "resample(minute, sum) matches pandas resample('1min').sum()" {
  let s = series_at([0, 30000, 60000, 90000], [1.0, 2.0, 3.0, 4.0])
  let got = s.resample(@moonts.Minute, @moonts.Sum) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [0, 60000])
  assert_doubles_eq(got.values, [3.0, 7.0])
}

///|
test "resample(month) handles a year boundary" {
  // 2024-12-01T00:00:05Z and 2025-01-01T00:00:00Z (epoch ms via pandas)
  let s = series_at([1733011205000, 1735689600000], [5.0, 6.0])
  let got = s.resample(@moonts.Month, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [1733011200000, 1735689600000])
  assert_doubles_eq(got.values, [5.0, 6.0])
}

///|
test "resample(week) bins to Monday starts" {
  // 2026-09-20 is a Sunday -> week of Mon 2026-09-14;
  // 2026-09-23 is a Wednesday -> week of Mon 2026-09-21.
  let s = series_at([1789862400000, 1790121600000], [1.0, 2.0])
  let got = s.resample(@moonts.Week, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [1789344000000, 1789948800000])
  assert_doubles_eq(got.values, [1.0, 2.0])
}

///|
test "resample skips NaN inside buckets and supports Std" {
  let s = series_at([0, 1000, 2000], [2.0, nan, 4.0])
  let got = s.resample(@moonts.Day, @moonts.Std) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [0])
  assert_doubles_close(got.values, [1.4142135623730951], 0.000000001)
}

///|
test "resample guards against corrupted ranges" {
  // 1970 -> ~year 953,000 at month frequency exceeds ten million bins
  let s = series_at([0L, 30000000000000000L], [1.0, 2.0])
  try (s.resample(@moonts.Month, @moonts.Mean) : @moonts.Series) catch {
    @moonts.TooManyBins(_) => ()
  } noraise {
    _ => fail("expected TooManyBins")
  }
}

///|
test "Frequency::from_string parses aliases, rejects unknown" {
  @test.assert_eq(@moonts.Frequency::from_string("min"), Some(@moonts.Minute))
  @test.assert_eq(@moonts.Frequency::from_string("D"), Some(@moonts.Day))
  @test.assert_eq(
    @moonts.Frequency::from_string("5min"),
    Some(@moonts.Counted(5, @moonts.BasicFrequency::Minute)),
  )
  @test.assert_eq(@moonts.Frequency::from_string("ME"), Some(@moonts.Month))
  @test.assert_eq(
    @moonts.Frequency::from_string("2w"),
    Some(@moonts.Counted(2, @moonts.BasicFrequency::Week)),
  )
  @test.assert_eq(
    @moonts.Frequency::from_string("30S"),
    Some(@moonts.Counted(30, @moonts.BasicFrequency::Second)),
  )
  // zero/negative counts and counted months have no sane meaning
  @test.assert_eq(@moonts.Frequency::from_string("0min"), None)
  @test.assert_eq(@moonts.Frequency::from_string("-3h"), None)
  @test.assert_eq(@moonts.Frequency::from_string("2me"), None)
  @test.assert_eq(@moonts.Frequency::from_string("5x"), None)
  @test.assert_eq(@moonts.Frequency::from_string("min5"), None)
}

///|
test "ffill propagates last valid value, keeps leading NaN" {
  // pandas: pd.Series([1,None,None,4]).ffill() -> [1,1,1,4]
  let got = series_of([1.0, nan, nan, 4.0]).ffill()
  assert_doubles_eq(got.values, [1.0, 1.0, 1.0, 4.0])
  // pandas: pd.Series([None,2,None]).ffill() -> [None,2,2]
  let lead = series_of([nan, 2.0, nan]).ffill()
  assert_doubles_eq(lead.values, [nan, 2.0, 2.0])
}

///|
test "bfill propagates next valid value, keeps trailing NaN" {
  // pandas: pd.Series([None,2,None,3]).bfill() -> [2,2,3,3]
  let got = series_of([nan, 2.0, nan, 3.0]).bfill()
  assert_doubles_eq(got.values, [2.0, 2.0, 3.0, 3.0])
  // pandas: pd.Series([1,None]).bfill() -> [1,None]
  let tail = series_of([1.0, nan]).bfill()
  assert_doubles_eq(tail.values, [1.0, nan])
}

///|
test "fill_constant replaces every NaN" {
  let got = series_of([1.0, nan, nan]).fill_constant(0.0)
  assert_doubles_eq(got.values, [1.0, 0.0, 0.0])
}

///|
test "drop_missing removes NaN rows keeping alignment" {
  let s = series_at([10L, 20L, 30L], [1.0, nan, 3.0])
  let got = s.drop_missing() catch { e => fail("unexpected error: \{e}") }
  @test.assert_eq(got.ts, [10L, 30L])
  assert_doubles_eq(got.values, [1.0, 3.0])
}

///|
test "drop_missing rejects all-NaN input to preserve the non-empty invariant" {
  let s = series_of([nan, nan])
  try (s.drop_missing() : @moonts.Series) catch {
    @moonts.Empty => ()
    e => fail("unexpected error: \{e}")
  } noraise {
    _ => fail("expected Empty")
  }
}

///|
test "resample then ffill closes gap buckets" {
  let s = series_at([0, 172800000], [7.0, 9.0])
  let r = s.resample(@moonts.Day, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  assert_doubles_eq(r.ffill().values, [7.0, 7.0, 9.0])
}

///|
test "from_csv_string parses plain rows" {
  let s = @moonts.Series::from_csv_string("1000,1.0\n2000,2.5\n3000,4.0") catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(s.ts, [1000L, 2000L, 3000L])
  assert_doubles_eq(s.values, [1.0, 2.5, 4.0])
}

///|
test "from_csv_string skips auto-detected header and reads NaN cells" {
  let s = @moonts.Series::from_csv_string(
    "timestamp,value\n1000,1.0\n2000,\n3000,NaN",
  ) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(s.ts, [1000L, 2000L, 3000L])
  assert_doubles_eq(s.values, [1.0, nan, nan])
}

///|
test "from_csv_string tolerates CRLF, blank lines, and padded fields" {
  let s = @moonts.Series::from_csv_string(
    "\r\ntimestamp,value\r\n1000 , 1.0\r\n\r\n2000,2.0\r\n",
  ) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(s.ts, [1000L, 2000L])
  assert_doubles_eq(s.values, [1.0, 2.0])
}

///|
test "from_csv_string reports the 1-based line number of malformed rows" {
  try
    (@moonts.Series::from_csv_string("1000,1.0\nbroken") : @moonts.Series)
  catch {
    @moonts.Malformed(2, _) => ()
    e => fail("unexpected error: \{e}")
  } noraise {
    _ => fail("expected Malformed on line 2")
  }
}

///|
test "blank csv raises Empty and unsorted rows raise NonIncreasing" {
  try (@moonts.Series::from_csv_string("") : @moonts.Series) catch {
    @moonts.Empty => ()
    e => fail("unexpected error: \{e}")
  } noraise {
    _ => fail("expected Empty")
  }
  try
    (@moonts.Series::from_csv_string("2000,1.0\n1000,2.0") : @moonts.Series)
  catch {
    @moonts.NonIncreasingTimestamps => ()
    e => fail("unexpected error: \{e}")
  } noraise {
    _ => fail("expected NonIncreasingTimestamps")
  }
}

///|
test "to_csv_string round-trips through from_csv_string" {
  let s = series_at([1000L, 2000L, 3000L], [1.0, nan, 3.0])
  let text = s.to_csv_string()
  if !text.has_prefix("timestamp,value\n") {
    fail("to_csv_string must start with the header row")
  }
  let back = @moonts.Series::from_csv_string(text) catch {
    e => fail("round-trip parse failed: \{e}")
  }
  @test.assert_eq(back.ts, s.ts)
  assert_doubles_eq(back.values, s.values)
}

///|
test "rolling_by matches pandas rolling('2h'): half-open duration windows" {
  // pandas: Series([1,2,3,4], index=ts).rolling('2000ms').mean()
  // ts 0 is exactly 2000ms older than ts 2000 (excluded), and likewise
  // ts 2000 at t=4000, leaving that final window one observation.
  let s = series_at([0L, 1000L, 2000L, 4000L], [1.0, 2.0, 3.0, 4.0])
  let got = s.rolling_by(2000L, 1, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  assert_doubles_eq(got.values, [1.0, 1.5, 2.5, 4.0])
}

///|
test "rolling_by skips NaN and keeps min_periods semantics" {
  let s = series_at([0L, 1000L, 2000L], [1.0, nan, 3.0])
  let g1 = s.rolling_by(2000L, 1, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  assert_doubles_eq(g1.values, [1.0, 1.0, 3.0])
  let g2 = s.rolling_by(2000L, 2, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  // only the first window holds two valid observations (1.0 and nan -> one
  // valid at ts 0 is alone; at ts 1000 both ts 0 and 1000 are inside)
  assert_doubles_eq(g2.values, [nan, nan, nan])
}

///|
test "rolling_by rejects non-positive duration and unreachable min_periods" {
  let s = series_at([0L, 1000L], [1.0, 2.0])
  try (s.rolling_by(0L, 1, @moonts.Mean) : @moonts.Series) catch {
    @moonts.InvalidWindowMs(0L) => ()
    e => fail("expected InvalidWindowMs(0), got \{e}")
  } noraise {
    _ => fail("expected InvalidWindowMs")
  }
  try (s.rolling_by(1000L, 3, @moonts.Mean) : @moonts.Series) catch {
    @moonts.InvalidMinPeriods(3) => ()
    e => fail("expected InvalidMinPeriods(3), got \{e}")
  } noraise {
    _ => fail("expected InvalidMinPeriods")
  }
}

///|
test "resample(5min, sum) matches pandas resample('5min').sum()" {
  let s = series_at([0, 300000, 330000], [1.0, 2.0, 4.0])
  let five_min = @moonts.Counted(5, @moonts.BasicFrequency::Minute)
  let got = s.resample(five_min, @moonts.Sum) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [0, 300000])
  assert_doubles_eq(got.values, [1.0, 6.0])
}

///|
test "resample(2h, sum) bins on even epoch-hour boundaries" {
  // pandas: points at 00:00, 01:00 fall in the 00:00-02:00 bin;
  // the point at 02:00 opens the next bin
  let s = series_at([0, 3600000, 7200000], [1.0, 2.0, 3.0])
  let two_h = @moonts.Counted(2, @moonts.BasicFrequency::Hour)
  let got = s.resample(two_h, @moonts.Sum) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [0, 7200000])
  assert_doubles_eq(got.values, [3.0, 3.0])
}

///|
test "resample(5min, mean) fills interior gaps with NaN" {
  let s = series_at([0, 900000], [2.0, 5.0])
  let five_min = @moonts.Counted(5, @moonts.BasicFrequency::Minute)
  let got = s.resample(five_min, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [0, 300000, 600000, 900000])
  assert_doubles_eq(got.values, [2.0, nan, nan, 5.0])
}

///|
test "resample(2w, mean) keeps Monday-anchored two-week bins" {
  // 2024-01-01 (Mon) and 2024-01-08 (Mon) are one week apart, so with a
  // two-week step anchored on Mondays they land in different bins:
  // [2023-12-25, 2024-01-08) and [2024-01-08, ...).
  let s = series_at([1704067200000, 1704672000000], [3.0, 5.0])
  let two_w = @moonts.Counted(2, @moonts.BasicFrequency::Week)
  let got = s.resample(two_w, @moonts.Mean) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [1703462400000, 1704672000000])
  assert_doubles_eq(got.values, [3.0, 5.0])
}

///|
test "resample buckets pre-epoch timestamps with floor semantics" {
  // -1000 ms is 1 second before 1970-01-01, still inside the day that
  // starts at -86400000; truncating % would wrongly round toward zero.
  let s = series_at([-1000, 86399000], [1.0, 2.0])
  let got = s.resample(@moonts.Day, @moonts.Sum) catch {
    e => fail("unexpected error: \{e}")
  }
  @test.assert_eq(got.ts, [-86400000, 0])
  assert_doubles_eq(got.values, [1.0, 2.0])
}
