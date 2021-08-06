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
so every `Buffer` should have the `pts` field in the `metadata` map.

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

The package can be installed by adding `membrane_video_merger_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_video_merger_plugin, "~> 0.1.0"}
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
  def handle_init(_) do
    children = [
      file_src_1: %Source{chunk_size: 40_960, location: "/tmp/input_1.h264"},
      parser_1: %Parser{framerate: {30, 1}},
      decoder_1: Decoder,
      file_src_2: %Source{chunk_size: 40_960, location: "/tmp/input_2.h264"},
      parser_2: %Parser{framerate: {30, 1}},
      decoder_2: Decoder,
      cut_and_merge: VideoCutAndMerge,
      sink: %Sink{location: "/tmp/output.raw"}
    ]

    stream_1 = %VideoCutAndMerge.Stream{intervals: [{0, Membrane.Time.seconds(5)}]}
    stream_2 = %VideoCutAndMerge.Stream{intervals: [{Membrane.Time.seconds(5), :infinity}]}

    links = [
      link(:file_src_1)
      |> to(:parser_1)
      |> to(:decoder_1)
      |> via_in(Pad.ref(:input, 1), options: [stream: stream_1])
      |> to(:cut_and_merge),
      link(:file_src_2)
      |> to(:parser_2)
      |> to(:decoder_2)
      |> via_in(Pad.ref(:input, 2), options: [stream: stream_2])
      |> to(:cut_and_merge),
      link(:cut_and_merge)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
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
  def handle_init(_) do
    children = [
      file_src_1: %Source{chunk_size: 40_960, location: "/tmp/input_1.h264"},
      parser_1: %Parser{framerate: {30, 1}},
      decoder_1: Decoder,
      cutter_1: %VideoCutter{intervals: [{0, Membrane.Time.seconds(5)}]},
      file_src_2: %Source{chunk_size: 40_960, location: "/tmp/input_2.h264"},
      parser_2: %Parser{framerate: {30, 1}},
      decoder_2: Decoder,
      cutter_2: %VideoCutter{intervals: [{Membrane.Time.seconds(5), :infinity}]},
      merger: VideoMerger,
      sink: %Sink{location: "/tmp/output.raw"}
    ]

    links = [
      link(:file_src_1)
      |> to(:parser_1)
      |> to(:decoder_1)
      |> to(:cutter_1)
      |> via_in(Pad.ref(:input, 1))
      |> to(:merger),
      link(:file_src_2)
      |> to(:parser_2)
      |> to(:decoder_2)
      |> to(:cutter_2)
      |> via_in(Pad.ref(:input, 2))
      |> to(:merger),
      link(:merger)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

## Copyright and License

Copyright 2021, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_video_merger_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_video_merger_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
