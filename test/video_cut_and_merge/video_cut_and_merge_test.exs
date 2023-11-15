defmodule Membrane.VideoCutAndMergeTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec

  require Membrane.Pad

  alias Membrane.{File, H264, Pad, Testing, Time}
  alias Membrane.VideoCutAndMerge
  alias Membrane.VideoCutAndMerge.Stream
  alias Membrane.VideoMerger.Support

  @fps 30
  @framerate {@fps, 1}

  defp run_pipeline_test(streams, test_length) do
    structure = get_pipeline_structure(streams)
    indices = 0..(test_length * @fps - 1)
    Support.run_test(structure, indices, @framerate)
  end

  defp get_pipeline_structure(streams) do
    structure =
      Enum.with_index(
        streams,
        fn stream, i ->
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
          |> via_in(Pad.ref(:input, i), options: [stream: stream])
          |> get_child(:cut_and_merge)
        end
      )

    structure =
      [child(:cut_and_merge, VideoCutAndMerge) |> child(:sink, Testing.Sink)] ++ structure

    structure
  end

  test "split into two parts and merge again" do
    streams = [
      %Stream{intervals: [{0, Time.seconds(2)}]},
      %Stream{intervals: [{Time.seconds(2), :infinity}]}
    ]

    run_pipeline_test(streams, 10)
  end

  test "split into five parts and merge again" do
    streams = [
      %Stream{intervals: [{0, Time.seconds(1)}]},
      %Stream{
        intervals: [{Time.seconds(1), Time.seconds(2)}, {Time.seconds(7), Time.seconds(9)}]
      },
      %Stream{intervals: [{Time.seconds(2), Time.seconds(5)}]},
      %Stream{intervals: [{Time.seconds(5), Time.seconds(7)}]},
      %Stream{intervals: [{Time.seconds(9), :infinity}]}
    ]

    run_pipeline_test(streams, 10)
  end
end
