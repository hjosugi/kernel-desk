import gleam/dynamic/decode
import gleam/json
import gleam/string
import kernel_desk/learning_path
import kernel_desk/node

const json_content_type = "application/json; charset=utf-8"

pub type ProgressInput {
  ProgressInput(path: String, status: String, note: String)
}

pub fn handle(
  method: String,
  path: String,
  query: String,
  body: String,
  repo_root: String,
  data_file: String,
) -> String {
  case method, path {
    "OPTIONS", _ -> response(204, "text/plain; charset=utf-8", "")

    "GET", "/api/health" ->
      response(
        200,
        json_content_type,
        json.object([#("status", json.string("ok"))]) |> json.to_string,
      )

    "GET", "/api/repo" ->
      response(200, json_content_type, node.git_snapshot(repo_root))

    "GET", "/api/learning-path" ->
      response(200, json_content_type, learning_path.to_json())

    "GET", "/api/file" -> handle_file(query, repo_root)

    "GET", "/api/progress" ->
      response(200, json_content_type, node.load_progress(data_file))

    "POST", "/api/progress" -> handle_progress(body, data_file)

    _, _ -> error_response(404, "Route not found.")
  }
}

fn handle_file(query: String, repo_root: String) -> String {
  let requested_path = node.query_param(query, "path") |> string.trim

  case requested_path {
    "" -> error_response(400, "The path query parameter is required.")
    path -> response(200, json_content_type, node.read_source(repo_root, path))
  }
}

fn handle_progress(body: String, data_file: String) -> String {
  case json.parse(from: body, using: progress_input_decoder()) {
    Error(_) -> error_response(400, "Request body must be valid progress JSON.")

    Ok(input) -> {
      let path = string.trim(input.path)

      case path, valid_status(input.status) {
        "", _ -> error_response(422, "Progress path cannot be empty.")
        _, False -> error_response(422, "Unknown progress status.")
        _, True ->
          response(
            200,
            json_content_type,
            node.save_progress(data_file, path, input.status, input.note),
          )
      }
    }
  }
}

fn progress_input_decoder() {
  use path <- decode.field("path", decode.string)
  use status <- decode.field("status", decode.string)
  use note <- decode.field("note", decode.string)
  decode.success(ProgressInput(path:, status:, note:))
}

fn valid_status(status: String) -> Bool {
  case status {
    "not_started" -> True
    "reading" -> True
    "understood" -> True
    _ -> False
  }
}

fn error_response(status: Int, message: String) -> String {
  let body =
    json.object([#("error", json.string(message))])
    |> json.to_string

  response(status, json_content_type, body)
}

fn response(status: Int, content_type: String, body: String) -> String {
  json.object([
    #("status", json.int(status)),
    #("contentType", json.string(content_type)),
    #("body", json.string(body)),
  ])
  |> json.to_string
}
