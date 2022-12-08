defmodule Membrane.VideoCutterTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec

  alias Membrane.H264
  alias Membrane.Testing
  alias Membrane.Time
  alias Membrane.VideoCutter
  alias Membrane.VideoMerger.Support

  @fps 30
  @framerate {@fps, 1}

  defp get_pipeline_with_testing_sink_structure(video_cutter) do
    child(
      :file_src,
      %Membrane.File.Source{
        chunk_size: 40_960,
        location: "./test/fixtures/test_video_10s.h264"
      }
    )
    |> child(:parser, %H264.FFmpeg.Parser{framerate: @framerate})
    |> child(:decoder, H264.FFmpeg.Decoder)
    |> child(:video_cutter, video_cutter)
    |> child(:sink, Testing.Sink)
  end

  defp test_for_intervals(intervals, indices_ranges, offset \\ 0) do
    video_cutter = %VideoCutter{
      intervals: intervals,
      offset: offset
    }

    structure = get_pipeline_with_testing_sink_structure(video_cutter)
    indices = Enum.flat_map(indices_ranges, &Enum.to_list/1)
    Support.run_test(structure, indices, @framerate)
  end

  test "cut middle 3s" do
    intervals = [{0, Time.second()}, {4 * Time.second(), :infinity}]
    ranges = [0..29, 120..299]
    test_for_intervals(intervals, ranges)
  end

  test "cut middle 3s and apply 0.5s offset" do
    intervals = [{0, Time.second()}, {4 * Time.second(), :infinity}]
    offset = Time.milliseconds(500)
    ranges = [0..29, 120..299]
    test_for_intervals(intervals, ranges, offset)
  end
end
