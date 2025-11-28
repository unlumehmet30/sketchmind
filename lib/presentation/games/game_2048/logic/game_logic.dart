import 'dart:math';

class GameLogic {
  final int gridSize;
  List<List<int>> _grid;
  int _score = 0;
  bool _isGameOver = false;

  GameLogic({this.gridSize = 4}) : _grid = [] {
    resetGame();
  }

  List<List<int>> get grid => _grid;
  int get score => _score;
  bool get isGameOver => _isGameOver;

  void resetGame() {
    _grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    _score = 0;
    _isGameOver = false;
    _spawnTile();
    _spawnTile();
  }

  void _spawnTile() {
    List<Point<int>> emptyCells = [];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_grid[r][c] == 0) {
          emptyCells.add(Point(r, c));
        }
      }
    }

    if (emptyCells.isNotEmpty) {
      final random = Random();
      final point = emptyCells[random.nextInt(emptyCells.length)];
      _grid[point.x][point.y] = random.nextDouble() < 0.9 ? 2 : 4;
    }
  }

  bool moveLeft() {
    bool moved = false;
    for (int r = 0; r < gridSize; r++) {
      List<int> newRow = _mergeRow(_grid[r]);
      if (!_listsEqual(_grid[r], newRow)) {
        _grid[r] = newRow;
        moved = true;
      }
    }
    if (moved) _afterMove();
    return moved;
  }

  bool moveRight() {
    bool moved = false;
    for (int r = 0; r < gridSize; r++) {
      List<int> reversedRow = List.from(_grid[r].reversed);
      List<int> newRow = _mergeRow(reversedRow);
      newRow = List.from(newRow.reversed);
      if (!_listsEqual(_grid[r], newRow)) {
        _grid[r] = newRow;
        moved = true;
      }
    }
    if (moved) _afterMove();
    return moved;
  }

  bool moveUp() {
    bool moved = false;
    for (int c = 0; c < gridSize; c++) {
      List<int> col = [];
      for (int r = 0; r < gridSize; r++) col.add(_grid[r][c]);
      
      List<int> newCol = _mergeRow(col);
      
      for (int r = 0; r < gridSize; r++) {
        if (_grid[r][c] != newCol[r]) {
          _grid[r][c] = newCol[r];
          moved = true;
        }
      }
    }
    if (moved) _afterMove();
    return moved;
  }

  bool moveDown() {
    bool moved = false;
    for (int c = 0; c < gridSize; c++) {
      List<int> col = [];
      for (int r = 0; r < gridSize; r++) col.add(_grid[r][c]);
      
      List<int> reversedCol = List.from(col.reversed);
      List<int> newCol = _mergeRow(reversedCol);
      newCol = List.from(newCol.reversed);

      for (int r = 0; r < gridSize; r++) {
        if (_grid[r][c] != newCol[r]) {
          _grid[r][c] = newCol[r];
          moved = true;
        }
      }
    }
    if (moved) _afterMove();
    return moved;
  }

  List<int> _mergeRow(List<int> row) {
    List<int> nonZero = row.where((val) => val != 0).toList();
    List<int> newRow = [];
    
    int i = 0;
    while (i < nonZero.length) {
      if (i + 1 < nonZero.length && nonZero[i] == nonZero[i + 1]) {
        int mergedVal = nonZero[i] * 2;
        newRow.add(mergedVal);
        _score += mergedVal;
        i += 2;
      } else {
        newRow.add(nonZero[i]);
        i++;
      }
    }
    
    while (newRow.length < gridSize) {
      newRow.add(0);
    }
    return newRow;
  }

  void _afterMove() {
    _spawnTile();
    _checkGameOver();
  }

  void _checkGameOver() {
    // Check for empty cells
    for (var row in _grid) {
      if (row.contains(0)) return;
    }

    // Check for possible merges
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        int val = _grid[r][c];
        if (c + 1 < gridSize && _grid[r][c + 1] == val) return;
        if (r + 1 < gridSize && _grid[r + 1][c] == val) return;
      }
    }

    _isGameOver = true;
  }

  bool _listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
