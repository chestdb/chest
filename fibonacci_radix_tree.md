# Fibonacci Radix Tree

A useful invariant of keys and index values is that they can be compared byte-by-byte.
So, for Chest, I invented a new datastructure, the Fibonacci radix tree.

## Radix trees

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

## Can duplication be good?

A challenge when implementing a radix tree in a storage-based environment is that the nodes all have the same size (in Chest, each node is a chunk). So, the less nodes you use, the more memory-efficient the tree is.
That's why it might make sense to allow some duplication.

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

## Fibonacci radix tree

So, how can we implement something like that on scale?
That's where the Fibonacci radix tree comes into play.
Each node has a maximum key part length that is a Fibonacci number. A node with a maximum key part length of n is called n-node.

Here's a diagram for a specific node size memory limit showing that nodes with smaller key parts can contain more children than nodes with larger key parts:

```
 1 | a | a | a | a | a | a | a | a | a | a | a | a | hard
 2 | aa | aa | aa | aa | aa | aa | aa | aa | aa |  | memory
 3 | aaa | aaa | aaa | aaa | aaa | aaa | aaa | aaa | limit
 5 | aaaaa | aaaaa | aaaaa | aaaaa | aaaaa | aaaaa |
 8 | aaaaaaaa | aaaaaaaa | aaaaaaaa | aaaaaaaa |   |
13 | aaaaaaaaaaaaa | aaaaaaaaaaaaa | aaaaaaaaaaaaa |
21 | aaaaaaaaaaaaaaaaaaaaa | aaaaaaaaaaaaaaaaaaaaa |
34 | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |          |
```

If a node overflows, it's split into a hierarchy of the two smaller node types.

Consider a 5-node (containing 5-byte parts of keys) that needs to be split. The following two options are possible:

- Split it into a 3-node and a layer of 2-nodes.
- Split it into a 2-node and a layer of 3-nodes.

For both these options, the filling factor is computed (what percentage of the available slots is used) and the option with the larger filling factor is chosen.

## Example

Let's have a look at how a Fibonacci Radix Tree with the node types from above evolves when the following keys are added:

- `banana`
- `banana shake`
- `kiwi`
- `fruit bowl`
- `fruits`
- `banana smoothie with a little umbrella`

From here on, the width of nodes in diagrams is proportional to the amount of space they're using.

### Adding `banana`

By default, the node with the largest key parts (in this case, a 43-node) is used:

```
+------------------------------------+
| banana                             |
| v                                  |
+------------------------------------+
```

### Adding `banana shake`

There's no empty slot, so the node needs to be split. The two options are:

- Split the node into a 21-node with 13-nodes as children if necessary.
- Split the node into a 13-node with 21-nodes as children if necessary.

In both cases, the key parts fit into the limit, so no children are necessary either way:

```
+-----------------------+-----------------------+
| banana                | banana shake          |
| v                     | v                     |
+-----------------------+-----------------------+

or

+---------------+---------------+---------------+
| banana        | banana shake  |               |
| v             | v             |               |
+---------------+---------------+---------------+
```

The options use 2/2, or 2/3 slots, respectively. So, the filling factors are 2/2=1.0 and 2/3=0.67.
The first option's filling factor is greater, so it is chosen:

```
+-----------------------+-----------------------+
| banana                | banana shake          |
| v                     | v                     |
+-----------------------+-----------------------+
```

### Adding `kiwi`

Now, the 21-node needs to be split. These are the two options:

```
+---------------+---------------+---------------+
| banana        | banana shake  | kiwi          |
| v             | v             | v             |
+---------------+---------------+---------------+

or

+----------+----------+----------+----------+
| banana   | banana s | kiwi     |          |
| v        | p        | v        |          |
+----------+----------+----------+----------+
             ↓
+---------------+---------------+---------------+
| hake          |               |               |
| v             |               |               |
+---------------+---------------+---------------+
```

Note that in the second option, because `banana shake` doesn't fit into the first node, a child needs to be created containing the rest.

The first option uses 3/3 slots, the lower one 4/7. So, the first option is chosen:

```
+---------------+---------------+---------------+
| banana        | banana shake  | kiwi          |
| v             | v             | v             |
+---------------+---------------+---------------+
```

### Adding `fruit bowl`

Next, `fruit bowl` is added. Because the current node is already full, it has to be split again.
It's currently a 13-node, so 8-node and 5-node are the two options for the root node type:

