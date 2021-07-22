defmodule Membrane.VideoMergerBin do
  @moduledoc """
  Membrane Bin that cuts and merges multiple raw videos into one.

  The bin expects each frame to be received in a separate buffer, so the parser
  (`Membrane.Element.RawVideo.Parser`) may be required in a pipeline before
  the merger bin (e.g. when input is read from `Membrane.File.Source`).

  The element expects to receive frames in order from each input.

  The bin consists of `Membrane.VideoMerger` and mutliple `Membrane.VideoCutter`.
  Number of elements is constant: cutters are created at initialization,
  one for each stream.

  Please note that `:id` of a the stream passed in options should be the same as
  dynamic `input` pad id to which stream is connected.
  """
  use Membrane.Bin
  alias __MODULE__.Stream
  alias Membrane.Caps.Video.Raw
  alias Membrane.{Pad, ParentSpec, VideoCutter, VideoMerger}

  def_options streams: [
                spec: [Stream.t()],
                default: [],
                describtion: "List of streams to merge"
              ]

  def_input_pad :input,
    caps: {Raw, aligned: true},
    demand_unit: :buffers,
    availability: :on_request

  def_output_pad :output,
    caps: {Raw, aligned: true},
    demand_unit: :buffers

  defmodule Stream do
    @moduledoc """
    Structure describing video stream to merge by `Membrane.VideoMergerBin`

    ## Fields
      - `:id` - ID of stream. Must be unique and implement `String.Char` protocol.
      - `:intervals` - List of intervals of timestamps that are supposed to be
      cut and kept from the stream.
      - `:offset` - Offset aplied to all franes' presentation timestamp values.
    """
    alias Membrane.{Pad, Time}

    @enforce_keys [:id, :intervals]
    defstruct @enforce_keys ++ [offset: 0]

    @type t :: %__MODULE__{
            id: String.Chars.t(),
            intervals: [{Time.t(), Time.t() | :infinity}],
            offset: Time.t()
          }
  end

  @impl true
  def handle_init(%{streams: streams}) do
    cutters =
      List.foldl(streams, [], fn stream = %Stream{id: id}, elems ->
        cutter = {cutter_id(id), %VideoCutter{intervals: stream.intervals, offset: stream.offset}}

        [cutter | elems]
      end)

    ids = streams |> Enum.map(fn stream -> stream.id end) |> MapSet.new()
    merger = {:merger, VideoMerger}
    output_link = link(:merger) |> to_bin_output
    spec = %ParentSpec{children: [merger | cutters], links: [output_link]}

    {{:ok, spec: spec}, ids}
  end

  @impl true
  def handle_pad_added({_pad, :input, id}, _ctx, ids) do
    if id in ids do
      link =
        link_bin_input(Pad.ref(:input, id))
        |> to(cutter_id(id))
        |> via_in(Pad.ref(:input, id))
        |> to(:merger)

      new_ids = MapSet.delete(ids, id)
      {{:ok, spec: %ParentSpec{links: [link]}}, new_ids}
    else
      raise "Unknown pad id #{id}"
    end
  end

  defp cutter_id(id), do: String.to_atom("cutter_#{id}")
end
