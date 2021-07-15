defmodule Membrane.VideoMerger.BufferQueueTest do
  use ExUnit.Case, async: true

  alias Membrane.Buffer
  alias Membrane.VideoMerger.BufferQueue

  defp buffer(pts), do: %Buffer{metadata: %{pts: pts}, payload: nil}

  test "empty queue" do
    queue = BufferQueue.new()
    assert queue == %{}
    assert BufferQueue.get_empty_ids(queue) == []
    assert BufferQueue.dequeue_buffers(queue) == {:ok, :end_of_stream}
  end

  test "end of stream" do
    queue = BufferQueue.enqueue_eos(BufferQueue.new(), :id)
    assert queue != BufferQueue.new()
    assert BufferQueue.get_empty_ids(queue) == []
    assert BufferQueue.dequeue_buffers(queue) == {:ok, :end_of_stream}
  end

  test "end of stream with buffers" do
    queue = BufferQueue.enqueue_eos(%{1 => [buffer(1)]}, 1)
    assert BufferQueue.dequeue_buffers(queue) == {{:ok, buffers: [buffer(1)]}, :end_of_stream}
  end

  test "empty ids" do
    assert BufferQueue.get_empty_ids(%{1 => [], 2 => []}) == [1, 2]
    assert BufferQueue.get_empty_ids(%{1 => [1], 2 => []}) == [2]
    assert BufferQueue.get_empty_ids(%{1 => [], 2 => [2]}) == [1]
    assert BufferQueue.get_empty_ids(%{1 => [1], 2 => [2]}) == []
  end

  test "three queues" do
    queue = %{1 => [], 2 => [], 3 => []}
    assert BufferQueue.get_empty_ids(queue) === [1, 2, 3]

    {{:ok, buffers: buffers}, queue} =
      queue
      |> BufferQueue.enqueue_list(1, [buffer(1), buffer(5)])
      |> BufferQueue.enqueue_list(2, [buffer(3)])
      |> BufferQueue.enqueue_list(3, [buffer(2), buffer(4)])
      |> BufferQueue.dequeue_buffers()

    assert buffers == [buffer(1), buffer(2), buffer(3)]
    assert BufferQueue.get_empty_ids(queue) === [2]

    {{:ok, buffers: buffers}, queue} =
      queue
      |> BufferQueue.enqueue_eos(2)
      |> BufferQueue.enqueue_eos(3)
      |> BufferQueue.dequeue_buffers()

    assert buffers == [buffer(4), buffer(5)]
    assert BufferQueue.get_empty_ids(queue) == [1]

    assert {:ok, :end_of_stream} =
             queue
             |> BufferQueue.enqueue_eos(1)
             |> BufferQueue.dequeue_buffers()
  end
end
