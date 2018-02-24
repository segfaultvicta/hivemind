defmodule HivemindWeb.HiveController do
  use HivemindWeb, :controller
  require Logger

  def show(conn, %{"id" => id}) do
  	conn
  	|> put_resp_cookie("location-id", id, [max_age: 20, http_only: false])
  	|> render("show.html")
  end

  def handle(conn, params) do
  	conn
  	|> redirect(to: hive_path(conn, :show, params["target"]))
  end
end
