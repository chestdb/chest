# Chunk-based Radix Tree

A useful invariant of keys and index values is that they can be compared byte-by-byte.
So, for Chest, I adapted radix tree to work well in a chunk-based environment.

## Radix trees

In radix trees, only parts of the keys are stored in each node.
Consider the following radix tree which saves the keys `fruit bowl`, `fruit`, `fruit shake`, and `banana`:

```
        -
       / \
   fruit banana
   / | \
bowl - shake
```

As you see, the string `fruit` is only saved once in the tree.
Very long keys or keys with long common prefixes are saved in a memory-efficient way that even allows for splitting them across multiple nodes.

The following diagram shows how the same tree but in a way showing the nodes used in implementations. You also see where the values for each key are saved. Dots mark the end of a key.

```
p = pointer, v = value

+-------+---------+
| fruit | banana. |
| p     | v       |
+-------+---------+
  ↓
+-------+---+--------+
| bowl. | . | shake. |
| v     | v | v      |
+-------+---+--------+
```

## Node restrictions

A challenge when implementing a radix tree in a storage-based environment is that the nodes all have the same size (in Chest, each node is a chunk). So, the less nodes you use, the more memory-efficient the tree is.

### Node sizes

From now on, the width of nodes in diagrams corresponds to the amount of memory they need.
A node with a maximum key part length of n is called n-node.

For example, here's an 8-node with a capacity for 3 keys:

```
+----------+----------+----------+
| hello.   | blubbel. |          |
| v        | v        |          |
+----------+----------+----------+
```

### Can duplication be good?

Imagine the keys `ab` and `ac` are stored in a tree of 5-nodes (the maximum key part length is 5).

If all keys share common prefixes, nodes are mostly empty:

```
+-------+-------+-------+
| a     |       |       |
| p     |       |       |
+-------+-------+-------+
  ↓
+-------+-------+-------+
| b.    | c.    |       |
| v     | v     |       |
+-------+-------+-------+
```

This is how that would look with duplication allowed:

```
+-------+-------+-------+
| ab.   | ac.   |       |
| v     | v     |       |
+-------+-------+-------+
```

The prefix `a` is saved twice, but we only need one node instead of two!
So, duplication does allow for more memory-efficient trees in a chunk-based environment.

### Node size limits

Exponential radix trees split and join nodes to achieve maximum efficiency. To do that, we first have to define choose a minimum and maximum node size (size now referring to the size of the key part).

In the example above, 5-nodes were used. Given a chunk size, we're now looking for useful kinds of minimum and maximum values of n-nodes.

#### Smallest node

The smallest node should be chosen in a way that it can store all variants of keys simultaneously.
That means, if the smallest node is a 1-node, then it needs to have at least 256 slots to be able to store all 256 byte combinations simultaneously.

If the chunk size is really large, maybe it's even possible for a 2-node to be the smallest – it just has to fit 65536 2-byte combinations inside.

If the chunk size is really small, there are a couple of things you can do:

- Split the node even further – like, make it contain 5 *bits* per key. But good luck implementing that. 😉
- Simply increase the node size / chunk size.
- Represent one leaf node with multiple chunks in a linked-list-style.

Also, because the smallest node is complete (it has space for all keys), it can be implemented more efficiently than other nodes. The keys don't actually have to be saved.  
For example, a 1-node could just be an array with 256 entries. Searching for a key part is as easy as accessing the corresponding array entry.

#### Largest node

Trees that degenerated into a linked list occur if there are few very long keys. This is likely to happen, so the maximum node size should ideally be chosen in a way so that saving just one key uses all the available space.

For example, here's how a tree of 10-nodes containing only `banana smoothie with a little umbrella` would look like:

```
+------------+
| banana smo |
| p          |
+------------+
  ↓
+------------+
| othie with |
| p          |
+------------+
  ↓
+------------+
|  a little  |
| p          |
+------------+
  ↓
+------------+
| umbrella.  |
| p          |
+------------+
```

## Definition of a Chunk-based radix tree

Once minimum and maximum node sizes have been defined like described above, node sizes in between are chosen, so that each can be split into two smaller sizes.

For example, given a minimum node size of 1 and a maximum node size of 30, here's a list of possible (roughly exponential) node sizes:

- 1: the smallest
- 2: split into 1 and 1
- 4: split into 2 and 2
- 6: split into 2 and 4
- 8: split into 4 and 4
- 16: split into 8 and 8
- 22: split into 6 and 16
- 30: split into 8 and 22

> Any roughly exponential sequence could have been used here. For example, the Fibonacci sequence is also exponential, so it would also be a great fit.

The nodes don't necessarily all contain the same number of keys. Specifically, nodes with smaller key parts can contain more keys than nodes with larger key parts:

