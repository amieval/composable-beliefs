defmodule CB.CollectionTest do
  use ExUnit.Case, async: true

  alias CB.Collection
  alias CB.Collection.Registry

  # Build a registry + collections under `dir`:
  #   collections.json  (namespace -> relative beliefs.json)
  #   <ns>/manifest.json (namespace, schema_version, depends_on)
  #   <ns>/beliefs.json  (array of belief maps)
  defp fixture(dir, collections) do
    registry = %{
      "collections" => Map.new(collections, fn {ns, _spec} -> {ns, "#{ns}/beliefs.json"} end)
    }

    File.write!(Path.join(dir, "collections.json"), Jason.encode!(registry))

    for {ns, spec} <- collections do
      ns_dir = Path.join(dir, ns)
      File.mkdir_p!(ns_dir)
      File.write!(Path.join(ns_dir, "beliefs.json"), Jason.encode!(spec.beliefs))

      manifest = %{"namespace" => ns, "schema_version" => spec[:schema_version] || 2}

      manifest =
        if deps = spec[:depends_on], do: Map.put(manifest, "depends_on", deps), else: manifest

      unless spec[:no_manifest],
        do: File.write!(Path.join(ns_dir, "manifest.json"), Jason.encode!(manifest))
    end

    Path.join(dir, "collections.json")
  end

  defp belief(id), do: %{"id" => id, "type" => "primitive", "status" => "active"}

  describe "registry/1" do
    @tag :tmp_dir
    test "loads a valid registry", %{tmp_dir: dir} do
      path = fixture(dir, %{"a" => %{beliefs: [belief("a:1")]}})

      assert {:ok, %Registry{collections: %{"a" => "a/beliefs.json"}, dir: ^dir}} =
               Collection.registry(path)
    end

    @tag :tmp_dir
    test "errors when the file has no collections map", %{tmp_dir: dir} do
      path = Path.join(dir, "bad.json")
      File.write!(path, Jason.encode!(%{"nope" => 1}))

      assert {:error, {:bad_registry, _}} = Collection.registry(path)
    end

    @tag :tmp_dir
    test "errors when the file is unreadable", %{tmp_dir: dir} do
      assert {:error, {:registry_unreadable, _, _}} =
               Collection.registry(Path.join(dir, "missing.json"))
    end
  end

  describe "closure/2" do
    @tag :tmp_dir
    test "is target-first and transitive", %{tmp_dir: dir} do
      path =
        fixture(dir, %{
          "a" => %{beliefs: [belief("a:1")], depends_on: ["b"]},
          "b" => %{beliefs: [belief("b:1")], depends_on: ["c"]},
          "c" => %{beliefs: [belief("c:1")]}
        })

      {:ok, reg} = Collection.registry(path)
      assert {:ok, ["a", "b", "c"]} = Collection.closure("a", reg)
    end

    @tag :tmp_dir
    test "is cycle-safe for mutually-dependent collections", %{tmp_dir: dir} do
      path =
        fixture(dir, %{
          "a" => %{beliefs: [belief("a:1")], depends_on: ["b"]},
          "b" => %{beliefs: [belief("b:1")], depends_on: ["a"]}
        })

      {:ok, reg} = Collection.registry(path)
      assert {:ok, ["a", "b"]} = Collection.closure("a", reg)
    end

    @tag :tmp_dir
    test "treats a collection with no manifest as a leaf", %{tmp_dir: dir} do
      path = fixture(dir, %{"a" => %{beliefs: [belief("a:1")]}})
      {:ok, reg} = Collection.registry(path)
      assert {:ok, ["a"]} = Collection.closure("a", reg)
    end

    @tag :tmp_dir
    test "errors on an unknown target", %{tmp_dir: dir} do
      path = fixture(dir, %{"a" => %{beliefs: [belief("a:1")]}})
      {:ok, reg} = Collection.registry(path)
      assert {:error, {:unknown_namespace, "ghost"}} = Collection.closure("ghost", reg)
    end

    @tag :tmp_dir
    test "errors when a declared dependency is missing from the registry", %{tmp_dir: dir} do
      path = fixture(dir, %{"a" => %{beliefs: [belief("a:1")], depends_on: ["gone"]}})
      {:ok, reg} = Collection.registry(path)
      assert {:error, {:unknown_namespace, "gone"}} = Collection.closure("a", reg)
    end
  end

  describe "load_union/2" do
    @tag :tmp_dir
    test "returns the closure order, per-collection beliefs, and a flat union", %{tmp_dir: dir} do
      path =
        fixture(dir, %{
          "a" => %{beliefs: [belief("a:1"), belief("a:2")], depends_on: ["b"]},
          "b" => %{beliefs: [belief("b:1")]}
        })

      {:ok, reg} = Collection.registry(path)
      assert {:ok, result} = Collection.load_union("a", reg)

      assert result.target == "a"
      assert result.namespaces == ["a", "b"]
      assert [{"a", a_beliefs}, {"b", b_beliefs}] = result.collections
      assert Enum.map(a_beliefs, & &1.id) == ["a:1", "a:2"]
      assert Enum.map(b_beliefs, & &1.id) == ["b:1"]
      assert Enum.map(result.union, & &1.id) == ["a:1", "a:2", "b:1"]
    end

    @tag :tmp_dir
    test "accepts a registry path directly", %{tmp_dir: dir} do
      path = fixture(dir, %{"a" => %{beliefs: [belief("a:1")]}})
      assert {:ok, %{union: [%{id: "a:1"}]}} = Collection.load_union("a", path)
    end

    @tag :tmp_dir
    test "errors when a collection file is not a JSON array", %{tmp_dir: dir} do
      path = fixture(dir, %{"a" => %{beliefs: [belief("a:1")]}})
      File.write!(Path.join(dir, "a/beliefs.json"), Jason.encode!(%{"not" => "an array"}))
      {:ok, reg} = Collection.registry(path)
      assert {:error, {:not_an_array, "a", _}} = Collection.load_union("a", reg)
    end
  end

  describe "namespaces/1" do
    @tag :tmp_dir
    test "lists registry namespaces sorted", %{tmp_dir: dir} do
      path =
        fixture(dir, %{
          "zeta" => %{beliefs: []},
          "alpha" => %{beliefs: []}
        })

      {:ok, reg} = Collection.registry(path)
      assert Collection.namespaces(reg) == ["alpha", "zeta"]
    end
  end
end
