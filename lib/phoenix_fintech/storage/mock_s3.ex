defmodule PhoenixFintech.Storage.MockS3 do
  alias PhoenixFintechWeb.Endpoint

  def upload_file(path, filename, content_type) do
    key = "party-docs/#{System.unique_integer([:positive])}-#{filename}"
    url = upload_url()
    body = File.read!(path)

    req =
      Req.new(
        url: url,
        headers: [
          {"content-type", content_type},
          {"x-object-key", key},
          {"x-filename", filename}
        ],
        body: body
      )

    case Req.put(req) do
      {:ok, %Req.Response{status: 201, body: %{"key" => stored_key, "url" => stored_url}}} ->
        {:ok, %{key: stored_key, url: stored_url}}

      {:ok, %Req.Response{status: status}} ->
        {:error, "mock storage upload failed with status #{status}"}

      {:error, reason} ->
        {:error, Exception.message(reason)}
    end
  end

  defp upload_url do
    Endpoint.url() <> "/api/mock_s3/objects"
  end
end
