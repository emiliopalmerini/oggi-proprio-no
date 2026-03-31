defmodule OggiWeb.PageController do
  use OggiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
