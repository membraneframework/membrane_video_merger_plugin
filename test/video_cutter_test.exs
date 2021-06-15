defmodule Membrane.VideoMerger.VideoCutterTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  alias Membrane.VideoCutter
  alias Membrane.H264
  alias Membrane.Testing.Pipeline

  def make_pipeline() do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{
          chunk_size: 40_960,
          location:
            "/Users/andrzej/Membrane/membrane_video_merger_plugin/test/fixtures/test_video_10s.h264"
        },
        parser: H264.FFmpeg.Parser,
        decoder: H264.FFmpeg.Decoder,
        video_cutter: VideoCutter,
        encoder: %H264.FFmpeg.Encoder{preset: :fast, crf: 30},
        sink: %Membrane.File.Sink{
          location:
            "/Users/andrzej/Membrane/membrane_video_merger_plugin/test/results/test_video_10s.h264"
        }
      ]
    })
  end

  test "simple test" do
    assert {:ok, pid} = make_pipeline()
    assert Pipeline.play(pid) == :ok
    assert_end_of_stream(pid, :sink, :input, 10_000)
  end
end
