defmodule RadioBrowser do
  @moduledoc """
  Client for the Radio Browser API (https://api.radio-browser.info/).

  This module provides a GenServer-based client to interact with the Radio Browser API,
  allowing you to search, play, and manage radio stations from a worldwide directory.

  ## Features

  * Search radio stations by various criteria (name, country, language, etc.)
  * Play radio stations
  * Vote for stations
  * Track station clicks
  * Access station metadata and statistics
  * Fetch faceted data (tags, countries, languages, etc.)

  ## Usage

  Start the client as part of your supervision tree:

      children = [
        RadioBrowser
      ]
      Supervisor.start_link(children, strategy: :one_for_one)

  Then use the various functions to interact with radio stations:

      # Search for stations
      RadioBrowser.search(name: "jazz", country: "US")

      # Play a station
      RadioBrowser.play("station-uuid")
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

  @doc """
  Starts the RadioBrowser client.

  This function starts a GenServer process that maintains the connection to the Radio Browser API
  and handles all API requests. The process is registered under the module name.

  ## Options

  Currently no options are supported, but they may be added in future versions.

  ## Return Values

  * `{:ok, pid}` - If the process was started successfully
  * `{:error, reason}` - If the process could not be started
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Retrieves a random API server from the pool of available servers.

  This is mainly used internally but can be useful for debugging purposes.

  ## Return Values

  Returns a URI struct representing the server address.
  """
  def get_server do
    GenServer.call(__MODULE__, :get_server)
  end

  @doc """
  Plays a radio station and records a click event.

  This function does two things:
  1. Returns the station information immediately
  2. Asynchronously records a click event for the station

  ## Parameters

  * `station_uuid` - The UUID of the station to play

  ## Return Values

  Returns the station information if found, or an error if the station doesn't exist.
  """
  def play(station_uuid) do
    Task.start(fn -> GenServer.call(__MODULE__, {:click, station_uuid}) end)

    GenServer.call(__MODULE__, {:get_by_uuid, station_uuid})
  end

  @doc """
  Votes for a radio station.

  Each client can vote for a station once within 24 hours.
  Votes help determine station popularity and rankings.

  ## Parameters

  * `station_uuid` - The UUID of the station to vote for

  ## Return Values

  * `{:ok, response}` - If the vote was recorded successfully
  * `{:error, reason}` - If the vote could not be recorded
  """
  def vote(station_uuid) do
    GenServer.call(__MODULE__, {:vote, station_uuid})
  end

  @doc """
  Records a click event for a radio station.

  Click events are used to track station popularity and generate statistics.
  This is automatically called by `play/1` but can be called manually if needed.

  ## Parameters

  * `station_uuid` - The UUID of the station that was clicked

  ## Return Values

  Returns the click response from the API.
  """
  def click(station_uuid) do
    GenServer.call(__MODULE__, {:click, station_uuid})
  end

  @doc """
  Searches for radio stations using the provided parameters.

  ## Parameters

  * `opts` - Keyword list of search parameters:
    * `:name` - (String) Station name to search for
    * `:name_exact` - (Boolean) Whether to match the name exactly
    * `:country` - (String) Country name to filter by
    * `:country_exact` - (Boolean) Whether to match the country exactly
    * `:countrycode` - (String) ISO country code to filter by
    * `:state` - (String) State/region to filter by
    * `:state_exact` - (Boolean) Whether to match the state exactly
    * `:language` - (String) Language to filter by
    * `:language_exact` - (Boolean) Whether to match the language exactly
    * `:tag` - (String) Tag to filter by
    * `:tag_exact` - (Boolean) Whether to match the tag exactly
    * `:tag_list` - (String) Comma-separated list of tags
    * `:bitrate_min` - (Integer) Minimum bitrate in kbps
    * `:bitrate_max` - (Integer) Maximum bitrate in kbps
    * `:order` - (String) Field to order by (see @valid_order_fields)
    * `:reverse` - (Boolean) Whether to reverse the order
    * `:offset` - (Integer) Number of results to skip
    * `:limit` - (Integer) Maximum number of results to return
    * `:hidebroken` - (Boolean) Whether to hide broken stations

  ## Return Values

  * `{:ok, stations}` - List of stations matching the search criteria
  * `{:error, reason}` - If the search failed
  """
  @spec search(keyword()) :: {:ok, list()} | {:error, term()}
  def search(opts) do
    search_params = Map.merge(@default_params, Map.new(opts))
    GenServer.call(__MODULE__, {:search, search_params})
  end

  @doc """
  Searches for radio stations by country code.

  This is a convenience wrapper around `search/1` that automatically
  uppercases the country code.

  ## Parameters

  * `countrycode` - ISO 3166-1 alpha-2 country code (e.g., "US", "GB", "DE")

  ## Return Values

  Same as `search/1`
  """
  def search_by_countrycode(countrycode) do
    search(countrycode: String.upcase(countrycode))
  end

  @doc """
  Searches for radio stations by name.

  This is a convenience wrapper around `search/1` that performs a non-exact
  name search.

  ## Parameters

  * `name` - Name or partial name of the station to search for

  ## Return Values

  Same as `search/1`
  """
  def search_by_name(name) do
    search(name: name, name_exact: false)
  end

  @doc """
  Retrieves faceted data from the API.

  Facets are pre-aggregated lists of values that can be used for filtering
  and navigation. Available facets are: #{inspect(@facets)}

  ## Parameters

  * `facet` - Name of the facet to retrieve (atom or string)

  ## Return Values

  * List of facet values if the facet exists
  * `{:error, reason}` if the facet is invalid
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

    post_by_path_and_uuid(state, "stations/byuuid", uuid, params)
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

    with :ok <- validate_search_params(params) do
      {:ok, res} =
        Req.post(URI.to_string(%{server_uri | path: path}), user_agent: @user_agent, json: params)

      {:reply, res.body, state}
    end
  end
end
