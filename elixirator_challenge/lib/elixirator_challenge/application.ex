defmodule ElixiratorChallenge.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixiratorChallengeWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:elixirator_challenge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixiratorChallenge.PubSub},
      # Start a worker by calling: ElixiratorChallenge.Worker.start_link(arg)
      # {ElixiratorChallenge.Worker, arg},
      # Start to serve requests, typically the last entry
      ElixiratorChallengeWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixiratorChallenge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixiratorChallengeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
