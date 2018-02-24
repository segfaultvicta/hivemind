defmodule HivemindWeb.PageController do
  use HivemindWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
