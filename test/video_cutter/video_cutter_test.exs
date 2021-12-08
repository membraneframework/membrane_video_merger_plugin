defmodule Membrane.VideoCutterTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  alias Membrane.H264
  alias Membrane.Testing
  alias Membrane.Time
  alias Membrane.VideoCutter

  @fps 30
  @framerate {@fps, 1}

  @spec make_pipeline_with_testing_sink(VideoCutter.t()) :: GenServer.on_start()
  def make_pipeline_with_testing_sink(video_cutter) do
    Testing.Pipeline.start_link(%Testing.Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{
          chunk_size: 40_960,
          location: "./test/fixtures/test_video_10s.h264"
        },
        parser: %H264.FFmpeg.Parser{framerate: @framerate},
        decoder: H264.FFmpeg.Decoder,
        video_cutter: video_cutter,
        sink: Testing.Sink
      ]
    })
  end

  test "cut middle 3s" do
    frame_duration = Ratio.new(Time.second(), @fps)
    intervals = [{0, Time.second()}, {4 * Time.second(), :infinity}]

    video_cutter = %VideoCutter{
      intervals: intervals
    }

    # input video has 10[s] * 30[frames/s] = 300[frames]
    # there should be 300[frames] - (4-1)[s] * 30[frames/s] = 210[frames]
    # on the testing sink with the following timestamps
    first_interval_pts_list = for i <- 0..29, do: i |> Ratio.mult(frame_duration) |> Ratio.trunc()

    second_interval_pts_list =
      for i <- 120..299, do: i |> Ratio.mult(frame_duration) |> Ratio.trunc()

    expected_pts_list = first_interval_pts_list ++ second_interval_pts_list

    assert {:ok, pid} = make_pipeline_with_testing_sink(video_cutter)
    assert Testing.Pipeline.play(pid) == :ok

    expected_pts_list
    |> Enum.each(fn expected_pts ->
      assert_sink_buffer(pid, :sink, %Membrane.Buffer{pts: buffer_pts})
      assert buffer_pts == expected_pts
    end)

    assert_end_of_stream(pid, :sink, :input, 10_000)

    Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end

  test "cut middle 3s and apply 0.5s offset" do
    frame_duration = Ratio.new(Time.second(), @fps)
    intervals = [{0, Time.second()}, {4 * Time.second(), :infinity}]
    offset = Ratio.new(Time.second(), 2)

    video_cutter = %VideoCutter{
      intervals: intervals,
      offset: offset
    }

    first_interval_pts_list =
      for i <- 0..29, do: i |> Ratio.mult(frame_duration) |> Ratio.add(offset) |> Ratio.trunc()

    second_interval_pts_list =
      for i <- 120..299, do: i |> Ratio.mult(frame_duration) |> Ratio.add(offset) |> Ratio.trunc()

    expected_pts_list = first_interval_pts_list ++ second_interval_pts_list

    assert {:ok, pid} = make_pipeline_with_testing_sink(video_cutter)
    assert Testing.Pipeline.play(pid) == :ok

    expected_pts_list
    |> Enum.each(fn expected_pts ->
      assert_sink_buffer(pid, :sink, %Membrane.Buffer{pts: buffer_pts})
      assert buffer_pts == expected_pts
    end)

    assert_end_of_stream(pid, :sink, :input, 10_000)

    Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end
end
