defmodule ExdnTest do
  use ExUnit.Case
  doctest Exdn

  test "char converts irreversibly to Elixir" do
    assert Exdn.to_elixir!( "\\a" ) == "a"
  end

  test "integer converts to Elixir" do
    assert Exdn.to_elixir!("41") == 41
  end

  test "float converts to Elixir" do
    assert Exdn.to_elixir!("41.2") == 41.2
  end

  test "keyword converts to Elixir" do
    assert Exdn.to_elixir!(":foo") == :foo
  end

  test "nil converts to Elixir" do
    assert Exdn.to_elixir!("nil") == nil
  end

  test "nil keyword converts to Elixir" do
    assert Exdn.to_elixir!(":nil") == nil
  end

  test "symbol converts to Elixir" do
   assert Exdn.to_elixir!("foo") == {:symbol, :foo}
  end

  test "true converts to Elixir" do
    assert Exdn.to_elixir!("true") == true
  end

  test "false converts to Elixir" do
    assert Exdn.to_elixir!("false") == false
  end

  test "string converts to Elixir" do
    assert Exdn.to_elixir!("\"asd\"") == "asd"
  end

  # Lists
  # NOTE: Lists are generally used (in Datomic, at least) as forms and
  # not as data structures. So we keep them distinct even in to_elixir!/1
  test "empty list converts to Elixir" do
    assert Exdn.to_elixir!("()") == {:list, []}
  end

  test "one-member list converts to Elixir" do
    assert Exdn.to_elixir!("(1)") == {:list, [1]}
  end

  test "two-member list converts to Elixir" do
    assert Exdn.to_elixir!("(1, :foo)") == {:list, [1, :foo]}
  end

  test "nested list converts to Elixir" do
    assert Exdn.to_elixir!("(1, \\a)") == {:list, [1, "a"]}
  end


  # Vectors
  test "empty vector converts to Elixir" do
    assert Exdn.to_elixir!("[]") == []
  end

  test "one-member vector converts to Elixir" do
    assert Exdn.to_elixir!("[1]") == [1]
  end

  test "two-member vector converts to Elixir" do
    assert Exdn.to_elixir!("[1 :foo]") == [1, :foo]
  end

  test "nested vector converts to Elixir" do
    assert Exdn.to_elixir!("[1 \\a]") == [1, "a"]
  end


  # Sets
  test "empty set converts to Elixir" do
    assert Exdn.to_elixir!( "\#{}" ) == MapSet.new([])
  end

  test "one-member set converts to Elixir" do
    assert Exdn.to_elixir!( "\#{1}" ) == MapSet.new([1])
  end

  test "two-member set converts to Elixir" do
    assert Exdn.to_elixir!( "\#{1 :foo}" ) == MapSet.new([1, :foo])
  end

  test "nested set converts to Elixir" do
    edn_set = "\#{1 \\a 1}"
    assert Exdn.to_elixir!(edn_set) == MapSet.new([1, "a"])
  end


  # Maps
  test "empty map converts to Elixir" do
    map0 = "{}"
    assert Exdn.to_elixir!(map0) == %{}
  end

  test "one-entry map converts to Elixir" do
    map1 = "{1 :foo}"
    assert Exdn.to_elixir!(map1) == %{1 => :foo}
  end

  test "two-entry map converts to Elixir" do
    map2 = "{1 :foo, 2 :bar}"
    assert Exdn.to_elixir!(map2) == %{1 => :foo, 2 => :bar}
  end

  test "nested map converts to Elixir" do
    map2 = "{:foo, \\a, \\b 2 }"
    assert Exdn.to_elixir!(map2) == %{:foo => "a", "b" => 2}
  end


  # Tags
  test "tag converts irreversibly to Elixir" do
    tagged = "#inst \"1985-04-12T23:20:50.52Z\""
    timestamp = Calendar.DateTime.Parse.rfc3339_utc("1985-04-12T23:20:50.52Z")
    assert Exdn.to_elixir(tagged) == timestamp
  end

  test "unknown tag raises an error when irreversibly converting to Elixir" do
    tagged = "#foo \"blarg\""
    assert_raise RuntimeError, "Handler not found for tag foo with tagged expression blarg", fn ->
      Exdn.to_elixir!(tagged)
    end
  end

  test "custom tag can be handled in irreversible conversions by providing a handler" do
    tagged = "#foo \"blarg\""
    handler = fn(_tag, val, _handlers) -> val <> "-converted" end
    assert Exdn.to_elixir!(tagged, [{:foo, handler}]) == "blarg-converted"
  end

  # to_elixir - safe version. We'll test this selectively since it's based on to_elixir!
  test "nested map converts safely to Elixir" do
    map2 = "{:foo, \\a, \\b #inst \"1985-04-12T23:20:50.52Z\" }"
    {:ok, timestamp} = Calendar.DateTime.Parse.rfc3339_utc("1985-04-12T23:20:50.52Z")
    assert Exdn.to_elixir(map2) == {:ok, %{:foo => "a", "b" => timestamp}}
  end

  test "unknown tag returns :error when irreversibly converting to Elixir" do
    map2 = "{:foo, \\a, \\b #foo \"blarg\" }"
    assert Exdn.to_elixir(map2) == {:error, %RuntimeError{:message => "Handler not found for tag foo with tagged expression blarg"}}
  end

  # to_reversible
  test "char converts reversibly to Elixir" do
    assert Exdn.to_reversible( "\\a" ) == {:char, ?a}
  end

  test "integer converts reversibly to Elixir" do
    assert Exdn.to_reversible("41") == 41
  end

  test "float converts reversibly to Elixir" do
    assert Exdn.to_reversible("41.2") == 41.2
  end

  test "keyword converts reversibly to Elixir" do
    assert Exdn.to_reversible(":foo") == :foo
  end

  test "nil converts reversibly to Elixir" do
    assert Exdn.to_reversible("nil") == nil
  end

  test "nil keyword converts reversibly to Elixir" do
    assert Exdn.to_reversible(":nil") == nil
  end

  test "symbol converts reversibly to Elixir" do
   assert Exdn.to_reversible("foo") == {:symbol, :foo}
  end

  test "true converts reversibly to Elixir" do
    assert Exdn.to_reversible("true") == true
  end

  test "false converts reversibly to Elixir" do
    assert Exdn.to_reversible("false") == false
  end

  test "string converts reversibly to Elixir" do
    assert Exdn.to_reversible("\"asd\"") == "asd"
  end

  # Lists
  # NOTE: Lists are generally used (in Datomic, at least) as forms and
  # not as data structures. So we keep them distinct even in to_elixir!/1
  test "empty list converts reversibly to Elixir" do
    assert Exdn.to_reversible("()") == {:list, []}
  end

  test "one-member list converts reversibly to Elixir" do
    assert Exdn.to_reversible("(1)") == {:list, [1]}
  end

  test "two-member list converts reversibly to Elixir" do
    assert Exdn.to_reversible("(1, :foo)") == {:list, [1, :foo]}
  end

  test "nested list converts reversibly to Elixir" do
    assert Exdn.to_reversible("(1, \\a)") == {:list, [1, {:char, ?a}]}
  end


  # Vectors
  test "empty vector converts reversibly to Elixir" do
    assert Exdn.to_reversible("[]") == []
  end

  test "one-member vector converts reversibly to Elixir" do
    assert Exdn.to_reversible("[1]") == [1]
  end

  test "two-member vector converts reversibly to Elixir" do
    assert Exdn.to_reversible("[1 :foo]") == [1, :foo]
  end

  test "nested vector converts reversibly to Elixir" do
    assert Exdn.to_reversible("[1 \\a]") == [1, { :char, ?a}]
  end


  # Sets
  test "empty set converts reversibly to Elixir" do
    assert Exdn.to_reversible( "\#{}" ) == MapSet.new([])
  end

  test "one-member set converts reversibly to Elixir" do
    assert Exdn.to_reversible( "\#{1}" ) == MapSet.new([1])
  end

  test "two-member set converts reversibly to Elixir" do
    assert Exdn.to_reversible( "\#{1 :foo}" ) == MapSet.new([1, :foo])
  end

  test "nested set converts reversibly to Elixir" do
    edn_set = "\#{1 \\a 1}"
    assert Exdn.to_reversible(edn_set) == MapSet.new([1, {:char, ?a}])
  end


  # Maps
  test "empty map converts reversibly to Elixir" do
    map0 = "{}"
    assert Exdn.to_reversible(map0) == %{}
  end

  test "one-entry map converts reversibly to Elixir" do
    map1 = "{1 :foo}"
    assert Exdn.to_reversible(map1) == %{1 => :foo}
  end

  test "two-entry map converts reversibly to Elixir" do
    map2 = "{1 :foo, 2 :bar}"
    assert Exdn.to_reversible(map2) == %{1 => :foo, 2 => :bar}
  end

  test "nested map converts reversibly to Elixir" do
    map2 = "{:foo, \\a, \\b 2 }"
    assert Exdn.to_reversible(map2) == %{:foo => {:char, ?a}, {:char, ?b} => 2}
  end


  # Tags
  test "tag converts reversibly to Elixir" do
    tagged = "#inst \"1985-04-12T23:20:50.52Z\""
    assert Exdn.to_reversible(tagged) == {:tag, :inst, "1985-04-12T23:20:50.52Z"}
  end

  test "unknown tag raises no error when reversibly converting to Elixir" do
    tagged = "#foo \"blarg\""
    assert Exdn.to_reversible(tagged) == {:tag, :foo, "blarg"}
  end


  # ad-hoc converters
  test "expression tagged with :list can be converted to list" do
    assert Exdn.tagged_list_to_list({:list, [:foo]}) == [:foo]
  end

  test "expression tagged with :char can be converted to char" do
    assert Exdn.tagged_char_to_string({:char, ?a}) == "a"
  end

  test "expression tagged with :tag can be converted using a handler" do
    tagged = {:tag, :foo, "blarg"}
    handler = fn(_tag, val, _handlers) -> val <> "-converted" end
    assert Exdn.evaluate_tagged_expr(tagged, [{:foo, handler}]) == "blarg-converted"
  end
end