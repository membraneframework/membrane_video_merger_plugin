defmodule Membrane.VideoMerger.IntegrationTest do
  use ExUnit.Case, async: true

  import Membrane.ParentSpec
  import Membrane.Testing.Assertions
  alias Membrane.{File, H264, Pad, Testing, Time, VideoCutter, VideoMerger}
  require Pad

  @fps 30
  @framerate {@fps, 1}

  test "split into two parts and merge again" do
    elems = [
      file_src_1: %File.Source{
        chunk_size: 40_960,
        location: "./test/fixtures/test_video_10s.h264"
      },
      parser_1: %H264.FFmpeg.Parser{framerate: @framerate},
      decoder_1: H264.FFmpeg.Decoder,
      file_src_2: %File.Source{
        chunk_size: 40_960,
        location: "./test/fixtures/test_video_10s.h264"
      },
      parser_2: %H264.FFmpeg.Parser{framerate: @framerate},
      decoder_2: H264.FFmpeg.Decoder,
      cutter_1: %VideoCutter{intervals: [{0, Time.seconds(1)}]},
      cutter_2: %VideoCutter{intervals: [{Time.seconds(1), Time.seconds(2)}]},
      merger: VideoMerger,
      sink: Testing.Sink
    ]

    links = [
      link(:file_src_1)
      |> to(:parser_1)
      |> to(:decoder_1)
      |> to(:cutter_1)
      |> via_in(Pad.ref(:input, 1))
      |> to(:merger)
      |> to(:sink),
      link(:file_src_2)
      |> to(:parser_2)
      |> to(:decoder_2)
      |> to(:cutter_2)
      |> via_in(Pad.ref(:input, 2))
      |> to(:merger)
    ]

    assert {:ok, pid} =
             Testing.Pipeline.start_link(%Testing.Pipeline.Options{
               elements: elems,
               links: links
             })

    assert Testing.Pipeline.play(pid) == :ok
    frame_duration = Ratio.new(Time.second(), @fps)

    assert_end_of_stream(pid, :sink, :input, 10_000)

    for i <- 0..59 do
      pts = Ratio.mult(frame_duration, i)
      assert_sink_buffer(pid, :sink, %Membrane.Buffer{metadata: %{pts: buffer_pts}})
      assert pts == buffer_pts
    end

    Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end
end
