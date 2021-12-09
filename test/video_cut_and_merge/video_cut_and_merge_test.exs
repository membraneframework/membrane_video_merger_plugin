defmodule Membrane.VideoCutAndMergeTest do
  use ExUnit.Case, async: true

  import Membrane.ParentSpec
  alias Membrane.{File, H264, Pad, Testing, Time}
  alias Membrane.VideoCutAndMerge
  alias Membrane.VideoCutAndMerge.Stream
  alias Membrane.VideoMerger.Support
  require Pad

  @fps 30
  @framerate {@fps, 1}

  defp run_pipeline_test(streams, test_length) do
    opts = get_pipeline_opts(streams)
    indicies = 0..(test_length * @fps - 1)
    Support.run_test(opts, indicies, @framerate)
  end

  defp get_pipeline_opts(streams) do
    elem_names =
      streams
      |> Enum.with_index(fn stream, i ->
        {stream, "file_src_#{i}", "parser_#{i}", "decoder_#{i}"}
      end)

    elems =
      elem_names
      |> Enum.flat_map(fn {_stream, src_i, parser_i, decoder_i} ->
        [
          {src_i,
           %File.Source{
             chunk_size: 40_960,
             location: "./test/fixtures/test_video_10s.h264"
           }},
          {parser_i, %H264.FFmpeg.Parser{framerate: @framerate}},
          {decoder_i, H264.FFmpeg.Decoder}
        ]
      end)

    links =
      elem_names
      |> Enum.with_index(fn {stream, src_i, parser_i, decoder_i}, i ->
        link(src_i)
        |> to(parser_i)
        |> to(decoder_i)
        |> via_in(Pad.ref(:input, i), options: [stream: stream])
        |> to(:cut_and_merge)
      end)

    elems = [cut_and_merge: VideoCutAndMerge, sink: Testing.Sink] ++ elems
    links = [link(:cut_and_merge) |> to(:sink) | links]

    %Testing.Pipeline.Options{
      elements: elems,
      links: links
    }
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
