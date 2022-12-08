defmodule Membrane.VideoCutAndMerge do
  @moduledoc """
  Membrane Bin that cuts and merges multiple raw videos into one.

  The bin expects each frame to be received in a separate buffer, so the parser
  (`Membrane.Element.RawVideo.Parser`) may be required in a pipeline before
  the merger bin (e.g. when input is read from `Membrane.File.Source`).

  The element expects to receive frames in order from each input.

  The bin consists of single `Membrane.VideoMerger` and multiple
  `Membrane.VideoCutter`. Number of elements is constant: cutters are
  created at initialization, one for each stream.
  """

  use Membrane.Bin

  alias __MODULE__.Stream
  alias Membrane.{Pad, ParentSpec, RawVideo, VideoCutter, VideoMerger}

  def_input_pad :input,
    accepted_format: %RawVideo{aligned: true},
    demand_unit: :buffers,
    availability: :on_request,
    options: [
      stream: [
        spec: Stream.t(),
        description: "A stream to cut and merge"
      ]
    ]

  def_output_pad :output,
    accepted_format: %RawVideo{aligned: true},
    demand_unit: :buffers

  defmodule Stream do
    @moduledoc """
    Structure describing video stream to merge by `Membrane.VideoCutAndMerge`

    ## Fields
      - `:intervals` - List of intervals of timestamps that are supposed to be
      cut and kept from the stream.
      - `:offset` - Offset applied to all franes' presentation timestamp values.
    """
    alias Membrane.{Pad, Time}

    @enforce_keys [:intervals]
    defstruct @enforce_keys ++ [offset: 0]

    @type t :: %__MODULE__{
            intervals: [{Time.t(), Time.t() | :infinity}],
            offset: Time.t()
          }
  end

  @impl true
  def handle_init(_opts) do
    children = [{:merger, VideoMerger}]
    links = [link(:merger) |> to_bin_output]
    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, nil}
  end

  @impl true
  def handle_pad_added({_pad, :input, id} = pad_ref, ctx, state) do
    stream = ctx.pads[pad_ref].options.stream
    cutter = {id, %VideoCutter{intervals: stream.intervals, offset: stream.offset}}

    link =
      link_bin_input(Pad.ref(:input, id))
      |> to(id)
      |> via_in(Pad.ref(:input, id))
      |> to(:merger)

    {{:ok, spec: %ParentSpec{children: [cutter], links: [link]}}, state}
  end
end
