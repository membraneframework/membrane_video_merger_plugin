defmodule Membrane.VideoMerger.BufferQueue do
  @moduledoc false

  alias Membrane.{Buffer, Pad}

  @type k :: Pad.dynamic_id_t()
  @type v :: Buffer.t()
  @type t :: map

  @eos %Buffer{metadata: %{pts: -1}, payload: :end_of_stream}

  @doc """
  Creates an empty queue.
  """
  @spec new() :: t
  def new(), do: %{}

  @doc """
  Returns list of ids with empty queues.
  """
  @spec get_empty_ids(t) :: [k]
  def get_empty_ids(state) do
    state
    |> Enum.filter(fn {_id, buffers} -> buffers == [] end)
    |> Enum.map(fn {id, _val} -> id end)
  end

  @doc """
  Enqueues list of buffers to queue of given id.
  """
  @spec enqueue_list(t, k, [v]) :: t
  def enqueue_list(queue, id, buffers), do: Map.update(queue, id, [buffers], &(&1 ++ buffers))

  @doc """
  Enqueues end of stream buffer to queue of given id.

  End of stream buffer will be last buffer in queue of given id: when end of
  stream buffer of id `eos_id` will be dequeued, the `eos_id` queue will be
  removed from `BufferQueue`.
  """
  @spec enqueue_eos(t, k) :: t
  def enqueue_eos(queue, id), do: Map.update(queue, id, [@eos], &(&1 ++ [@eos]))

  @doc """
  Dequeues and (maybe) returns list of buffers with lowest values.

  If the dequeued buffers are the very last ones, end of stream atom will be
  returned insted of queue.

  A buffer can be dequeued if and only if all of queues have at least one
  buffer.
  """
  @spec dequeue_buffers(t, [v]) ::
          {:ok | {:ok, buffers: [v]}, t | :end_of_stream}
  def dequeue_buffers(queue, curr \\ [])

  def dequeue_buffers(queue, []) when queue == %{}, do: {:ok, :end_of_stream}

  def dequeue_buffers(queue, curr) when queue == %{} do
    {{:ok, buffers: Enum.reverse(curr)}, :end_of_stream}
  end

  def dequeue_buffers(queue, curr) do
    if Enum.any?(queue, fn {_id, buffers} -> buffers == [] end) do
      if curr == [], do: {:ok, queue}, else: {{:ok, buffers: Enum.reverse(curr)}, queue}
    else
      {id, [buffer | _rest]} =
        Enum.min_by(queue, fn {_id, [x | _rest]} -> x.metadata.pts end, &Ratio.lte?/2)

      if buffer == @eos do
        new_state = Map.delete(queue, id)
        dequeue_buffers(new_state, curr)
      else
        new_state = Map.update!(queue, id, &tl/1)
        dequeue_buffers(new_state, [buffer | curr])
      end
    end
  end
end
