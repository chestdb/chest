part of 'chest.dart';

T identityFunction<T>(T value) => value;

class IndexedValue<Root, Value> {
  IndexedValue(this.path, this.fromRoot);

  final List<int> path;
  final Value Function(Root object) fromRoot;
}

abstract class IndexedClass<Root> {
  List<IndexedValue<Root, dynamic>> get values;
}

typedef QueryBuilder<V, IV> = Query<IV> Function(IV value);

abstract class QueryResult<V> {}

typedef IndexedValueExtractor<O, V> = V Function(O object);

abstract class Query<O> {
  operator &(Query<O> other) => AndQuery([this, other]);
  operator |(Query<O> other) => OrQuery([this, other]);
}

class EqualsQuery<O, V> extends Query<O> {
  EqualsQuery(this.property, this.value);

  final IndexedValue<O, V> property;
  final V value;
}

class IsLargerThanQuery<O, V> extends Query<O> {
  IsLargerThanQuery(this.property, this.value, this.isInclusive);

  final IndexedValue<O, V> property;
  final V value;
  final bool isInclusive;
}

class IsSmallerThanQuery<O, V> extends Query<O> {
  IsSmallerThanQuery(this.property, this.value, this.isInclusive);

  final IndexedValue<O, V> property;
  final V value;
  final bool isInclusive;
}

class IsBetweenQuery<O, V> extends Query<O> {
  IsBetweenQuery(
    this.property,
    this.lower,
    this.upper,
    this.isLowerInclusive,
    this.isUpperInclusive,
  );

  final IndexedValue<O, V> property;
  final V lower;
  final V upper;
  final bool isLowerInclusive;
  final bool isUpperInclusive;
}

class AndQuery<V> extends Query<V> {
  AndQuery(this.parts);

  final List<Query<V>> parts;

  operator &(Query<V> other) => parts.add(other);
}

class OrQuery<V> extends Query<V> {
  OrQuery(this.parts);

  final List<Query<V>> parts;

  operator |(Query<V> other) => parts.add(other);
}

extension IndexedValueActions<O, V> on IndexedValue<O, V> {
  Query<O> equals(V value) => EqualsQuery(this, value);

  Query<O> operator >(V value) => IsLargerThanQuery(this, value, false);
  Query<O> operator >=(V value) => IsLargerThanQuery(this, value, true);
  Query<O> operator <(V value) => IsSmallerThanQuery(this, value, false);
  Query<O> operator <=(V value) => IsSmallerThanQuery(this, value, true);

  Query<O> isBetween(
    V lower,
    V upper, {
    bool isLowerInclusive = true,
    bool isUpperInclusive = false,
  }) {
    return IsBetweenQuery(
      this,
      lower,
      upper,
      isLowerInclusive,
      isUpperInclusive,
    );
  }
}

extension IndexedStringValueActions<Root> on IndexedValue<Root, String> {
  Query<Root> startsWith(String prefix) =>
      (this >= prefix) & (this < (prefix /* plus 1 */));
}
