// Run with osascript -l JavaScript. Read local history only: never mount a disk.
// SnapshotDates records destination backups, unlike local/attempt snapshot dates.
ObjC.import("Foundation");

function run() {
  const prefs = $.NSDictionary.dictionaryWithContentsOfFile(
    "/Library/Preferences/com.apple.TimeMachine.plist",
  );
  if (!prefs || prefs.isNil()) return "history\tunavailable";
  const destinations = prefs.objectForKey("Destinations");
  if (!destinations || destinations.isNil() || !destinations.count) return "history\tunavailable";

  let latest = 0;
  let latestName = "";
  const names = [];
  for (let i = 0; i < destinations.count; i++) {
    const destination = destinations.objectAtIndex(i);
    const nameValue = destination.objectForKey("LastKnownVolumeName");
    const name = nameValue && !nameValue.isNil() ? ObjC.unwrap(nameValue) : "Unknown destination";
    names.push(name);
    const dates = destination.objectForKey("SnapshotDates");
    if (!dates || dates.isNil()) continue;
    for (let j = 0; j < dates.count; j++) {
      const epoch = Number(dates.objectAtIndex(j).timeIntervalSince1970);
      if (epoch > latest) {
        latest = epoch;
        latestName = name;
      }
    }
  }
  const clean = (value) => value.replace(/[\t\r\n]/g, " ");
  const result = ["destination\t" + clean(names.join(", "))];
  if (latest > 0) {
    result.push("last_backup\t" + Math.floor(latest));
    result.push("last_destination\t" + clean(latestName));
  } else {
    result.push("history\tunavailable");
  }
  return result.join("\n");
}
