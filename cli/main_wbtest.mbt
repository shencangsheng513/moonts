///|
test "demo pipeline shows a NaN gap bucket on day 1" {
  let out = run(["demo"]) catch { e => fail("demo failed: \{e}") }
  let s = @moonts.Series::from_csv_string(out) catch {
    e => fail("demo output not parseable: \{e}")
  }
  @test.assert_eq(s.values.length(), 3)
  @test.assert_eq(s.values[0], 2.0)
  @test.assert_eq(s.values[1].is_nan(), true)
  @test.assert_eq(s.values[2], 10.0)
}

///|
test "resample without --ffill keeps the gap visible" {
  let csv = "timestamp,value\n0,1.0\n3600000,2.0\n7200000,3.0\n172800000,9.0\n176400000,11.0"
  let out = run(["resample", "d", "mean", csv]) catch {
    e => fail("unexpected error: \{e}")
  }
  let s = @moonts.Series::from_csv_string(out) catch {
    e => fail("output not parseable: \{e}")
  }
  @test.assert_eq(s.ts, [0L, 86400000L, 172800000L])
  @test.assert_eq(s.values[1].is_nan(), true)
}

///|
test "resample with --ffill before the csv fills the gap bucket" {
  let csv = "timestamp,value\n0,1.0\n3600000,2.0\n7200000,3.0\n172800000,9.0\n176400000,11.0"
  let out = run(["resample", "d", "mean", "--ffill", csv]) catch {
    e => fail("unexpected error: \{e}")
  }
  let s = @moonts.Series::from_csv_string(out) catch {
    e => fail("output not parseable: \{e}")
  }
  assert_doubles(s.values, [2.0, 2.0, 10.0])
}

///|
test "rolling 2 mean over three rows" {
  let out = run(["rolling", "2", "mean", "1000,1.0\n2000,2.0\n3000,3.0"]) catch {
    e => fail("unexpected error: \{e}")
  }
  let s = @moonts.Series::from_csv_string(out) catch {
    e => fail("output not parseable: \{e}")
  }
  assert_doubles(s.values, [1.0, 1.5, 2.5])
}

///|
test "unknown subcommand raises Usage" {
  try (run(["bogus"]) : String) catch {
    Usage(_) => ()
    e => fail("expected Usage, got \{e}")
  } noraise {
    _ => fail("expected Usage")
  }
}

///|
test "bad frequency and bad window raise Usage" {
  try (run(["resample", "fortnight", "mean", "1000,1.0"]) : String) catch {
    Usage(_) => ()
    e => fail("expected Usage, got \{e}")
  } noraise {
    _ => fail("expected Usage for bad frequency")
  }
  try (run(["rolling", "abc", "mean", "1000,1.0"]) : String) catch {
    Usage(_) => ()
    e => fail("expected Usage, got \{e}")
  } noraise {
    _ => fail("expected Usage for bad window")
  }
}

///|
fn assert_doubles(got : Array[Double], want : Array[Double]) -> Unit raise {
  @test.assert_eq(got.length(), want.length())
  for i in 0..<want.length() {
    if got[i].is_nan() != want[i].is_nan() {
      fail("index \{i}: nan-ness differs (got \{got[i]}, want \{want[i]})")
    } else if !got[i].is_nan() {
      @test.assert_eq(got[i], want[i])
    }
  }
}

///|
test "rolling accepts duration windows like 2h" {
  let out = run(["rolling", "2h", "mean", "0,1.0\n3600000,2.0\n7200000,3.0"]) catch {
    e => fail("unexpected error: \{e}")
  }
  let s = @moonts.Series::from_csv_string(out) catch {
    e => fail("output not parseable: \{e}")
  }
  // ts 0 is exactly 2h older than ts 7200000, so the last window is
  // just (2.0, 3.0) -> 2.5
  assert_doubles(s.values, [1.0, 1.5, 2.5])
}

///|
test "bad duration unit still raises Usage" {
  try (run(["rolling", "2x", "mean", "0,1.0\n1000,2.0"]) : String) catch {
    Usage(_) => ()
    e => fail("expected Usage, got \{e}")
  } noraise {
    _ => fail("expected Usage for '2x'")
  }
}
