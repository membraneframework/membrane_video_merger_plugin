defmodule Membrane.VideoMerger.IntegrationTest do
  use ExUnit.Case, async: true

  import Membrane.ParentSpec
  import Membrane.Testing.Assertions
  alias Membrane.{File, H264, Pad, Testing, Time, VideoCutter, VideoMerger}
  require Pad

  @framerate 30

  test "split into two parts and merge again" do
    elems = [
      file_src_1: %File.Source{
        chunk_size: 40_960,
        location: "./test/fixtures/test_video_10s.h264"
      },
      parser_1: %H264.FFmpeg.Parser{framerate: {@framerate, 1}},
      decoder_1: H264.FFmpeg.Decoder,
      file_src_2: %File.Source{
        chunk_size: 40_960,
        location: "./test/fixtures/test_video_10s.h264"
      },
      parser_2: %H264.FFmpeg.Parser{framerate: {@framerate, 1}},
      decoder_2: H264.FFmpeg.Decoder,
      merger: VideoMerger,
      sink: Testing.Sink,
      cutter_1: %VideoCutter{
        intervals: [{0, Membrane.Time.seconds(2)}]
      },
      cutter_2: %VideoCutter{
        intervals: [{Membrane.Time.seconds(2), :infinity}]
      }
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
    frame_duration = Ratio.new(Time.second(), @framerate)

    for i <- 0..299 do
      pts = Ratio.mult(frame_duration, i)
      assert_sink_buffer(pid, :sink, %Membrane.Buffer{metadata: %{pts: buffer_pts}})
      assert pts == buffer_pts
    end

    assert_end_of_stream(pid, :sink, :input, 10_000)
    Testing.Pipeline.stop(pid)
  end
end
