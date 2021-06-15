defmodule Membrane.VideoCutter do
  use Membrane.Filter

  alias Membrane.Buffer
  alias Membrane.Caps.Video.Raw

  def_output_pad :output,
    caps: {Raw, format: one_of([:I420, :I422]), aligned: true}

  def_input_pad :input,
    caps: {Raw, format: one_of([:I420, :I422]), aligned: true},
    demand_unit: :buffers

  @impl true
  def handle_init(_intervals) do
    # {:ok, %{intervals: intervals}}
    {:ok, %{caps_sent: false}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_caps(:input, caps, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {:ok, state}
  end

  def handle_process(:input, buffer, ctx, state) do
    IO.inspect("[Video cutter] Processing...")
    buffer_action = [buffer: {:output, [buffer]}]

    {caps_action, state} =
      if ctx.pads.input.caps != nil and state.caps_sent == false do
        {[caps: {:output, ctx.pads.input.caps}], %{state | caps_sent: true}}
      else
        {[], state}
      end

    actions = buffer_action ++ caps_action ++ [redemand: :output]
    IO.inspect(actions, label: "$$$")
    {{:ok, actions}, state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {{:ok, [end_of_stream: :output, notify: {:end_of_stream, :input}]}, state}
  end

  defp check_buffer(timestamp, ranges) do
    Enum.any?(ranges, fn %{start: start, stop: stop} ->
      timestamp >= start and timestamp < stop
    end)
  end
end
