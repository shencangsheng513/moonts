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
