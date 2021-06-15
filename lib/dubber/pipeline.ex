defmodule Dubber.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(path_to_config) do
    worker_config = parse(path_to_config)

    
  end
end
