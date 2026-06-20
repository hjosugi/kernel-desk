@external(javascript, "./node_ffi.mjs", "env")
pub fn env(name: String, fallback: String) -> String

@external(javascript, "./node_ffi.mjs", "envInt")
pub fn env_int(name: String, fallback: Int) -> Int

@external(javascript, "./node_ffi.mjs", "queryParam")
pub fn query_param(query: String, key: String) -> String

@external(javascript, "./node_ffi.mjs", "gitSnapshot")
pub fn git_snapshot(repo_root: String) -> String

@external(javascript, "./node_ffi.mjs", "readSource")
pub fn read_source(repo_root: String, relative_path: String) -> String

@external(javascript, "./node_ffi.mjs", "loadProgress")
pub fn load_progress(data_file: String) -> String

@external(javascript, "./node_ffi.mjs", "saveProgress")
pub fn save_progress(
  data_file: String,
  path: String,
  status: String,
  note: String,
) -> String

@external(javascript, "./node_ffi.mjs", "startServer")
pub fn start_server(
  port: Int,
  static_root: String,
  handler: fn(String, String, String, String) -> String,
) -> Nil
