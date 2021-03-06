part of file.src.backends.memory;

/// Returns a deep copy of [map], verifying it is JSON serializable.
Map<String, Object> _cloneSafe(Map<String, Object> map) {
  var json = JSON.encode(map);
  return JSON.decode(json) as Map<String, Object>;
}

/// An implementation of [FileSystem] that exists entirely in memory.
///
/// [MemoryFileSystem] is suitable for mocking and tests, as well as for
/// caching or staging before writing or reading to a live system.
///
/// **NOTE**: This class is not yet optimized and should not be used for
/// performance-sensitive operations. There is also no implementation today for
/// symbolic [Link]s.
class MemoryFileSystem implements FileSystem {
  final Map<String, Object> _data;

  /// Create a new, empty in-memory file system.
  factory MemoryFileSystem() {
    return new MemoryFileSystem._(<String, Object>{});
  }

  // Prevent extending this class.
  MemoryFileSystem._(this._data);

  @override
  Directory directory(String path) {
    return new _MemoryDirectory(this, path == '/' ? '' : path);
  }

  @override
  File file(String path) => new _MemoryFile(this, path);

  // Resolves a list of path parts to the final directory in the hash map.
  //
  // This will be the most expensive part of the implementation as the
  // directory structure grows n levels deep it will require n checks.
  //
  // This could be sped up by using a SplayTree intead for O(logn) lookups
  // if we are expecting very deep directory structures.
  //
  // May pass [recursive] as `true` to create missing directories instead of
  // failing by returning null.
  Map<String, Object> _resolvePath(Iterable<String> paths, {bool recursive: false}) {
    var root = _data;
    for (var path in paths) {
      if (path == '') continue;
      // Could use putIfAbsent to potentially optimize, but creating a long
      // directory structure recursively is unlikely to happen in a tight loop.
      var next = root[path];
      if (next == null) {
        if (recursive) {
          root[path] = next = <String, Object>{};
        } else {
          return null;
        }
      }
      root = next as Map<String, Object>;
    }
    return root;
  }

  /// Returns a Map equivalent to the file structure of the file system.
  ///
  // See [InMemoryFileSystem.fromMap] for details on the structure.
  Map<String, Object> toMap() => _cloneSafe(_data);

  @override
  Future<FileSystemEntityType> type(String path, {bool followLinks: true}) {
    if (!followLinks) {
      throw new UnimplementedError('No support for symbolic links in system');
    }
    FileSystemEntityType result;
    if (path == '/') {
      result = FileSystemEntityType.DIRECTORY;
    } else if (!path.startsWith('/')) {
      throw new ArgumentError('Path must begin with "/"');
    } else {
      var paths = path.substring(1).split('/');
      var directory = _resolvePath(paths.take(paths.length - 1));
      var entity;
      if (directory != null) {
        entity = directory[paths.last];
      }
      if (entity == null) {
        result = FileSystemEntityType.NOT_FOUND;
      } else if (entity is String || entity is List) {
        result = FileSystemEntityType.FILE;
      } else if (entity is Map) {
        result = FileSystemEntityType.DIRECTORY;
      } else {
        throw new UnsupportedError('Unknown type: ${entity.runtimeType}');
      }
    }
    return new Future<FileSystemEntityType>.value(result);
  }
}
