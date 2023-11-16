defmodule Membrane.VideoMerger.IntegrationTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec

  require Membrane.Pad

  alias Membrane.{File, H264, Pad, Testing, Time, VideoCutter, VideoMerger}
  alias Membrane.VideoMerger.Support

  @fps 30
  @framerate {@fps, 1}

  defp run_multiple_cutter_pipeline(cutters, test_length) do
    structure = get_testing_structure(cutters)
    indices = 0..(test_length * @fps - 1)
    Support.run_test(structure, indices, @framerate)
  end

  defp get_testing_structure(cutters) do
    structure =
      Enum.with_index(
        cutters,
        fn cutter, i ->
          child(
            {:file_src, i},
            %File.Source{
              chunk_size: 40_960,
              location: "./test/fixtures/test_video_10s.h264"
            }
          )
          |> child({:parser, i}, %H264.Parser{
            generate_best_effort_timestamps: %{framerate: @framerate}
          })
          |> child({:decoder, i}, H264.FFmpeg.Decoder)
          |> child({:cutter, i}, cutter)
          |> via_in(Pad.ref(:input, i))
          |> get_child(:merger)
        end
      )

    structure = [child(:merger, VideoMerger) |> child(:sink, Testing.Sink)] ++ structure

    structure
  end

  test "split into two parts and merge again" do
    cutters = [
      %VideoCutter{intervals: [{0, Time.seconds(2)}]},
      %VideoCutter{intervals: [{Time.seconds(2), :infinity}]}
    ]

    run_multiple_cutter_pipeline(cutters, 10)
  end

  test "split into four parts and merge again" do
    cutters = [
      %VideoCutter{intervals: [{0, Time.seconds(2)}, {Time.seconds(8), :infinity}]},
      %VideoCutter{intervals: [{Time.seconds(2), Time.seconds(4)}]},
      %VideoCutter{intervals: [{Time.seconds(4), Time.seconds(6)}]},
      %VideoCutter{intervals: [{Time.seconds(6), Time.seconds(8)}]}
    ]

    run_multiple_cutter_pipeline(cutters, 10)
  end

  test "merge only first two seconds of audio" do
    cutters = [
      %VideoCutter{intervals: [{0, Time.seconds(1)}]},
      %VideoCutter{intervals: [{Time.seconds(1), Time.seconds(2)}]}
    ]

    run_multiple_cutter_pipeline(cutters, 2)
  end

  test "single cutter" do
    cutters = [
      %VideoCutter{intervals: [{Time.seconds(0), :infinity}]}
    ]

    run_multiple_cutter_pipeline(cutters, 10)
  end
end
