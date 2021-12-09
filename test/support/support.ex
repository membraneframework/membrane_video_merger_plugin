defmodule Membrane.VideoMerger.Support do
  @moduledoc false
  import Membrane.Testing.Assertions
  import ExUnit.Assertions
  alias Membrane.{Buffer, Testing}

  @exact_result_period Membrane.Time.second()
  @maximal_error Membrane.Time.millisecond()

  @spec run_test(Testing.Pipeline.Options.t(), Enum.t(), {integer(), integer()}) :: :ok
  def run_test(pipeline_opts, indicies, framerate) do
    assert {:ok, pid} = Testing.Pipeline.start_link(pipeline_opts)
    assert Testing.Pipeline.play(pid) == :ok
    assert_end_of_stream(pid, :sink, :input, 10_000)

    check_sunk_buffers(pid, framerate, indicies)
    Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end

  defp check_sunk_buffers(pid, {frames, seconds}, buffers_indicies) do
    frame_duration = Ratio.new(Membrane.Time.second() * seconds, frames)
    expected = for i <- buffers_indicies, do: i |> Ratio.mult(frame_duration) |> Ratio.trunc()

    for expected_pts <- expected do
      assert_sink_buffer(pid, :sink, %Buffer{pts: buffer_pts})
      compare_pts(expected_pts, buffer_pts)
    end
  end

  defp compare_pts(expected_pts, buffer_pts) do
    if rem(expected_pts, @exact_result_period) == 0 do
      expected_pts == buffer_pts
    else
      abs(expected_pts - buffer_pts) <= @maximal_error
    end
  end
end
