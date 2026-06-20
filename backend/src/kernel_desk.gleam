import kernel_desk/node
import kernel_desk/router

pub fn main() {
  let repo_root = node.env("KERNEL_REPO_PATH", "../sample/linux-mini")
  let data_file = node.env("KERNEL_DESK_DATA", "./data/progress.json")
  let static_root = node.env("KERNEL_DESK_STATIC", "./priv/static")
  let port = node.env_int("PORT", 4000)

  node.start_server(port, static_root, fn(method, path, query, body) {
    router.handle(method, path, query, body, repo_root, data_file)
  })
}
