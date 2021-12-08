defmodule Membrane.VideoCutAndMergeTest do
  use ExUnit.Case, async: true

  import Membrane.ParentSpec
  import Membrane.Testing.Assertions
  alias Membrane.{Buffer, File, H264, Pad, Testing, Time}
  alias Membrane.VideoCutAndMerge
  alias Membrane.VideoCutAndMerge.Stream
  require Pad

  @fps 30
  @framerate {@fps, 1}

  defp run_pipeline_test(streams, test_length) do
    assert {:ok, pid} = start_pipeline(streams)
    assert(Testing.Pipeline.play(pid) == :ok)
    frame_duration = Ratio.new(Time.second(), @fps)

    assert_end_of_stream(pid, :sink, :input, 10_000)

    for i <- 0..(test_length * @fps - 1) do
      pts = Ratio.mult(frame_duration, i) |> Ratio.trunc()
      assert_sink_buffer(pid, :sink, %Buffer{pts: buffer_pts})
      assert buffer_pts == pts
    end

    Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end

  defp start_pipeline(streams) do
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

    Testing.Pipeline.start_link(%Testing.Pipeline.Options{
      elements: elems,
      links: links
    })
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
