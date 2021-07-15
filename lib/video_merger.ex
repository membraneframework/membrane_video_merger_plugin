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
  alias Membrane.Caps.Video.Raw
  alias Membrane.Pad
  alias Membrane.Buffer

  @eos %Buffer{metadata: %{pts: -1}, payload: :end_of_stream}

  def_input_pad :input,
    caps: {Raw, aligned: true},
    demand_unit: :buffers,
    availability: :on_request

  def_output_pad :output,
    caps: {Raw, aligned: true}

  @impl true
  def handle_init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    demands =
      state
      |> get_empty_inputs()
      |> Enum.map(&{:demand, {Pad.ref(:input, &1), size}})

    {{:ok, demands}, state}
  end

  @impl true
  def handle_end_of_stream({_pad, :input, id} = pad_ref, _ctx, state) do
    state
    |> Map.update!(id, &(&1 ++ [@eos]))
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
    |> Map.update!(id, &(&1 ++ buffers))
    |> get_actions(redemand: :output)
  end

  defp get_empty_inputs(state) do
    state
    |> Enum.filter(fn {_id, buffers} -> buffers == [] end)
    |> Enum.map(fn {id, _val} -> id end)
  end

  defp get_actions(state, fallback) do
    case get_buffers(state) do
      {[], new_state} when new_state == %{} ->
        {{:ok, [end_of_stream: :output] ++ fallback}, %{}}

      {buffers, new_state} when new_state == %{} ->
        {{:ok, [end_of_stream: :output, buffers: buffers] ++ fallback}, %{}}

      {[], new_state} ->
        {{:ok, fallback}, new_state}

      {buffers, new_state} ->
        {{:ok, buffer: {:output, buffers}}, new_state}
    end
  end

  defp get_buffers(state, curr \\ [])
  defp get_buffers(state, _curr) when state == %{}, do: {[], state}

  defp get_buffers(state, curr) do
    if Enum.any?(state, fn {_id, buffers} -> buffers == [] end) do
      {Enum.reverse(curr), state}
    else
      {id, [buffer | _rest]} =
        Enum.min_by(state, fn {_id, [x | _rest]} -> x.metadata.pts end, &Ratio.lte?/2)

      if buffer == @eos do
        new_state = Map.delete(state, id)
        get_buffers(new_state, curr)
      else
        new_state = Map.update!(state, id, &tl/1)
        get_buffers(new_state, [buffer | curr])
      end
    end
  end
end
