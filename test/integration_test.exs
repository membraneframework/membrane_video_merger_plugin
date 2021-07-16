defmodule Membrane.VideoMerger.IntegrationTest do
  use ExUnit.Case, async: true

  import Membrane.ParentSpec
  import Membrane.Testing.Assertions
  alias Membrane.{File, H264, Pad, Testing, Time, VideoCutter, VideoMerger}
  require Pad

  @fps 30
  @framerate {@fps, 1}

  defp run_multiple_cutter_test(cutters, test_length) do
    assert {:ok, pid} = start_multiple_cutter_pipeline(cutters)
    assert(Testing.Pipeline.play(pid) == :ok)
    frame_duration = Ratio.new(Time.second(), @fps)

    assert_end_of_stream(pid, :sink, :input, 10_000)

    for i <- 0..(test_length * @fps - 1) do
      pts = Ratio.mult(frame_duration, i)
      assert_sink_buffer(pid, :sink, %Membrane.Buffer{metadata: %{pts: buffer_pts}})
      assert pts == buffer_pts
    end

    Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end

  defp start_multiple_cutter_pipeline(cutters) do
    elems = [merger: VideoMerger, sink: Testing.Sink]
    links = [link(:merger) |> to(:sink)]

    {_i, elems, links} =
      List.foldl(cutters, {1, elems, links}, fn cutter, {i, elems, links} ->
        {src_i, parser_i, decoder_i, cutter_i} =
          {String.to_atom("file_src_#{i}"), String.to_atom("parser_#{i}"),
           String.to_atom("decoder_#{i}"), String.to_atom("cutter_#{i}")}

        new_elems = [
          {src_i,
           %File.Source{
             chunk_size: 40_960,
             location: "./test/fixtures/test_video_10s.h264"
           }},
          {parser_i, %H264.FFmpeg.Parser{framerate: @framerate}},
          {decoder_i, H264.FFmpeg.Decoder},
          {cutter_i, cutter}
        ]

        new_links = [
          link(src_i)
          |> to(parser_i)
          |> to(decoder_i)
          |> to(cutter_i)
          |> via_in(Pad.ref(:input, i))
          |> to(:merger)
        ]

        {i + 1, elems ++ new_elems, links ++ new_links}
      end)

    Testing.Pipeline.start_link(%Testing.Pipeline.Options{
      elements: elems,
      links: links
    })
  end

  test "split into two parts and merge again" do
    cutters = [
      %VideoCutter{intervals: [{0, Time.seconds(2)}]},
      %VideoCutter{intervals: [{Time.seconds(2), :infinity}]}
    ]

    run_multiple_cutter_test(cutters, 10)
  end

  test "split into four parts and merge again" do
    cutters = [
      %VideoCutter{intervals: [{0, Time.seconds(2)}, {Time.seconds(8), :infinity}]},
      %VideoCutter{intervals: [{Time.seconds(2), Time.seconds(4)}]},
      %VideoCutter{intervals: [{Time.seconds(4), Time.seconds(6)}]},
      %VideoCutter{intervals: [{Time.seconds(6), Time.seconds(8)}]}
    ]

    run_multiple_cutter_test(cutters, 10)
  end

  test "merge only first two seconds of audio" do
    cutters = [
      %VideoCutter{intervals: [{0, Time.seconds(1)}]},
      %VideoCutter{intervals: [{Time.seconds(1), Time.seconds(2)}]}
    ]

    run_multiple_cutter_test(cutters, 2)
  end

  test "single cutter" do
    cutters = [
      %VideoCutter{intervals: [{Time.seconds(0), :infinity}]}
    ]

    run_multiple_cutter_test(cutters, 10)
  end
end
