defmodule Membrane.VideoCutterTest do
  use ExUnit.Case, async: true

  alias Membrane.H264
  alias Membrane.Testing
  alias Membrane.Time
  alias Membrane.VideoCutter
  alias Membrane.VideoMerger.Support

  @fps 30
  @framerate {@fps, 1}

  defp get_pipeline_with_testing_sink_opts(video_cutter) do
    %Testing.Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{
          chunk_size: 40_960,
          location: "./test/fixtures/test_video_10s.h264"
        },
        parser: %H264.FFmpeg.Parser{framerate: @framerate},
        decoder: H264.FFmpeg.Decoder,
        video_cutter: video_cutter,
        sink: Testing.Sink
      ]
    }
  end

  defp test_for_intervals(intervals, indicies_ranges, offest \\ 0) do
    video_cutter = %VideoCutter{
      intervals: intervals,
      offset: offest
    }

    opts = get_pipeline_with_testing_sink_opts(video_cutter)
    indicies = Enum.flat_map(indicies_ranges, &Enum.to_list/1)
    Support.run_test(opts, indicies, @framerate)
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
