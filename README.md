# RadioBrowser

An Elixir client for the [Radio Browser API](https://api.radio-browser.info/), providing access to a worldwide directory of radio stations. This client allows you to search, play, and manage radio stations through a simple and intuitive interface.

## Features

* Search radio stations by various criteria (name, country, language, etc.)
* Play radio stations
* Vote for stations
* Track station clicks
* Access station metadata and statistics
* Fetch faceted data (tags, countries, languages, etc.)

## Installation

Add `radio_browser` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:radio_browser, "~> 0.1.0"}
  ]
end
```

## Usage

Start the RadioBrowser client as part of your supervision tree:

```elixir
# In your application.ex
children = [
  RadioBrowser
]
Supervisor.start_link(children, strategy: :one_for_one)
```

### Searching for Stations

```elixir
# Search by name
RadioBrowser.search_by_name("jazz")

# Search by country code
RadioBrowser.search_by_countrycode("US")

# Advanced search with multiple criteria
RadioBrowser.search(
  name: "jazz",
  country: "United States",
  language: "english",
  tag: "smooth jazz",
  bitrate_min: 128,
  limit: 10
)
```

### Playing and Interacting with Stations

```elixir
# Play a station (returns station info and records click)
RadioBrowser.play("station-uuid")

# Vote for a station
RadioBrowser.vote("station-uuid")

# Manually record a click
RadioBrowser.click("station-uuid")
```

### Fetching Metadata

```elixir
# Get all available tags
RadioBrowser.get_facet("tags")

# Get all available countries
RadioBrowser.get_facet("countries")

# Get all available languages
RadioBrowser.get_facet("languages")
```

## Configuration

No configuration is required. The client automatically discovers and uses available Radio Browser API servers.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

This project is licensed under the MIT License. See LICENSE.md for details.
