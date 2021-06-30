defmodule Membrane.VideoCutter do
  use Membrane.Filter

  alias Membrane.Caps.Video.Raw

  def_options intervals: [
                spec: [{Membrane.Time.t(), Membrane.Time.t() | :infinity}],
                default: [{0, :infinity}],
                description: """
                List of intervals of timestamps. The buffer is forwarder when its timestamp belongs
                to any of the given intervals. The start of the interval is inclusive and the end is
                exclusive. By default, the cutter is initialized with a single interval [0, :infinity)
                """
              ],
              offset: [
                spec: Membrane.Time.t(),
                default: 0,
                description: """
                Offset is applied to all output frames pts values. It allows to logically shift the
                video to express its real starting point. For example, if there are two streams and
                the second one begins two seconds after the first one, video cutter that processes
                the second stream should apply a 2sec offset. Offset is applied after the cutting phase.
                """
              ]

  def_output_pad :output,
    caps: {Raw, format: one_of([:I420, :I422]), aligned: true}

  def_input_pad :input,
    caps: {Raw, format: one_of([:I420, :I422]), aligned: true},
    demand_unit: :buffers

  @impl true
  def handle_init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {:ok, state}
  end

  def handle_process(:input, buffer, _ctx, state) do
    if not Map.has_key?(buffer.metadata, :pts), do: raise("Cannot cut stream without pts")

    buffer_action =
      if within_any_interval(buffer.metadata.pts, state.intervals),
        do: [buffer: {:output, [apply_offset(buffer, state.offset)]}],
        else: []

    actions = buffer_action ++ [redemand: :output]

    {{:ok, actions}, state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {{:ok, [end_of_stream: :output, notify: {:end_of_stream, :input}]}, state}
  end

  defp apply_offset(buffer, offset) do
    Bunch.Struct.update_in(buffer, [:metadata, :pts], &Ratio.add(&1, offset))
  end

  defp within_any_interval(timestamp, intervals) do
    use Ratio

    Enum.any?(intervals, fn
      {:infinity, _any} ->
        false

      {start, :infinity} ->
        Ratio.gte?(timestamp, start)

      {start, stop} ->
        Ratio.gte?(timestamp, start) and Ratio.lt?(timestamp, stop)
    end)
  end
end
