///|
/// Error raised while parsing CSV text. The Int is a 1-based line
/// number and the StringView is the offending line content.
pub suberror CsvError {
  Malformed(Int, StringView)
}

///|
pub impl Show for CsvError with fn output(self : CsvError, logger) {
  match self {
    Malformed(no, content) =>
      logger.write_string("line \{no}: expected 'ms,value', got '\{content}'")
  }
}

///|
pub extend CsvError with Show::{to_string, output}

///|
fn parse_i64_opt(s : StringView) -> Int64? {
  Some(@string.FromStr::from_str(s)) catch {
    _ => None
  }
}

///|
fn parse_value_opt(s : StringView) -> Double? {
  if s == "" || s.to_owned().to_lower() == "nan" {
    Some(nan)
  } else {
    Some(@string.FromStr::from_str(s)) catch {
      _ => None
    }
  }
}

///|
/// Parse CSV text with one timestamp,value record per line. A leading
/// header line ('timestamp,value', case-insensitive on the second
/// field) is auto-detected and skipped. Empty lines are ignored, CR is
/// tolerated (CRLF files), and an empty value or nan (any case)
/// becomes a missing observation. Blank input raises Empty; unsorted
/// rows raise NonIncreasingTimestamps via Series::new.
pub fn Series::from_csv_string(text : String) -> Series raise {
  let ts_out = Array(capacity=16)
  let val_out = Array(capacity=16)
  let mut seen_data = false
  let mut lineno = 0
  for raw in text.split("\n") {
    lineno = lineno + 1
    let line = raw.to_owned()
    let fields = Array(capacity=2)
    for f in line.split(",") {
      fields.push(f.trim())
    }
    if fields.length() == 1 && fields[0] == "" {
      continue
    }
    if fields.length() != 2 {
      raise Malformed(lineno, line.trim())
    }
    let t = parse_i64_opt(fields[0])
    let v = parse_value_opt(fields[1])
    let maybe_header = fields[1].to_owned().to_lower() == "value"
    match (t, v) {
      (Some(t), Some(v)) => {
        ts_out.push(t)
        val_out.push(v)
        seen_data = true
      }
      (None, _) if !seen_data && maybe_header => ()
      _ => raise Malformed(lineno, line.trim())
    }
  }
  Series::new(ts_out, val_out)
}

///|
/// Serialize to CSV text, always with a timestamp,value header. Missing
/// values are written as an empty field (pandas convention).
pub fn Series::to_csv_string(self : Series) -> String {
  let buf = StringBuilder()
  buf.write_string("timestamp,value\n")
  for i in 0..<self.values.length() {
    buf.write_string(self.ts[i].to_string())
    buf.write_string(",")
    if !self.values[i].is_nan() {
      buf.write_string(self.values[i].to_string())
    }
    buf.write_string("\n")
  }
  buf.to_string()
}