```
+----------+----------+----------+----------+
| banana   | banana s | kiwi     | fruit bo |
| v        | p        | v        | p        |
+----------+----------+----------+----------+
             |                     +---------------+
             ↓                                     |
+-------+-------+-------+-------+-------+-------+  |
| hake  |       |       |       |       |       |  |
| v     |       |       |       |       |       |  |
+-------+-------+-------+-------+-------+-------+  |
                                                   |
+-------+-------+-------+-------+-------+-------+  |
| wl    |       |       |       |       |       |←-+
| v     |       |       |       |       |       |
+-------+-------+-------+-------+-------+-------+

or

+-------+-------+-------+-------+-------+-------+
| banan | kiwi  | fruit |       |       |       |
| p     | v     | p     |       |       |       |
+-------+-------+-------+-------+-------+-------+
  |               +----------------------------+
  ↓                                            |
+----------+----------+----------+----------+  |
| a        | a shake  |          |          |  |
| v        | v        |          |          |  |
+----------+----------+----------+----------+  |
                                               |
+----------+----------+----------+----------+  |
|  bowl    |          |          |          |←-+
| v        |          |          |          |
+----------+----------+----------+----------+
```

The filling factors are 6/16=0.38 and 6/14=0.43, so the second option is chosen:

```
+-------+-------+-------+-------+-------+-------+
| banan | kiwi  | fruit |       |       |       |
| p     | v     | p     |       |       |       |
+-------+-------+-------+-------+-------+-------+
  |               +----------------------------+
  ↓                                            |
+----------+----------+----------+----------+  |
| a        | a shake  |          |          |  |
| v        | v        |          |          |  |
+----------+----------+----------+----------+  |
                                               |
+----------+----------+----------+----------+  |
|  bowl    |          |          |          |←-+
| v        |          |          |          |
+----------+----------+----------+----------+
```

### Adding `fruits`

The root node is a 5-node and the first 5 bytes of `fruits` (`fruit`) already exist as a key. So, we follow the pointer and insert the key into the next chunk:

```
+-------+-------+-------+-------+-------+-------+
| banan | kiwi  | fruit |       |       |       |
| p     | v     | p     |       |       |       |
+-------+-------+-------+-------+-------+-------+
  |               +----------------------------+
  ↓                                            |
+----------+----------+----------+----------+  |
| a        | a shake  |          |          |  |
| v        | v        |          |          |  |
+----------+----------+----------+----------+  |
                                               |
+----------+----------+----------+----------+  |
|  bowl    | s        |          |          |←-+
| v        | v        |          |          |
+----------+----------+----------+----------+
```

### Adding `banana smoothie with a little umbrella`

`banana smoothie with a little umbrella` starts with `banan`, so we follow the pointer to the second node, which is an 8-node.
It doesn't contain the next 8 bytes, `a smooth`, so we add those as a key. Our key is still longer, so we add a new node for the rest, defaulting to the 43-node (just like in the beginning):

```
+-------+-------+-------+-------+-------+-------+
| banan | kiwi  | fruit |       |       |       |
| p     | v     | p     |       |       |       |
+-------+-------+-------+-------+-------+-------+
  |               +----------------------------+
  ↓                                            |
+----------+----------+----------+----------+  |
| a        | a shake  | a smooth |          |  |
| v        | v        | p        |          |  |
+----------+----------+----------+----------+  |
                        ↓                      |
+------------------------------------+         |
| ie with a little umbrella          |         |
| v                                  |         |
+------------------------------------+         |
                                               |
+----------+----------+----------+----------+  |
|  bowl    | s        |          |          |←-+
| v        | v        |          |          |
+----------+----------+----------+----------+
```

## Deletion

TODO: Think about this.

## Edge cases

### Lower bound

The smallest node can't be split anymore, so all possible combinations have to fit inside it. That means, if the smallest node saves 1 byte per key, then it needs to have at least 256 slots.

There are a couple of options for circumventing that:

- Split the node even further – like, make it contain 5 *bits* per key. But good luck implementing that. 😉
- Simply increase the node size / chunk size.
- Represent one leaf node with multiple chunks in a linked-list-style.

### Upper bound

The biggest node doesn't necessarily fill the whole chunk, only the space equal to the largest Fibonacci number lower than the limit. That's a waste of space if there are few long keys that cause the tree to degenerate into a linked list.

So, it may make sense to have a special upper bound chunk that fills the chunk and can be split into two of the biggest Fibonacci-sized chunks.
