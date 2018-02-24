defmodule HivemindWeb.Router do
  use HivemindWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HivemindWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/hive/:id", HiveController, :show
    post "/hive/", HiveController, :handle
  end

  # Other scopes may use custom stacks.
  # scope "/api", HivemindWeb do
  #   pipe_through :api
  # end
end
