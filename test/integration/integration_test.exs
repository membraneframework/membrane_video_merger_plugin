defmodule Membrane.VideoMerger.IntegrationTest do
  use ExUnit.Case, async: true

  import Membrane.ParentSpec
  alias Membrane.{File, H264, Pad, Testing, Time, VideoCutter, VideoMerger}
  alias Membrane.VideoMerger.Support
  require Pad

  @fps 30
  @framerate {@fps, 1}

  defp run_multiple_cutter_pipeline(cutters, test_length) do
    opts = get_testing_opts(cutters)
    indicies = 0..(test_length * @fps - 1)
    Support.run_test(opts, indicies, @framerate)
  end

  defp get_testing_opts(cutters) do
    elem_names =
      cutters
      |> Enum.with_index(fn cutter, i ->
        {cutter, "file_src_#{i}", "parser_#{i}", "decoder_#{i}", "cutter_#{i}"}
      end)

    elems =
      elem_names
      |> Enum.flat_map(fn {cutter, src_i, parser_i, decoder_i, cutter_i} ->
        [
          {src_i,
           %File.Source{
             chunk_size: 40_960,
             location: "./test/fixtures/test_video_10s.h264"
           }},
          {parser_i, %H264.FFmpeg.Parser{framerate: @framerate}},
          {decoder_i, H264.FFmpeg.Decoder},
          {cutter_i, cutter}
        ]
      end)

    links =
      elem_names
      |> Enum.with_index(fn {_cutter, src_i, parser_i, decoder_i, cutter_i}, i ->
        link(src_i)
        |> to(parser_i)
        |> to(decoder_i)
        |> to(cutter_i)
        |> via_in(Pad.ref(:input, i))
        |> to(:merger)
      end)

    elems = [merger: VideoMerger, sink: Testing.Sink] ++ elems
    links = [link(:merger) |> to(:sink) | links]

    %Testing.Pipeline.Options{
      elements: elems,
      links: links
    }
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