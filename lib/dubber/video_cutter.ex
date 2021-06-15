defmodule Dubber.VideoCutter do
  use Membrane.Filter

  def_output_pad :output, caps: :any

  def_input_pad :input, caps: :any, demand_unit: :buffers

  @impl true
  def handle_init(intervals) do
    {:ok, %{intervals: intervals}}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  def handle_process(:input, buffer, _ctx, state) do
    %Buffer{metadata: metadata} = buffer

    if check_buffer(metadata.timestamp, state.intervals),
      do: {{:ok, [buffer: {:output, buffer}, redemand: :output]}, state},
      else: {{:ok, [redemand: :output]}, state}
  end

  defp check_buffer(timestamp, ranges) do
    Enum.any?(ranges, fn %{start: start, stop: stop} ->
      timestamp >= start and timestamp < stop
    end)
  end
end
