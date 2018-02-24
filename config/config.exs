# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :hivemind, HivemindWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "9k3WQDzpEwGy2dqalpT5SeiqJDCZ5YjULOMuuxkWqI6IbbX73i25WkF6gnHcRDDS",
  render_errors: [view: HivemindWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Hivemind.PubSub,
           adapter: Phoenix.PubSub.PG2]

config :hivemind, :adjectives, ~w(
	shiny brilliant dusty sparkly polished amused boiling brave breezy bumpy careful charming courageous
	defiant delightful determined elated energetic exuberant faithful fantastic fierce fluffy friendly
	fuzzy gentle helpful hollow hungry jolly lively lucky magnificent magnanimous melodic
	melting miniature quaint quick rapid relieved resonant roasted responsible shaggy shivering splendid
	stupendous tangy thoughtful thundering victorious vivacious whimsical whispering zesty
)

config :hivemind, :nouns, ~w(
	armadillo pangolin teacup treehouse clavichord clover hurricane furball windowsill mountaintop
	leopard elephant gopher python camel windmill skyscraper shoelace matchstick snurble leaf willow
	panther tiger lion timberwolf teapot paintbrush tapestry spatula
)

config :hivemind, :happy_sentiments, ["happy"]

config :hivemind, :sad_sentiments, ["sad", "hardno"]

config :hivemind, :blocking_sentiments, ["question", "poo", "raisedhand", "hardno"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
