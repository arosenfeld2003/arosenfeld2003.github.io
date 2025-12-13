---
title: "Learning Graph Algorithms: A Deep Dive into BFS, DFS, and Graph Representations"
date: 2025-12-06T09:00:00-08:00

draft: false

tags: ["algorithms", "graphs", "python", "computer-science", "learning"]
category: "technical"
summary: "An interactive learning session exploring graph data structures, adjacency matrices and lists, and the fundamental differences between breadth-first and depth-first search algorithms."
---

Today was a good refresher on graphs. I hadn't devoted significant time to graph algorithm problems for a while and our Qwasar engineering collab was a really good excuse. I got a lot out of pairing up on these exercises, and also using Claude to generate visuals in the terminal. One of the most challenging things for me about graph representations in code is constructing an accurate visualization. It has never been intuitive for me to mentally map a graph into common coding syntax (lists, etc). Also, the terminology can feel overwhelming at times: weighted vs unweighted, directed vs undirected, adjacency matrix, neighbors, edges… This language was intentionally included in the problem sets, which is one reason I really appreciate the Qwasar team and their thoughtful curriculum. This session was a very useful refresher and it reminded me that going slow and being methodical and asking a lot of questions is still extremely important. My number one objective now when sitting at a computer and writing code is to learn something concrete and expand my skillset. I think building mental models (being able to actually sketch out architectures and pseudocode completely independently of a language) will be an extremely important skill in the age of AI and agentic code, and will help developers to maintain an understanding of systems and effectively guide AI to building quickly and iteratively with confidence in safety/security and overall efficient design patterns.

## Technical Details

This session focused on implementing and understanding fundamental graph algorithms and data structures in Python. The work centered around a comprehensive implementation file (`12_06_25.py`) that covers multiple graph concepts with extensive test cases and visualizations.

### Graph Representation

The implementation includes two primary ways to represent graphs:

**1. Adjacency Matrix**
A 2D array where `matrix[i][j] = 1` indicates an edge between nodes i and j:

```python
def build_matrix(n, edges):
    matrix = [[0 for _ in range(n)] for _ in range(n)]
    for u, v in edges:
        # Validate that both u and v are within valid range [0, n)
        if u < 0 or u >= n or v < 0 or v >= n:
            raise ValueError(
                f"Invalid edge ({u}, {v}): node indices must be in range [0, {n-1}] "
                f"for a graph with {n} nodes"
            )
        matrix[u][v] = 1
        matrix[v][u] = 1  # Undirected graph
    return matrix
```

This implementation includes defensive error handling with helpful messages when edge indices are out of bounds.

**2. Adjacency List**
A list of lists where `adj_list[i]` contains all neighbors of node i:

```python
def matrix_to_list(matrix):
    """Convert adjacency matrix to adjacency list"""
    return [neighbors(matrix, u) for u in range(len(matrix))]

def list_to_matrix(adj_list):
    """Convert adjacency list to adjacency matrix"""
    n = len(adj_list)
    edges = []
    for u in range(n):
        for v in adj_list[u]:
            edges.append((u, v))
    return build_matrix(n, edges)
```

The conversion functions demonstrate code reuse - `list_to_matrix` leverages the existing `build_matrix` function rather than duplicating logic.

### Graph Query Operations

Three core operations for working with adjacency matrices:

```python
def has_edge(matrix, u, v):
    return matrix[u][v] == 1

def neighbors(matrix, u):
    """Return list of nodes adjacent to u"""
    return [j for j in range(len(matrix[u])) if matrix[u][j] == 1]

def degree(matrix, u):
    """Return the number of neighbors of node u"""
    return len(neighbors(matrix, u))
```

The `neighbors` function uses a clean list comprehension, and `degree` follows the DRY principle by reusing `neighbors` rather than reimplementing the logic.

### Breadth-First Search (BFS)

BFS explores graphs level-by-level using a queue (FIFO):

```python
def bfs(adj_list, start):
    visited = set()
    queue = [start]
    result = []

    while queue:
        node = queue.pop(0)  # FIFO - removes first element

        if node in visited:
            continue

        visited.add(node)
        result.append(node)

        for neighbor in sorted(adj_list[node]):
            if neighbor not in visited:
                queue.append(neighbor)

    return result
```

The key characteristic is `queue.pop(0)` which removes the first element, creating the breadth-first exploration pattern.

### Depth-First Search (DFS)

DFS explores as deep as possible before backtracking, using a stack (LIFO):

