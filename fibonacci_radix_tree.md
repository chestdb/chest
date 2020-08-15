# Fibonacci radix tree

A useful invariant of keys and index values is that they can be compared byte-by-byte.
So, for Chest, I invented a new datastructure, the Fibonacci radix tree.

In radix trees, only parts of the keys are stored in each node.
Consider the following radix tree which saves the keys `fruit bowl`, `fruit`, `fruit shake`, and `banana`:

```
        .
       / \
   fruit banana
   / | \
bowl . shake
```

As you see, `fruit` is only saved once in the tree.
Very long keys or keys with long common prefixes are saved in a memory-efficient way that even allows for splitting them across multiple nodes.

The following diagram shows how the above tree looks like in a way showing the nodes used in implementations. You also see where the values for each key are saved.

```
p = pointer, v = value

+-------+--------+
| fruit | banana |
| p     | v      |
+-------+--------+
  ↓
+------+---+-------+
| bowl | . | shake |
| v    | v | v     |
+------+---+-------+
```

A challenge when implementing a radix tree in a storage-based environment is that the nodes all have the same size (in Chest, each node is a chunk). So, it's often more more memory-efficient to allow some duplication.

Imagine the keys `ab` and `ac` are stored:

```
+---+
| a |
| p |
+---+
  ↓
+---+---+
| b | c |
| v | v |
+---+---+
```

This is how that would look with duplication allowed:

```
+----+----+
| ab | ac |
| v  | v  |
+----+----+
```

We only need one chunk instead of two!

So, how can implement something like that on scale?
That's where the Fibonacci radix tree comes into play. The key parts stored in each node have a (maximum) length of a Fibonacci number that is defined for that node.

Given a memory limit, possible nodes setups are defined where the key parts have a Fibonacii length:

```
 1 | a | a | a | a | a | a | a | a | a | a | a | a | hard
 2 | aa | aa | aa | aa | aa | aa | aa | aa | aa |  | memory
 3 | aaa | aaa | aaa | aaa | aaa | aaa | aaa | aaa | limit
 5 | aaaaa | aaaaa | aaaaa | aaaaa | aaaaa | aaaaa |
 8 | aaaaaaaa | aaaaaaaa | aaaaaaaa | aaaaaaaa |   |
13 | aaaaaaaaaaaaa | aaaaaaaaaaaaa | aaaaaaaaaaaaa |
21 | aaaaaaaaaaaaaaaaaaaaa | aaaaaaaaaaaaaaaaaaaaa |
```

Suppose the following keys are added:

- `banana`
- `banana shake`
- `kiwi`
- `fruit bowl`
- `shake made out of banana`
- `fruit bowl with kiwis and some other stuff`

By default, the largest setup is used. Adding `banana`:

```
   +-----------------------+-----------------------+
21 | banana                | -                     |
   | v                     |                       |
   +-----------------------+-----------------------+
```

If there's still space, new keys are just added. Adding `banana shake`:
```
   +-----------------------+-----------------------+
21 | banana                | banana shake          |
   | v                     | v                     |
   +-----------------------+-----------------------+
```

Adding `kiwi` doesn't work because there's no space anymore. So, the 21-node is split into a 8- and a 13-node.

There are two options: Making the upper or the lower node the larger one. Both of them are considered:
```
   +---------------+---------------+---------------+
13 | banana        | banana shake  | kiwi          |
   | v             | v             | v             |
   +---------------+---------------+---------------+
 8 not needed

or

   +----------+----------+----------+----------+
 8 | banana   | banana s | kiwi     |          |
   | v        | p        | v        |          |
   +----------+----------+----------+----------+
                ↓
   +---------------+---------------+---------------+
13 | hake          |               |               |
   | v             |               |               |
   +---------------+---------------+---------------+
```

Not requiring a second node is of course better, so the first option is chosen.

Next, `fruit bowl` is added. Because the node is already full it's again split into two. The current size is 13, so it's split into a 8-node and a 5-node. Again, both orderings are considered:

```
   +----------+----------+----------+----------+
 8 | banana   | banana s | kiwi     | fruit bo |
   | v        | p        | v        |          |
   +----------+----------+----------+----------+


```

