defmodule Membrane.VideoCutter do
  @moduledoc """
  Membrane element that cuts raw video.

  The element expects each frame to be received in a separate buffer, so the parser
  (`Membrane.Element.RawVideo.Parser`) may be required in a pipeline before
  the encoder (e.g. when input is read from `Membrane.File.Source`).

  To use this element, specify the desired intervals in the `intervals` options -
  `VideoCutter` will "filter" out all frames with timestamps outside of them.
  """
  use Membrane.Filter

  alias Membrane.{Buffer, RawVideo}

  def_options intervals: [
                spec: [{Membrane.Time.t(), Membrane.Time.t() | :infinity}],
                default: [{0, :infinity}],
                description: """
                List of intervals of timestamps. The buffer is forwarded when its timestamp belongs to any of the given intervals.
                The start of the interval is inclusive and the end is exclusive.

                For example, to cut part starting from 190 ms up to 1530 ms out of the video,
                the `intervals` should be set to `[{0, Membrane.Time.miliseconds(190)}, {Membrane.Time.miliseconds(1530), :infinity}]`.
                """
              ],
              offset: [
                spec: Membrane.Time.t(),
                default: 0,
                description: """
                Offset applied to all cut frames' presentation timestamp (PTS) values. It allows to logically shift the video to express its real starting point.

                For example, if there are two streams and the second one begins two seconds after the first one,
                video cutter that processes the second stream should apply a 2sec offset. Offset is applied after cutting phase.
                """
              ]

  def_input_pad :input, accepted_format: %RawVideo{aligned: true}
  def_output_pad :output, accepted_format: %RawVideo{aligned: true}

  @impl true
  def handle_init(_ctx, opts) do
    {[], opts}
  end

  @impl true
  def handle_buffer(_pad, %Buffer{pts: nil}, _ctx, _state) do
    raise "Cannot cut stream without pts"
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    actions =
      if within_any_interval?(buffer.pts, state.intervals),
        do: [buffer: {:output, [apply_offset(buffer, state.offset)]}],
        else: []

    {actions, state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {[end_of_stream: :output], state}
  end

  defp apply_offset(%Buffer{pts: pts} = buffer, offset) do
    %Buffer{buffer | pts: pts + offset}
  end

  defp within_any_interval?(timestamp, intervals) do
    Enum.any?(intervals, fn
      {:infinity, _any} ->
        false

      {start, :infinity} ->
        timestamp >= start

      {start, stop} ->
        timestamp >= start and timestamp < stop
    end)
  end
end
