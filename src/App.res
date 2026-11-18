// Thin viewer for status-api: fetch status.json, query the values each line
// needs by path, and print fixed-width lines (~34 columns, fits a phone).
//
// Queries are lenient: extra fields are ignored, a missing or null value
// prints as "n/a", and a line whose section is absent is left out — so the
// page keeps working while status-api's JSON evolves.

// Minimal DOM / fetch bindings.
type document
type element
type response
@val external document: document = "document"
@set external setTitle: (document, string) => unit = "title"
@val @scope("document") external getElementById: string => element = "getElementById"
@set external setTextContent: (element, string) => unit = "textContent"
@send @scope("classList") external addClass: (element, string) => unit = "add"
@send @scope("classList") external removeClass: (element, string) => unit = "remove"
@val external fetch: (string, {"cache": string}) => promise<response> = "fetch"
@get external ok: response => bool = "ok"
@get external httpStatus: response => int = "status"
@send external json: response => promise<JSON.t> = "json"

// --- queries ---

let get = (json: JSON.t, path) =>
  path->Array.reduce(Some(json), (acc, key) =>
    switch acc {
    | Some(JSON.Object(dict)) => dict->Dict.get(key)
    | _ => None
    }
  )

let has = (json, path) => get(json, path)->Option.isSome
let str = (json, path) =>
  switch get(json, path) {
  | Some(String(s)) => s
  | _ => "n/a"
  }
let num = (json, path, format) =>
  switch get(json, path) {
  | Some(Number(n)) => format(n)
  | _ => "n/a"
  }
let list = (json, path) =>
  switch get(json, path) {
  | Some(Array(items)) => items
  | _ => []
  }
let isTrue = (json, path) => get(json, path) == Some(Boolean(true))

// A line that only appears when its section exists.
let section = (json, path, line) => has(json, path) ? [line()] : []

// --- formatting ---

let units = ["B", "K", "M", "G", "T"]

let bytes = b => {
  let v = ref(b)
  let i = ref(0)
  while v.contents >= 1024. && i.contents < Array.length(units) - 1 {
    v := v.contents /. 1024.
    i := i.contents + 1
  }
  Float.toFixed(v.contents, ~digits=i.contents == 0 ? 0 : 1) ++ Array.getUnsafe(units, i.contents)
}
let perSec = b => bytes(b) ++ "/s"
let watts = w => Float.toFixed(w, ~digits=1) ++ "W"
let int = n => Float.toString(Math.floor(n))
let fixed2 = n => Float.toFixed(n, ~digits=2)
let duration = s => {
  let d = Math.floor(s /. 86400.)
  let h = Math.floor((s -. d *. 86400.) /. 3600.)
  let m = Math.floor((s -. d *. 86400. -. h *. 3600.) /. 60.)
  `${int(d)}d ${int(h)}h ${int(m)}m`
}
let pad = s => String.padEnd(s, 10, " ")

// --- what to show ---

let lines = s =>
  Array.flat([
    s->section(["sshd"], () => `sshd     ${str(s, ["sshd"])}`),
    s->section(["ssh24h"], () =>
      `SSH 24h  ok ${num(s, ["ssh24h", "ok"], int)} / reject ${num(s, ["ssh24h", "reject"], int)}`
    ),
    s->section(["uptime"], () => `up       ${num(s, ["uptime"], duration)}`),
    s->section(["load"], () =>
      `load     ${list(s, ["load"])->Array.map(l => num(l, [], fixed2))->Array.join(" ")}`
    ),
    s->section(["power"], () => {
      let gpu = isTrue(s, ["power", "gpuAsleep"]) ? "asleep" : num(s, ["power", "gpu"], watts)
      `power    CPU ${num(s, ["power", "cpu"], watts)} / GPU ${gpu}`
    }),
    s->section(["mem"], () =>
      `RAM      ${num(s, ["mem", "used"], bytes)}/${num(s, ["mem", "total"], bytes)} (free ${num(
          s,
          ["mem", "available"],
          bytes,
        )})`
    ),
    list(s, ["disks"])->Array.map(d =>
      `${pad(str(d, ["mount"]))} ${num(d, ["usedPct"], int)}% (${num(d, ["avail"], bytes)} free)`
    ),
    list(s, ["net"])->Array.flatMap(n => [
      `${pad(str(n, ["iface"]))} ↓${num(n, ["rxRate"], perSec)} ↑${num(n, ["txRate"], perSec)}`,
      `           total ↓${num(n, ["rx"], bytes)} ↑${num(n, ["tx"], bytes)}`,
    ]),
  ])

let refresh = async () => {
  let time = getElementById("time")
  try {
    let res = await fetch("status.json", {"cache": "no-store"})
    if !ok(res) {
      JsError.throwWithMessage(`HTTP ${Int.toString(httpStatus(res))}`)
    }
    let s = await json(res)
    let host = str(s, ["host"])
    document->setTitle(`${host} status`)
    getElementById("host")->setTextContent(host)
    getElementById("lines")->setTextContent(lines(s)->Array.join("\n"))
    time->setTextContent(num(s, ["time"], t => Date.fromTime(t *. 1000.)->Date.toLocaleString))
    time->removeClass("bad")
  } catch {
  // Unreachable means the box (or nginx) is down — that is signal too.
  | JsExn(e) =>
    time->setTextContent(`unreachable (${JsExn.message(e)->Option.getOr("error")})`)
    time->addClass("bad")
  | _ =>
    time->setTextContent("unreachable")
    time->addClass("bad")
  }
}

refresh()->ignore
setInterval(() => refresh()->ignore, 60 * 1000)->ignore
