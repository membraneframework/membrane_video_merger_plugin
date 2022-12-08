defmodule Membrane.VideoMerger.Support do
  @moduledoc false
  import Membrane.Testing.Assertions
  import ExUnit.Assertions
  alias Membrane.{Buffer, Testing}

  @maximal_error Membrane.Time.millisecond()

  @spec run_test(Testing.Pipeline.options(), Enum.t(), {integer(), integer()}) :: :ok
  def run_test(pipeline_structure, indices, framerate) do
    pipeline = Testing.Pipeline.start_link_supervised!(structure: pipeline_structure)
    assert_end_of_stream(pipeline, :sink, :input, 10_000)

    check_sunk_buffers(pipeline, framerate, indices)
  end

  defp check_sunk_buffers(pipeline, {frames, seconds}, buffers_indices) do
    frame_duration = Ratio.new(Membrane.Time.second() * seconds, frames)
    expected = for i <- buffers_indices, do: i |> Ratio.mult(frame_duration) |> Ratio.trunc()
    exact_result_period = seconds |> Membrane.Time.seconds()

    for expected_pts <- expected do
      assert_sink_buffer(pipeline, :sink, %Buffer{pts: buffer_pts})
      compare_pts(expected_pts, buffer_pts, exact_result_period)
    end
  end

  defp compare_pts(expected_pts, buffer_pts, exact_result_period) do
    if rem(expected_pts, exact_result_period) == 0 do
      expected_pts == buffer_pts
    else
      abs(expected_pts - buffer_pts) <= @maximal_error
    end
  end
end
