class Farm {
  final int? id;
  final String name, location;
  final double? latitude, longitude;
  const Farm(
      {this.id,
      required this.name,
      required this.location,
      this.latitude,
      this.longitude});
}

class Field {
  final int? id, farmId;
  final String name, area;
  const Field(
      {this.id, required this.farmId, required this.name, required this.area});
}

class NpkResult {
  final double nitrogen, phosphorus, potassium;
  final String unit;
  final String source;
  const NpkResult(this.nitrogen, this.phosphorus, this.potassium,
      {this.unit = 'mg/kg', this.source = 'device'});

  bool get isValid =>
      unit == 'mg/kg' &&
      nitrogen.isFinite &&
      nitrogen >= 0 &&
      phosphorus.isFinite &&
      phosphorus >= 0 &&
      potassium.isFinite &&
      potassium >= 0;
}

class SoilTest {
  final int? id, fieldId;
  final DateTime testedAt;
  final NpkResult result;
  final String note;
  final bool favorite;
  const SoilTest(
      {this.id,
      required this.fieldId,
      required this.testedAt,
      required this.result,
      this.note = '',
      this.favorite = false});
}

class CalendarEvent {
  final String type, title;
  final DateTime date;
  final int? id, farmId;
  final bool completed;
  const CalendarEvent(this.type, this.title, this.date,
      {this.id, this.farmId, this.completed = false});
}
