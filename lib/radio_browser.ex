defmodule RadioBrowser do
  @moduledoc """
  Client for the Radio Browser API.
  Provides access to worldwide radio station directory with search capabilities.
  """
  use GenServer

  @type search_params :: %{
          optional(:name) => String.t(),
          optional(:name_exact) => boolean(),
          optional(:country) => String.t(),
          optional(:country_exact) => boolean(),
          optional(:countrycode) => String.t(),
          optional(:state) => String.t(),
          optional(:state_exact) => boolean(),
          optional(:language) => String.t(),
          optional(:language_exact) => boolean(),
          optional(:tag) => String.t(),
          optional(:tag_exact) => boolean(),
          optional(:tag_list) => String.t(),
          optional(:bitrate_min) => integer(),
          optional(:bitrate_max) => integer(),
          optional(:order) => String.t(),
          optional(:reverse) => boolean(),
          optional(:offset) => integer(),
          optional(:limit) => integer(),
          optional(:hidebroken) => boolean()
        }

  @default_limit 100

  @default_params %{
    limit: @default_limit,
    offset: 0,
    hidebroken: true
  }
  @facets ["tags", "countries", "languages", "codecs", "states"]
  @valid_order_fields ~w(name url homepage favicon tags country state language votes codec bitrate lastcheckok lastchecktime clicktimestamp clickcount clicktrend random)
  @user_agent "RadioBrowser Elixir Client"

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_server do
    GenServer.call(__MODULE__, :get_server)
  end

  @doc """
  Play a radio station.
  returns the station
  and executes a click for the station
  """
  def play(station_uuid) do
    Task.start(fn -> GenServer.call(__MODULE__, {:click, station_uuid}) end)

    GenServer.call(__MODULE__, {:get_by_uuid, station_uuid})
  end

  @doc """
  Vote for a radio station.
  """
  def vote(station_uuid) do
    GenServer.call(__MODULE__, {:vote, station_uuid})
  end

  @doc """
  Click a radio station.
  """
  def click(station_uuid) do
    GenServer.call(__MODULE__, {:click, station_uuid})
  end

  @doc """
  Search stations by generic params.
  """
  @spec search(keyword()) :: {:ok, list()} | {:error, term()}
  def search(opts) do
    search_params = Map.merge(@default_params, Map.new(opts))
    GenServer.call(__MODULE__, {:search, search_params})
  end

  @doc """
  Search stations by country code.
  """
  def search_by_countrycode(countrycode) do
    search(countrycode: String.upcase(countrycode))
  end

  @doc """
  Search stations by name.
  """
  def search_by_name(name) do
    search(name: name, name_exact: false)
  end

  @doc """
  gets a valid facet
  """
  def get_facet(facet) when facet in @facets do
    GenServer.call(__MODULE__, {:get_facet, facet})
  end

  def get_facet(facet) do
    {:error, "invalid facet: #{inspect(facet)}"}
  end

  @impl true
  def init(_) do
    servers = discover_servers()

    {:ok, %{servers: servers}}
  end

  @impl true
  def handle_call(:get_server, _from, state) do
    server = get_random_server(state)
    {:reply, server, state}
  end

  @impl true
  def handle_call({:get_by_uuid, uuid}, _from, state) do
    params = %{uuids: [uuid], limit: 1}

    case post_by_path_and_uuid(state, "stations/byuuid", uuid, params) do
      {:reply, [], _} -> {:reply, nil, state}
      {:reply, [station], _} -> {:reply, station, state}
    end
  end

  @impl true
  def handle_call({:click, uuid}, _from, state) do
    get_by_path_and_uuid(state, "url", uuid)
  end

  @impl true
  def handle_call({:vote, uuid}, _from, state) do
    get_by_path_and_uuid(state, "vote", uuid)
  end

  def handle_call({:search, params}, _from, state) do
    post_by_path(state, "stations/search", params)
  end

  def handle_call({:get_facet, facet}, _from, state) do
    updated_state =
      Map.put_new_lazy(state, facet, fn ->
        {:reply, body, _state} = get_by_path(state, facet)
        body
      end)

    {:reply, updated_state[facet], updated_state}
  end

  @doc """
  Returns a list of URI structs for radio-browser API servers.
  """
  @spec discover_servers() :: [String.t()]
  def discover_servers do
    case :inet_res.lookup(~c"_api._tcp.radio-browser.info", :in, :srv) do
      [] ->
        ["https://de1.api.radio-browser.info"]

      records ->
        Enum.map(records, fn {_priority, _weight, port, host} ->
          scheme = if port == 443, do: "https", else: "http"
          %URI{scheme: scheme, port: port, host: to_string(host)}
        end)
    end
  end

  # Private functions

  defp validate_search_params(params) do
    with :ok <- validate_limit(params.limit),
         :ok <- validate_order(params[:order]) do
      :ok
    end
  end

  defp validate_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100_000, do: :ok
  defp validate_limit(_), do: {:error, "limit must be between 1 and 100000"}

  defp validate_order(nil), do: :ok
  defp validate_order(order) when order in @valid_order_fields, do: :ok
  defp validate_order(_), do: {:error, "invalid order field"}

  defp get_random_server(state) do
    Enum.random(state.servers)
  end

  defp get_by_path_and_uuid(state, path, uuid) do
    get_by_path(state, Path.join(path, uuid))
  end

  defp get_by_path(state, path) do
    server_uri = get_random_server(state)
    path = Path.join(["/json", path])
    {:ok, res} = Req.get(URI.to_string(%{server_uri | path: path}), user_agent: @user_agent)
    {:reply, res.body, state}
  end

  defp post_by_path_and_uuid(state, path, uuid, params) do
    post_by_path(state, Path.join(path, uuid), params)
  end

  defp post_by_path(state, path, params) do
    server_uri = get_random_server(state)
    path = Path.join(["/json", path])

    IO.inspect({%{server_uri | path: path}, user_agent: @user_agent, json: params})

    with :ok <- validate_search_params(params) do
      {:ok, res} =
        Req.post(URI.to_string(%{server_uri | path: path}), user_agent: @user_agent, json: params)

      {:reply, res.body, state}
    end
  end
end
