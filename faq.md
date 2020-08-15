# FAQ

<details>
<summary>Why did I write Chest?</summary>

When I started Chest, there was no database that

- was written in pure Dart,
- was lazy (not in-memory), and
- was easy to use.

So I decided to change that.

Also, I wanted to do a little research in database architecture.
</details>


<details>
<summary>What makes Chest different from other databases?</summary>

When I started Chest, pub.dev already contained some database packages.

- In-memory databases existed, most of which are written in pure Dart (like Sembast, Hive, or ObjectDB).
- Lazy on-disk databases existed, but all of them were wrappers for a native database (like Sqlite, Moor, or Postgres).

So I decided to write a lazy on-disk database in pure Dart.
</details>


<details>
<summary>Isn't Dart a painfully slow language for a database?</summary>

While Dart is slower than other lower-level languages like Rust or C++, it's fast enough for most applications.

Here are some reasons why the difference doesn't really matter much:

- All of the operations work in logarithmic time, so they are fast anyway.
- Database performance is mostly I/O-bound. Loading parts of files into memory is just as fast as in low-level languages.
- Results are cached in-memory.
</details>
