defmodule ElixiratorChallengeWeb.PageController do
  use ElixiratorChallengeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
