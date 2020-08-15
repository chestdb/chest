# Fibonacci radix tree

A useful invariant of keys and index values is that they can be compared byte-by-byte.
So, for Chest, I invented a new datastructure, the Fibonacci radix tree.

In radix trees, only parts of the keys are stored in each node.
Consider the following radix tree which saves the keys `fruit bowl`, `fruit salad`, `fruit shake`, and `banana`:

```
        .
       / \
   fruit banana
   / | \
bowl | salad
   shake
```

As you see, `fruit` is only saved once in the tree.
Very long keys or keys with long common prefixes are saved in a memory-efficient way that even allows for splitting them across multiple nodes.

Here's how the above tree looks like in a way showing the nodes used in implementations:

```
┏━━━━━━━━━┳━━━━━━━━┓
┃  fruit  ┃ banana ┃
┠─────────╂────────┨
┃ pointer ┃ value  ┃
┗━━━━━━━━━┻━━━━━━━━┛
     ↓
┏━━━━━━━┳━━━━━━━┳━━━━━━━┓
┃ bowl  ┃ salad ┃ shake ┃
┠───────╂───────╂───────┨
┃ value ┃ value ┃ value ┃
┗━━━━━━━┻━━━━━━━┻━━━━━━━┛
```

A challenge when implementing them in a storage-based environment is that the nodes all have the same size. So, it's often more more memory-efficient to allow some duplication.

Imagine the keys `ab` and `ac` are stored.

```
┏━━━━━━━━━┓
┃    a    ┃
┠─────────┨
┃ pointer ┃
┗━━━━━━━━━┛
     ↓
┏━━━━━━━┳━━━━━━━┓
┃   b   ┃   c   ┃
┠───────╂───────┨
┃ value ┃ value ┃
┗━━━━━━━┻━━━━━━━┛
```

This is how that would look with duplication allowed:

```
┏━━━━━━━┳━━━━━━━┓
┃  ab   ┃  ac   ┃
┠───────╂───────┨
┃ value ┃ value ┃
┗━━━━━━━┻━━━━━━━┛
```

We only need one chunk instead of two.
