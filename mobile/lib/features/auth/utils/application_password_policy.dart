import 'dart:convert';

const int applicationPasswordMaxUtf8Bytes = 72;

bool isApplicationPasswordWithinByteLimit(String password) {
  return utf8.encode(password).length <= applicationPasswordMaxUtf8Bytes;
}
