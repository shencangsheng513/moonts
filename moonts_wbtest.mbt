///|
/// Whitebox: error constructors are read-only outside the package
/// (`pub suberror` only opens matching), so pinning Show wording
/// has to happen inside it.
test "error Show texts are stable user-facing strings" {
  // Error messages are CLI output; pin the full wording so renames break
  // tests (this core has no String::contains, so equality is the check).
  @test.assert_eq(
    LengthMismatch(2, 3).to_string(),
    "length mismatch: ts has 2, values has 3",
  )
  @test.assert_eq(Empty.to_string(), "series must not be empty")
  @test.assert_eq(
    NonIncreasingTimestamps.to_string(),
    "timestamps must be strictly increasing",
  )
  @test.assert_eq(
    InvalidWindow(0).to_string(),
    "window must be at least 1, got 0",
  )
  @test.assert_eq(
    InvalidWindowMs(0L).to_string(),
    "duration window must be at least 1 ms, got 0",
  )
  @test.assert_eq(
    InvalidMinPeriods(5).to_string(),
    "min_periods must satisfy 1 <= m <= window, got 5",
  )
  @test.assert_eq(
    TooManyBins(200).to_string(),
    "resample reached 200 bins (limit 10000000); the input range looks corrupted",
  )
  @test.assert_eq(
    Malformed(7, "x,y,z").to_string(),
    "line 7: expected 'ms,value', got 'x,y,z'",
  )
}
