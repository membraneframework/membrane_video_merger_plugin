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
  alias Membrane.{Pad, RawVideo, VideoCutter, VideoMerger}

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
  def handle_init(_ctx, _opts) do
    structure = child(:merger, VideoMerger) |> bin_output

    {[spec: structure], nil}
  end

  # TODO: Remove this when we have fix in Membrane Core
  @dialyzer {:nowarn_function, {:handle_pad_added, 3}}
  @impl true
  def handle_pad_added(Pad.ref(:input, id) = pad_ref, ctx, state) do
    stream = ctx.pads[pad_ref].options.stream

    structure = [
      bin_input(pad_ref)
      |> child({:cutter, id}, %VideoCutter{intervals: stream.intervals, offset: stream.offset})
      |> via_in(pad_ref)
      |> get_child(:merger)
    ]

    {[spec: structure], state}
  end
end
