defmodule Membrane.VideoMerger.VideoCutterTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  alias Membrane.VideoCutter
  alias Membrane.H264
  alias Membrane.Testing
  alias Membrane.Time

  @framerate 30

  def make_pipeline_with_testing_sink(intervals) do
    Testing.Pipeline.start_link(%Testing.Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{
          chunk_size: 40_960,
          location:
            "/Users/andrzej/Membrane/membrane_video_merger_plugin/test/fixtures/test_video_10s.h264"
        },
        parser: %H264.FFmpeg.Parser{framerate: {@framerate, 1}},
        decoder: %H264.FFmpeg.Decoder{add_pts?: true},
        video_cutter: %VideoCutter{
          intervals: intervals
        },
        sink: Testing.Sink
      ]
    })
  end

  test "cut middle 3 seconds" do
    frame_duration = Ratio.new(Time.second(), @framerate)
    intervals = [{0, Time.second()}, {4 * Time.second(), :infinity}]

    # input video has 10[s] * 30[frames/s] = 300[frames]
    # there should be 300[frames] - (4-1)[s] * 30[frames/s] = 210[frames] on the testing sink with the following timestamps
    first_interval_pts_list = for i <- 0..29, do: Ratio.mult(frame_duration, i)
    second_interval_pts_list = for i <- 120..299, do: Ratio.mult(frame_duration, i)
    expected_pts_list = first_interval_pts_list ++ second_interval_pts_list

    assert {:ok, pid} = make_pipeline_with_testing_sink(intervals)
    assert Testing.Pipeline.play(pid) == :ok

    expected_pts_list
    |> Enum.each(fn expected_pts ->
      assert_sink_buffer(pid, :sink, %Membrane.Buffer{metadata: %{pts: buffer_pts}})
      assert expected_pts == buffer_pts
    end)

    assert_end_of_stream(pid, :sink, :input, 10_000)

    Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end
end
