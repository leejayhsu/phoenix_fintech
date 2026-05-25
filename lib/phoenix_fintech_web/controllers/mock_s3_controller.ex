defmodule PhoenixFintechWeb.MockS3Controller do
  use PhoenixFintechWeb, :controller

  def put_object(conn, _params) do
    object_key = List.first(get_req_header(conn, "x-object-key")) || "unknown"
    filename = List.first(get_req_header(conn, "x-filename")) || "upload.bin"

    target_dir = Path.join([File.cwd!(), "priv", "static", "mock_s3", Path.dirname(object_key)])
    :ok = File.mkdir_p(target_dir)

    target_path = Path.join(target_dir, Path.basename(object_key))
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    :ok = File.write(target_path, body)

    json(conn |> put_status(:created), %{
      key: object_key,
      filename: filename,
      url: "/mock_s3/#{object_key}"
    })
  end
end