```python
def dfs(adj_list, start):
    visited = set()
    stack = [start]
    result = []

    while stack:
        node = stack.pop()  # LIFO - removes last element

        if node in visited:
            continue

        visited.add(node)
        result.append(node)

        # Reverse sort so smallest neighbor is popped first
        for neighbor in sorted(adj_list[node], reverse=True):
            if neighbor not in visited:
                stack.append(neighbor)

    return result
```

The critical difference from BFS is `stack.pop()` (no argument) which removes the last element. The `reverse=True` ensures that when popping from the end, neighbors are processed in ascending order.

### Comprehensive Testing

The implementation includes extensive test cases with visual graph representations:

```python
# Test output showing the difference:
# Graph:
#     0 ———— 1
#     |      |
#     2      3

BFS: [0, 1, 2, 3]  # Level-by-level: 0 -> [1,2] -> [3]
DFS: [0, 1, 3, 2]  # Depth-first: 0 -> 1 -> 3 -> backtrack to 2
```

Tests include:
- Basic functionality tests for all graph operations
- BFS and DFS comparison on the same graphs
- Disconnected graph handling
- Error case validation
- Step-by-step execution traces explaining the `reverse()` trick in DFS

The tree structure test particularly highlights the algorithmic difference:

```python
# Graph:
#         0
#        /|\
#       1 2 3
#       |
#       4

BFS: [0, 1, 2, 3, 4]  # Visits by level: [0] then [1,2,3] then [4]
DFS: [0, 1, 4, 2, 3]  # Goes deep: 0->1->4, then backtracks to 2, then 3
```

## Claude's Perspective

_Note: These observations are verbatim as generated and were not edited by a human._

This session was particularly effective as a learning exercise because it emphasized understanding over implementation. The code artifacts reveal a pedagogical approach focused on three key areas:

**1. Building Intuition Through Visualization**

The inclusion of ASCII art graph diagrams and step-by-step execution traces in both comments and test output shows a deliberate effort to make abstract algorithms concrete. The docstring explaining the DFS `reverse()` trick with visual stack representations is especially notable - it addresses a subtle but important implementation detail that often trips up learners.

**2. Code Reuse as a Teaching Tool**

The implementation demonstrates the DRY (Don't Repeat Yourself) principle in multiple places:
- `degree()` calls `neighbors()` rather than reimplementing the iteration
- `matrix_to_list()` leverages the existing `neighbors()` function
- `list_to_matrix()` converts to an edge list and reuses `build_matrix()`

This pattern suggests the learning objective wasn't just "implement these functions" but "understand how to compose simple operations into more complex ones."

**3. Defensive Programming**

The error handling in `build_matrix()` with detailed error messages (`f"Invalid edge ({u}, {v}): node indices must be in range [0, {n-1}]"`) indicates attention to edge cases and user experience, even in learning code. This is a good habit that's worth cultivating early.

**The BFS vs DFS Comparison**

What I find most interesting is how the tests explicitly run both algorithms on identical graphs to highlight their behavioral differences. The comment blocks explaining why `reverse=True` is necessary in DFS show someone working to truly understand the mechanism, not just cargo-culting a solution.

The critical insight - that `pop(0)` vs `pop()` is the fundamental difference between BFS and DFS - is well-illustrated. However, I notice the code uses `pop(0)` on a Python list, which is O(n). For a production implementation, this would suggest using `collections.deque` with `popleft()`, but for learning with small graphs, the clarity of using a simple list is likely worth the performance trade-off.

**What the Test Cases Reveal**

The progression of test cases (connected graph → disconnected graph → tree structure → chain) shows thoughtful design. Each test isolates a different aspect:
- Test 1: Basic correctness
- Test 2: Different starting points
- Test 3: Reachability in disconnected graphs
- Test 4: Algorithmic difference visualization

The chain graph test (where BFS and DFS produce the same result) is particularly clever - it establishes that the algorithms differ only when there are multiple paths to explore, helping isolate the key variable.

**Limitations**

What I cannot know from the code alone:
- Whether this is part of a formal course or self-study
- What prior knowledge existed about graph theory
- How long different concepts took to internalize
- Whether the visual learning approach was more effective than alternatives

The presence of multiple problem descriptions in docstrings (querying matrices, building matrices, converting representations, BFS) suggests these may be exercises from a structured curriculum, but the extensive test suite and explanatory comments go beyond what typical exercise solutions require.

---

_Built with Claude Code during a graph algorithms learning session_
