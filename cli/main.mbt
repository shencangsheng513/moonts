///|
/// moonts demo CLI. CSV text is passed as a command-line argument and
/// the result is printed to stdout, so the file-free core promise
/// holds on every backend.
suberror CliError {
  Usage(String)
} derive(Debug)

///|
impl Show for CliError with fn output(self : CliError, logger) {
  match self {
    Usage(msg) => logger.write_string("usage error: \{msg}")
  }
}

///|

///|
let usage : String = "moonts <command> [args...]\n  (no args) or `demo`  built-in demo pipeline\n  resample <freq> <agg> [--ffill] <csv>\n  rolling <count | duration> <agg> <csv>\nfreq: s | min | h | d | w | me\nagg:  mean | sum | min | max | std\nduration: <n><s|min|h|d|w>, e.g. 90min, 2h, 7d"

///|
fn parse_agg(s : String) -> @moonts.Agg raise CliError {
  match s.to_lower() {
    "mean" => @moonts.Mean
    "sum" => @moonts.Sum
    "min" => @moonts.Min
    "max" => @moonts.Max
    "std" => @moonts.Std
    _ => raise Usage("bad agg '\{s}', expected mean/sum/min/max/std")
  }
}

///|
fn parse_freq(s : String) -> @moonts.Frequency raise CliError {
  match @moonts.Frequency::from_string(s) {
    Some(f) => f
    None => raise Usage("bad frequency '\{s}', expected s/min/h/d/w/me")
  }
}

///|
/// `30min` -> 1800000 ms and friends; None means "not a duration",
/// letting the caller fall back to a plain count window.
fn parse_duration_ms(s : String) -> Int64? {
  let lower = s.to_lower()
  let units = [
    ("min", 60000L),
    ("s", 1000L),
    ("h", 3600000L),
    ("d", 86400000L),
    ("w", 604800000L),
  ]
  for (suffix, ms) in units {
    if lower.has_suffix(suffix) {
      let head = lower[:lower.length() - suffix.length()]
      let count = Some(@string.FromStr::from_str(head)) catch { _ => None }
      return count.map(n => n * ms)
    }
  }
  None
}

///|
fn demo_csv() -> String raise {
  let input = "timestamp,value\n0,1.0\n3600000,2.0\n7200000,3.0\n172800000,9.0\n176400000,11.0"
  let s = @moonts.Series::from_csv_string(input)
  s.resample(@moonts.Day, @moonts.Mean).to_csv_string()
}

///|
fn run(argv : Array[String]) -> String raise {
  match argv.length() {
    0 => demo_csv()
    1 if argv[0] == "demo" => demo_csv()
    n if n >= 4 && argv[0] == "rolling" => {
      let agg = parse_agg(argv[2])
      let s = @moonts.Series::from_csv_string(argv[3])
      match parse_duration_ms(argv[1]) {
        Some(ms) => s.rolling_by(ms, 1, agg).to_csv_string()
        None => {
          let window = @string.FromStr::from_str(argv[1][:]) catch {
            _ =>
              raise Usage(
                "bad window '\{argv[1]}': expected a positive int or a duration like 30min/2h/7d",
              )
          }
          let out = match agg {
            @moonts.Mean => s.rolling_mean(window, 1)
            @moonts.Sum => s.rolling_sum(window, 1)
            @moonts.Min => s.rolling_min(window, 1)
            @moonts.Max => s.rolling_max(window, 1)
            @moonts.Std => s.rolling_std(window, 1)
          }
          out.to_csv_string()
        }
      }
    }
    n if n >= 4 && argv[0] == "resample" => {
      let (csv_at, ffill) = if n == 4 {
        (3, false)
      } else if n == 5 && argv[3] == "--ffill" {
        (4, true)
      } else {
        raise Usage(
          "resample: expected 'resample <freq> <agg> [--ffill] <csv>'",
        )
      }
      let freq = parse_freq(argv[1])
      let agg = parse_agg(argv[2])
      let s = @moonts.Series::from_csv_string(argv[csv_at])
      let out = s.resample(freq, agg)
      if ffill {
        out.ffill().to_csv_string()
      } else {
        out.to_csv_string()
      }
    }
    _ => raise Usage("unrecognized arguments; here is the help:\n\{usage}")
  }
}

///|
fn main {
  let argv = @env.args()[1:].to_owned()
  println(
    run(argv) catch {
      Usage(msg) => "error: \{msg}\n\n\{usage}"
      e => "error: \{e}"
    },
  )
}
