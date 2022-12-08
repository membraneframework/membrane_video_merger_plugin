# Membrane VideoMerger Plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_video_merger_plugin.svg)](https://hex.pm/packages/membrane_video_merger_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_video_merger_plugin)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_video_merger_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_video_merger_plugin)

Plugin containing elements for cutting and merging raw video. By using this plugin you can
  - simply merge multiple video tracks (`VideoMerger`)
  - cut out specific intervals of video track (`VideoCutter`)
  - combine chosen parts raw video tracks into one (`VideoCutAndMerge`), for instance by taking 
  the first half of one track and combining it with the second half of another

For most cases, the `VideoCutAndMerge` bin should be your first choice. 

Implementations of the `VideoCutter` and the `VideoMerger` are using presentation timestamps,
so every `Buffer` should have the `pts` field set.

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

The package can be installed by adding `membrane_video_merger_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
	{:membrane_video_merger_plugin, "~> 0.7.0"}
  ]
end
```

## Sample Usage

Both pipelines will result in creating `/tmp/output.raw` file with the first 5 seconds of the 
`input_1` track and everything but the first 5 seconds of the `input_2` track.

`/tmp/input_1.h264` and `/tmp/input_2.h264` should be an H264 video files.

### CutAndMerge bin

```elixir
defmodule VideoCutAndMerge.Pipeline do
  use Membrane.Pipeline

  alias Membrane.VideoCutAndMerge
  alias Membrane.H264.FFmpeg.{Parser, Decoder}
  alias Membrane.File.{Sink, Source}

  @impl true
  def handle_init(_ctx, _options) do
    stream_1 = %VideoCutAndMerge.Stream{intervals: [{0, Membrane.Time.seconds(5)}]}
    stream_2 = %VideoCutAndMerge.Stream{intervals: [{Membrane.Time.seconds(5), :infinity}]}

    structure = [
      child(:cut_and_merge, VideoCutAndMerge)
      |> child(:sink, %Sink{location: "/tmp/output.raw"}),

      child({:file_src, 1}, %Source{chunk_size: 40_960, location: "/tmp/input_1.h264"})
      |> child({:parser, 1}, %Parser{framerate: {30, 1}})
      |> child({:decoder, 1}, Decoder)
      |> via_in(Pad.ref(:input, 1), options: [stream: stream_1])
      |> get_child(:cut_and_merge),

      child({:file_src, 2}, %Source{chunk_size: 40_960, location: "/tmp/input_2.h264"})
      |> child({:parser, 2}, %Parser{framerate: {30, 1}})
      |> child({:decoder, 2}, Decoder)
      |> via_in(Pad.ref(:input, 2), options: [stream: stream_2])
      |> get_child(:cut_and_merge)
    ]

    {[spec: structure], %{}}
  end
end
```

### VideoCutter and VideoMerger

```elixir
defmodule VideoMerger.Pipeline do
  use Membrane.Pipeline

  alias Membrane.H264.FFmpeg.{Parser, Decoder}
  alias Membrane.File.{Sink, Source}
  alias Membrane.{VideoCutter, VideoMerger}

  @impl true
  def handle_init(_ctx, _options) do
    structure = [
      child(:merger, VideoMerger)
      |> child(:sink, %Sink{location: "/tmp/output.raw"),

      child({:file_src, 1}, %Source{chunk_size: 40_960, location: "/tmp/input_1.h264"})
      |> child({:parser, 1}, %Parser{framerate: {30, 1}})
      |> child({:decoder, 1}, Decoder)
      |> child({:cutter, 1}, %VideoCutter{intervals: [{0, Membrane.Time.seconds(5)}]})
      |> via_in(Pad.ref(:input, 1))
      |> get_child(:merger),

      child({:file_src, 2}, %Source{chunk_size: 40_960, location: "/tmp/input_2.h264"})
      |> child({:parser, 2}, %Parser{framerate: {30, 1}})
      |> child({:decoder, 2}, Decoder)
      |> child({:cutter, 2}, %VideoCutter{intervals: [{Membrane.Time.seconds(5), :infinity}]})
      |> via_in(Pad.ref(:input, 2))
      |> get_child(:merger),
    ]

    {[spec: structure], %{}}
  end
end
```

## Copyright and License

Copyright 2021, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_video_merger_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_video_merger_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
