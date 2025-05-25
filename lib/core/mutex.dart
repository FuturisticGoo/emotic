/// A simple async mutex which imposes limits to simultaneous access to
/// critical region. </br>
/// Use like this:
/// ```dart
/// final mutex = Mutex(limit: 1);
/// await mutex.acquire();
/// // Critical region, only 1 access allowed here
/// await mutex.release();
/// ```
///
/// [limit] specifies the number of simultaneous accesses allowed.
// TODO: maybe add a timeout for access?
final class Mutex {
  final int _acquireLimit;
  static int _acquireCount = 0;

  const Mutex({int limit = 1}) : _acquireLimit = limit;

  Future<void> acquire() async {
    while (_acquireCount >= _acquireLimit) {
      await Future.delayed(Duration.zero);
    }
    _acquireCount++;
    return;
  }

  Future<void> release() async {
    _acquireCount--;
  }
}
