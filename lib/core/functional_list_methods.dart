extension FunctionalAdditions<E> on List<E> {
  List<E> addIfNotExists(E itemToAdd) {
    return {
      ...this,
      itemToAdd,
    }.toList();
  }

  List<E> removeIfExists(E itemToRemove) {
    return where((element) => element != itemToRemove).toList();
  }

  E? singleWhereOrNull(bool Function(E) test) {
    try {
      return singleWhere(test);
    } on StateError {
      return null;
    }
  }
}
