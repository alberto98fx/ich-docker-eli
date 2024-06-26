defmodule DbQueryAPI.QueryService do
  require Logger
  alias HTTPoison

  @consul_host System.get_env("CONSUL_HTTP_ADDR") || "http://consul:8500"
  @mysql_root_password System.get_env("MYSQL_ROOT_PASSWORD") || "tooo"

  def run_query(query) when is_binary(query) do
    mysql_hosts = get_mysql_hosts()
    Logger.info("MySQL hosts: #{inspect(mysql_hosts)}")

    if mysql_hosts == [] do
      "No MySQL hosts found in Consul"
    else
      Logger.info("Running query: #{query}")

      results =
        mysql_hosts
        |> Task.async_stream(fn {host, port} ->
          connect_and_run_query(host, port, query)
        end, timeout: :infinity)
        |> Enum.map(fn
          {:ok, {:ok, {host, result}}} -> "#{host}: #{inspect(result)}"
          {:ok, {:error, {host, error}}} -> "#{host}: Error - #{error}"
          {:error, {host, error}} -> "#{host}: Task error: #{inspect(error)}"
          {:error, error} -> "General task error: #{inspect(error)}"  # General error handling
        end)



      Enum.join(results, "\n")
    end
  end

  def run_query(_), do: "Invalid query parameter"

  defp connect_and_run_query(host, port, query, attempts \\ 0) do
    Logger.info("Attempting to connect to MySQL at #{host}:#{port} (Attempt #{attempts + 1})")

    case MyXQL.start_link([
      hostname: host,
      port: String.to_integer(port),
      username: "root",
      password: @mysql_root_password,
      database: "game",
      pool_size: 2,
      queue_target: 5000,
      queue_interval: 5000,
      backoff_type: :exp,
      backoff_min: 1000,
      backoff_max: 30_000
    ]) do
      {:ok, conn} ->
        case MyXQL.query(conn, query) do
          {:ok, result} -> {:ok, {host, result}}
          {:error, error} -> {:error, {host, error}}
        end
      {:error, error} ->
        if attempts < 5 do
          connect_and_run_query(host, port, query, attempts + 1)
        else
          {:error, {host, error}}
        end
      {:error, error} ->
        Logger.warn("Connection error to #{host}:#{port}: #{inspect(error)}. Retrying...")
        backoff_time = :rand.uniform(round(:math.pow(1000, (2 + attempts))))
        :timer.sleep(backoff_time)
        if attempts < 5 do
          connect_and_run_query(host, port, query, attempts + 1)
        else
          Logger.error("Connection error to #{host}:#{port}: #{inspect(error)}. Max retries reached.")
          {:error, "Connection failed after multiple attempts: #{inspect(error)}"}
        end
    end
  end

  defp execute_query(conn, query) do
    case MyXQL.query(conn, query) do
      {:ok, result} -> {:ok, result}
      {:error, error} ->
        Logger.error("Query error: #{inspect(error)}")
        {:error, "Query failed: #{inspect(error)}"}
    end
  end

  defp get_mysql_hosts do
    Logger.info("Fetching MySQL hosts from Consul")
    case HTTPoison.get("#{@consul_host}/v1/catalog/service/mysql") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info("Consul response: #{inspect(body)}")
        case Jason.decode(body) do
          {:ok, json} ->
            json
            |> Enum.map(fn %{"ServiceAddress" => address, "ServicePort" => port} ->
              {address, Integer.to_string(port)}
            end)
          {:error, decode_error} ->
            Logger.error("Error decoding Consul response: #{inspect(decode_error)}")
            []
        end
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("Received unexpected status code from Consul: #{status_code}")
        []
      {:error, request_error} ->
        Logger.error("Error fetching from Consul: #{inspect(request_error)}")
        []
    end
  end
end
