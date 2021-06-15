defmodule Dubber do
  use Application

  @impl true
  def start(_type, _args) do
    {:ok, pid} = Dubber.Pipeline.start_link("example/path")
    Membrane.Pipeline.play(pid)

    {:ok, pid}
  end
end
