// Picking the shift a face scan belongs to.
//
// Guards were shown an empty "Select Shift" dropdown and had to work out
// which of "1 Morning Shift" / "2 Night Shift" they were on before the camera
// would open — the wrong pick lands the punch on the wrong shift. The screens
// now open with the shift for the current time already chosen, and the guard
// only has to change it in the rare case it is wrong (a night guard clocking
// in early, say).
//
// The `Shift_Timings` reference rows carry the shift's start time in
// `commonRefValue` — the backend resolves a scan the same way, formatting the
// current time as `h:mm a` and matching it against that column
// (`getIdByCurrentTime` → `findByRefKeyValueForAttendance`). We read the same
// column, but treat it as the *start* of a window that runs until the next
// shift begins, so any time of day resolves rather than only the exact minute
// a shift starts.

/// Minutes past midnight for a shift's start time, or null if unparseable.
///
/// Accepts what the reference table realistically holds: "6:00 AM", "06:00 AM",
/// "6:00PM", "6 AM", and 24-hour "18:00".
int? shiftStartMinutes(String? value) {
  if (value == null) return null;
  final text = value.trim().toUpperCase();
  if (text.isEmpty) return null;

  final match =
      RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$').firstMatch(text);
  if (match == null) return null;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2) ?? '0');
  final meridiem = match.group(3);

  if (minute > 59) return null;

  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    if (meridiem == 'AM') {
      if (hour == 12) hour = 0; // 12 AM is midnight.
    } else {
      if (hour != 12) hour += 12; // 12 PM is already noon.
    }
  } else if (hour > 23) {
    return null;
  }

  return hour * 60 + minute;
}

/// The shift covering [now], as an id from [shifts], or null if it cannot be
/// worked out — in which case the screen leaves the dropdown empty and the
/// guard picks, exactly as before.
///
/// [shifts] are the raw reference maps: `id`, `refValue` (the label shown),
/// `commonRefValue` (the start time) and `commonRefKey`.
int? shiftIdForTime(List<Map<String, dynamic>> shifts, DateTime now) {
  if (shifts.isEmpty) return null;

  final nowMinutes = now.hour * 60 + now.minute;

  // Preferred path: real start times from the reference data.
  final timed = <MapEntry<int, Map<String, dynamic>>>[];
  for (final shift in shifts) {
    final start = shiftStartMinutes(shift['commonRefValue'] as String?);
    if (start != null) timed.add(MapEntry(start, shift));
  }

  if (timed.isNotEmpty) {
    timed.sort((a, b) => a.key.compareTo(b.key));
    // The last shift that has already started today. Before the first start of
    // the day we are still inside the last shift, which began yesterday — that
    // is the night guard scanning out at 5am.
    var chosen = timed.last;
    for (final entry in timed) {
      if (entry.key <= nowMinutes) chosen = entry;
    }
    if (nowMinutes < timed.first.key) chosen = timed.last;
    return chosen.value['id'] as int?;
  }

  // Fallback: no usable start times, so go by what the shift is called.
  // Daytime is 6am–6pm, which is how these shifts are actually run.
  final wantsNight = nowMinutes < 6 * 60 || nowMinutes >= 18 * 60;
  const dayWords = ['morning', 'day', 'general', 'first'];
  const nightWords = ['night', 'evening', 'second'];

  for (final shift in shifts) {
    final label = '${shift['refValue'] ?? ''} ${shift['commonRefKey'] ?? ''}'
        .toLowerCase();
    final words = wantsNight ? nightWords : dayWords;
    if (words.any(label.contains)) return shift['id'] as int?;
  }

  return null;
}

/// How long after a shift ends a guard is still assumed to be logging out of
/// *that* shift rather than into the one that just started.
///
/// Four hours covers a normal handover plus the overtime these guards
/// actually work. Past that the guard is treated as belonging to the shift now
/// running, and can still change the dropdown.
///
/// Widening this trades one end for the other: it is a 12-hour window being
/// slid later, so every hour gained for a late finish is an hour lost at the
/// start, where someone leaving early gets offered the previous shift instead.
const Duration kLogoutGrace = Duration(hours: 4);

/// The shift a guard logging out at [now] is most likely *ending*.
///
/// Logging out is not the same question as logging in. A guard logs in at the
/// start of their shift, so the shift running now is the right guess — but
/// they log out at the *end* of it, by which time the next shift has usually
/// already begun. At 8pm the morning guard going home would otherwise be
/// offered "Night Shift", and the backend looks the login record up **by
/// shift** (`logoutSubmitAttandance` → `findListOfAttendance(userId, date,
/// shiftId)`), so the wrong shift does not just mislabel the punch — it fails
/// the logout outright with "No login record found to perform logout".
///
/// Resolving the time [kLogoutGrace] earlier keeps the guard on the shift they
/// have just finished for as long as a handover realistically takes.
int? shiftIdForLogout(List<Map<String, dynamic>> shifts, DateTime now) =>
    shiftIdForTime(shifts, now.subtract(kLogoutGrace));

/// How early a guard can turn up and still be offered the shift they are about
/// to *start* rather than the one still running.
///
/// Guards report before their shift begins — a morning guard at ten to six is
/// starting the morning shift, not joining the night one that is about to end.
/// One hour covers reporting early without reaching so far back that a guard
/// arriving mid-shift is offered the wrong one.
const Duration kEarlyArrivalGrace = Duration(hours: 1);

/// The shift a guard logging in at [now] is most likely *starting*.
///
/// Resolving the time [kEarlyArrivalGrace] later lets someone who reports
/// before the hour be offered the shift they came in for. It is the mirror of
/// [shiftIdForLogout]: logout looks back to the shift just finished, login
/// looks forward to the one about to begin.
int? shiftIdForLogin(List<Map<String, dynamic>> shifts, DateTime now) =>
    shiftIdForTime(shifts, now.add(kEarlyArrivalGrace));

class ShiftTiming {
  final int id;
  final int referenceTypeId;
  final String commonRefKey;
  final String commonRefValue;
  final String? value;
  final String? name;
  final String? phoneNumberPattren;
  final String? refValue;
  final int? refOrder;

  ShiftTiming({
    required this.id,
    required this.referenceTypeId,
    required this.commonRefKey,
    required this.commonRefValue,
    this.value,
    this.name,
    this.phoneNumberPattren,
    this.refValue,
    this.refOrder,
  });

  factory ShiftTiming.fromJson(Map<String, dynamic> json) {
    return ShiftTiming(
      id: json['id'] ?? 0,
      referenceTypeId: json['referenceTypeId'] ?? 0,
      commonRefKey: json['commonRefKey'] ?? '',
      commonRefValue: json['commonRefValue'] ?? '',
      value: json['value'],
      name: json['name'],
      phoneNumberPattren: json['phoneNumberPattren'],
      refValue: json['refValue'],
      refOrder: json['refOrder'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referenceTypeId': referenceTypeId,
      'commonRefKey': commonRefKey,
      'commonRefValue': commonRefValue,
      'value': value,
      'name': name,
      'phoneNumberPattren': phoneNumberPattren,
      'refValue': refValue,
      'refOrder': refOrder,
    };
  }
}
