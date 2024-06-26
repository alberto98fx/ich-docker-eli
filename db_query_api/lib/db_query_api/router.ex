defmodule DbQueryAPI.Router do
  use Plug.Router
  require Logger
  import Plug.Conn

  plug :match
  plug :dispatch

  post "/query" do
    {:ok, body, _conn} = read_body(conn)
    query = Jason.decode!(body)["query"]
    Logger.info("Received query: #{inspect(query)}")

    if query do
      result = DbQueryAPI.QueryService.run_query(query)
      send_resp(conn, 200, result)
    else
      send_resp(conn, 400, "Missing query parameter")
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
