import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Time-ordered UUID (v7) so ids sort by creation time — friendly to sync.
String newId() => _uuid.v7();