```
 1 | a | a | a | a | a | a | a | a || hard
 2 | aa | aa | aa | aa | aa | aa |  | memory
 4 | aaaa | aaaa | aaaa | aaaa |    | limit
 6 | aaaaaa | aaaaaa | aaaaaa |     |
 8 | aaaaaaaa | aaaaaaaa | aaaaaaaa |
16 | aaaaaaaaaaaaaaaa |             |
22 | aaaaaaaaaaaaaaaaaaaaaa |       |
30 | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
```

(You may notice that the 1-node only contains 8 key slots – not nearly enough to fit all possible 256 byte values. In pratice, you'd have much larger nodes that do support this.)

In exponential radix trees, nodes also save a preference for their child size.

### Adding keys

To add keys to a tree, you do the following, starting at the root node:

- Does the node exist?
  - No: Create a new one, choosing the parent's child size preference, or the largest node if there this will be the root.
  - Yes: Does it contain the beginning of the key clipped to the node size?
    - Yes: Follow that path and insert the rest of the key in the node below (start over in this list).
    - No: Does it have an empty slot?
      - Yes: Fill that slot with the beginning of the key and insert the key into the non-existing node below (start over and create a node).
      - No: Split the node. Then, insert it again (start over).

### Deleting keys

Each nodes also contains a counter for how many times it has been split. Newly added nodes have the counter set to 0. Nodes that got split also have their counter increased by one.

To delete keys from a tree, you follow it all the way to the last leaf and then do the following for each node encountered in backtracking order:

- Remove the key part.
- Is the node empty? If so, remove it.
- If a child node got removed, check if all child nodes have a split counter of 0 and if the number of entries in the children would all fit into the current node's un-split layout.
- If so, condense the node with the layer below.
- Then, decrease the split counter by one.

### Example

Let's have a look at how a Fibonacci Radix Tree with the node sizes from above evolves when the following keys are added:

- `banana`
- `kiwi`
- `banana shake`
- `banana smoothie with a little umbrella`

#### Adding `banana`

There's no node yet, so we create a new one – choosing the largest option available: a 30-node.

```
+--------------------------------+
| banana.                        |
| v                              | split 0
+--------------------------------+ child -
```

You can also see that each node saves how many times it has been split and what's the preferred size of the children.

#### Adding `kiwi`

There is a node and it doesn't contain `kiwi` (clipping to 30 characters doesn't do anything). Because there's no empty slot, we split the node (30-node → 8-node with 22-nodes as children if necessary).

```
+----------+----------+----------+
| banana.  | kiwi.    |          |
| v        | v        |          | split 1
+----------+----------+----------+ child 22
```

Because nothing overflows, no children need to be created.
Child size preferences are noted with an arrow on the right.

#### Adding `banana shake`

There's a node and it doesn't contain `banana shake` clipped to 8 characters (`banana s`). So, we first have to add `banana s` to it.
For the rest of the key, a child is added (with a child size of 22, because that's the preferred child size of the root node):

```
+----------+----------+----------+
| banana.  | kiwi.    | banana s |
| v        | v        | p        | split 1
+----------+----------+----------+ child 22
                        ↓
+------------------------+
| hake.                  |
| v                      | split 0
+------------------------+ child -
```

#### Adding `banana smoothie with a little umbrealla`

The root node, which is an 8-node, already contains the first 8 bytes of the key (`banana s`), so we just follow that pointer.
The next 22 bytes should be put into the second node, but it doesn't have an empty slot anymore. So, we have to split it into a 6-node and a 16-node and insert the key parts there.
The key has yet more bytes, so we add another node at the bottom with the default node size of 30-node, because the lower node doesn't have a child size preference:

```
+----------+----------+----------+
| banana.  | kiwi.    | banana s |
| v        | v        | p        | split 1
+----------+----------+----------+ child 22
                        ↓
+--------+--------+--------+
| hake.  | moothi |        |
| v      | p      |        | split 1
+--------+--------+--------+ child 16
           ↓
+------------------+
| e with a little  |
| p                | split 0
+------------------+ child -
  ↓
+--------------------------------+
| umbrella.                      |
| v                              | split 0
+--------------------------------+ child -
```

By now, you've probably noticed that the layout is not always space-optimal. For example, in the example above, two new chunks have been created instead of one – `umbrella.` would have easily fit into the previous chunk.  
The design decision behind this is that keys are layouted more consistently: You could split every key first into chunks of 30 bytes and each of those bytes is inside it's own little radix tree. This also makes merging very easy: Suppose, `banana shake.` got deleted. In that case, the node and its child could be merged into a 22-node again that contains `moothie with a little ` – which would not be possible if `umbrella.` was also inside the node.
