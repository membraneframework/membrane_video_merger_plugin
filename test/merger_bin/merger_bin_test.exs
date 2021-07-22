defmodule Membrane.VideoMergerBin.BinTest do
  use ExUnit.Case, async: true

  import Membrane.ParentSpec
  import Membrane.Testing.Assertions
  alias Membrane.{Buffer, File, H264, Pad, Testing, Time, VideoMergerBin}
  alias Membrane.VideoMergerBin.Stream
  require Pad

  @fps 30
  @framerate {@fps, 1}

  defp run_pipeline_test(streams, test_length) do
    assert {:ok, pid} = start_pipeline(streams)
    assert(Testing.Pipeline.play(pid) == :ok)
    frame_duration = Ratio.new(Time.second(), @fps)

    assert_end_of_stream(pid, :sink, :input, 10_000)

    for i <- 0..(test_length * @fps - 1) do
      pts = Ratio.mult(frame_duration, i)
      assert_sink_buffer(pid, :sink, %Buffer{metadata: %{pts: buffer_pts}})
      assert pts == buffer_pts
    end

    Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end

  defp start_pipeline(streams) do
    elems = [merger_bin: %VideoMergerBin{streams: streams}, sink: Testing.Sink]
    links = [link(:merger_bin) |> to(:sink)]

    {elems, links} =
      List.foldl(streams, {elems, links}, fn %Stream{id: id}, {elems, links} ->
        {src_i, parser_i, decoder_i} =
          {String.to_atom("file_src_#{id}"), String.to_atom("parser_#{id}"),
           String.to_atom("decoder_#{id}")}

        new_elems = [
          {src_i,
           %File.Source{
             chunk_size: 40_960,
             location: "./test/fixtures/test_video_10s.h264"
           }},
          {parser_i, %H264.FFmpeg.Parser{framerate: @framerate}},
          {decoder_i, H264.FFmpeg.Decoder}
        ]

        new_links = [
          link(src_i)
          |> to(parser_i)
          |> to(decoder_i)
          |> via_in(Pad.ref(:input, id))
          |> to(:merger_bin)
        ]

        {elems ++ new_elems, links ++ new_links}
      end)

    Testing.Pipeline.start_link(%Testing.Pipeline.Options{
      elements: elems,
      links: links
    })
  end

  test "split into two parts and merge again" do
    streams = [
      %Stream{id: :first, intervals: [{0, Time.seconds(2)}]},
      %Stream{id: :second, intervals: [{Time.seconds(2), :infinity}]}
    ]

    run_pipeline_test(streams, 10)
  end

  test "split into five parts and merge again" do
    streams = [
      %Stream{id: :a, intervals: [{0, Time.seconds(1)}]},
      %Stream{
        id: :b,
        intervals: [
          {Time.seconds(1), Time.seconds(2)},
          {Time.seconds(7), Time.seconds(9)}
        ]
      },
      %Stream{id: :c, intervals: [{Time.seconds(2), Time.seconds(5)}]},
      %Stream{id: :d, intervals: [{Time.seconds(5), Time.seconds(7)}]},
      %Stream{id: :e, intervals: [{Time.seconds(9), :infinity}]}
    ]

    run_pipeline_test(streams, 10)
  end
end
