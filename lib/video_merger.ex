defmodule Membrane.VideoMerger do
  @moduledoc """
  Membrane element that merges multiple raw videos into one.

  The element expects each frame to be received in a separate buffer, so the parser
  (`Membrane.Element.RawVideo.Parser`) may be required in a pipeline before
  the merger (e.g. when input is read from `Membrane.File.Source`).

  The element expects to receive frames in order from each input.

  Currently, `VideoMerger` may not be suitable for live merging streams: the element
  awaits for at least one frame from each of the inputs, and forwards the one
  with the lowest presentation timestamp.
  """

  use Membrane.Filter

  alias __MODULE__.BufferQueue
  alias Membrane.Caps.Video.Raw
  alias Membrane.Pad

  def_input_pad :input,
    caps: {Raw, aligned: true},
    demand_unit: :buffers,
    availability: :on_request

  def_output_pad :output,
    caps: {Raw, aligned: true}

  @impl true
  def handle_init(_opts) do
    {:ok, BufferQueue.new()}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    demands =
      state
      |> BufferQueue.get_empty_ids()
      |> Enum.map(&{:demand, {Pad.ref(:input, &1), size}})

    {{:ok, demands}, state}
  end

  @impl true
  def handle_end_of_stream({_pad, :input, id} = pad_ref, _ctx, state) do
    state
    |> BufferQueue.enqueue_eos(id)
    |> get_actions(notify: pad_ref)
  end

  @impl true
  def handle_pad_added({_pad, :input, id}, _ctx, state) do
    {:ok, Map.put_new(state, id, [])}
  end

  @impl true
  def handle_process_list({_pad, :input, id}, buffers, _context, state) do
    if not Enum.all?(buffers, &Map.has_key?(&1.metadata, :pts)) do
      raise("Cannot merge stream without pts")
    end

    state
    |> BufferQueue.enqueue_list(id, buffers)
    |> get_actions(redemand: :output)
  end

  defp get_actions(state, fallback) do
    case BufferQueue.dequeue_buffers(state) do
      {:ok, :end_of_stream} ->
        {{:ok, fallback ++ [end_of_stream: :output]}, %{}}

      {{:ok, buffers: buffers}, :end_of_stream} ->
        {{:ok, [buffers: buffers] ++ fallback ++ [end_of_stream: :output]}, %{}}

      {:ok, new_state} ->
        {{:ok, fallback}, new_state}

      {{:ok, buffers: buffers}, new_state} ->
        {{:ok, buffer: {:output, buffers}}, new_state}
    end
  end
end
