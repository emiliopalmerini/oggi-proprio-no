defmodule OggiWeb.Router do
  use OggiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OggiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OggiWeb do
    pipe_through :browser

    live "/", PollLive.New
    live "/p/:token", PollLive.Show
  end

  # Other scopes may use custom stacks.
  # scope "/api", OggiWeb do
  #   pipe_through :api
  # end
end
