defmodule CB.Belief.MaterializerTest do
  # async: false — these tests override the :cb beliefs_path app env.
  use ExUnit.Case, async: false

  alias CB.Belief
  alias CB.Belief.{Materializer, Store}

  # An in-memory sink that records what it was handed and returns refs,
  # exercising the pluggable-sink seam without touching disk.
  defmodule EchoSink do
    @behaviour CB.Materializer.Sink

    @impl true
    def persist(implication, action_items, opts) do
      send(self(), {:echo, implication.id, action_items, opts})

      refs =
        action_items
        |> Enum.with_index(1)
        |> Enum.map(fn {item, i} -> %{"action" => item["action"], "id" => "echo-#{i}"} end)

      {:ok, refs}
    end
  end

  defmodule FailingSink do
    @behaviour CB.Materializer.Sink
    @impl true
    def persist(_implication, _action_items, _opts), do: {:error, :boom}
  end

  setup do
    dir = System.tmp_dir!()
    tag = :rand.uniform(999_999)
    beliefs = Path.join(dir, "cb-mat-beliefs-#{tag}.json")
    todos = Path.join(dir, "cb-mat-todos-#{tag}.json")

    nodes = [
      %{
        "id" => "a020",
        "type" => "directive",
        "kind" => "rule",
        "domain" => "ops",
        "tags" => ["hold-queue"],
        "claim" => "When a hold expires the item returns to available",
        "deps" => ["a001"],
        "materialized" => nil,
        "status" => "active",
        "created" => "2024-09-15"
      },
      %{
        "id" => "a001",
        "type" => "primitive",
        "kind" => "rule",
        "domain" => "ops",
        "claim" => "Loan period is 21 days",
        "artifact" => "document:policy.md",
        "status" => "active",
        "created" => "2024-09-01"
      }
    ]

    File.write!(beliefs, Jason.encode!(nodes, pretty: true))
    prev = Application.get_env(:cb, :beliefs_path)
    Application.put_env(:cb, :beliefs_path, beliefs)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:cb, :beliefs_path, prev),
        else: Application.delete_env(:cb, :beliefs_path)

      File.rm(beliefs)
      File.rm(todos)
    end)

    %{todos: todos}
  end

  test "materialize routes action items through a pluggable sink and links the belief" do
    spec = %{
      "belief_id" => "a020",
      "action_items" => [
        %{"action" => "Notify next member in queue"},
        %{"action" => "Flip item to available"}
      ]
    }

    assert {:ok, %{belief_id: "a020", entries: entries}} =
             Materializer.materialize(spec, sink: EchoSink)

    # Sink received the directive belief + action items.
    assert_received {:echo, "a020", [%{"action" => "Notify next member in queue"} | _], _opts}

    assert entries == [
             %{"action" => "Notify next member in queue", "id" => "echo-1"},
             %{"action" => "Flip item to available", "id" => "echo-2"}
           ]

    # The belief is now linked to its materialized artifacts.
    {:ok, all} = Store.read()
    node = Enum.find(all, &(&1.id == "a020"))
    assert %{"todos" => ^entries} = node.materialized
  end

  test "default JSON sink appends generic todo records", %{todos: todos} do
    spec = %{
      "belief_id" => "a020",
      "action_items" => [%{"action" => "Notify next member in queue"}]
    }

    assert {:ok, _} = Materializer.materialize(spec, path: todos, today: "2026-06-03")

    written = Jason.decode!(File.read!(todos))
    assert [record] = written
    assert record["action"] == "Notify next member in queue"
    assert record["source"] == "a020"
    assert record["status"] == "open"
    assert record["created"] == "2026-06-03"
    assert String.match?(record["id"], ~r/^t\d+$/)
  end

  test "refuses to materialize a non-directive" do
    spec = %{"belief_id" => "a001", "action_items" => [%{"action" => "x"}]}

    assert {:error, {:not_directive, "primitive"}} =
             Materializer.materialize(spec, sink: EchoSink)
  end

  test "refuses to materialize twice" do
    spec = %{"belief_id" => "a020", "action_items" => [%{"action" => "x"}]}
    assert {:ok, _} = Materializer.materialize(spec, sink: EchoSink)
    assert {:error, :already_materialized} = Materializer.materialize(spec, sink: EchoSink)
  end

  test "missing belief id is rejected" do
    assert {:error, :missing_belief_id} =
             Materializer.materialize(%{"action_items" => [%{"action" => "x"}]}, sink: EchoSink)
  end

  test "empty action items are rejected" do
    assert {:error, :no_action_items} =
             Materializer.materialize(%{"belief_id" => "a020", "action_items" => []},
               sink: EchoSink
             )
  end

  test "sink failure surfaces and the belief is not linked" do
    spec = %{"belief_id" => "a020", "action_items" => [%{"action" => "x"}]}
    assert {:error, {:sink_failed, :boom}} = Materializer.materialize(spec, sink: FailingSink)

    {:ok, all} = Store.read()
    node = Enum.find(all, &(&1.id == "a020"))
    assert node.materialized == nil
  end

  test "unknown belief id is rejected" do
    spec = %{"belief_id" => "zzz999", "action_items" => [%{"action" => "x"}]}
    assert {:error, {:node_not_found, "zzz999"}} = Materializer.materialize(spec, sink: EchoSink)
  end

  # Sanity: the Belief alias is used so the module compiles cleanly even
  # if future edits reference it directly.
  test "directive belief shape" do
    assert %Belief{type: "directive"} = Belief.from_map(%{"id" => "x", "type" => "directive"})
  end
end
