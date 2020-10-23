defmodule FooStruct do
  defstruct foo: "default"
end

defmodule BarStruct do
  defstruct bar: "default"
end

defmodule ExdnTest do
  use ExUnit.Case
  alias Calendar.DateTime.Parse

  test "char converts irreversibly to Elixir" do
    assert Exdn.to_elixir!("\\a") == "a"
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
    assert Exdn.to_elixir!("(1, (1, \\a))") == {:list, [1, {:list, [1, "a"]}]}
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
    assert Exdn.to_elixir!("[[1 \\a], 1]") == [[1, "a"], 1]
  end

  # Sets
  test "empty set converts to Elixir" do
    assert Exdn.to_elixir!("\#{}") == MapSet.new([])
  end

  test "one-member set converts to Elixir" do
    assert Exdn.to_elixir!("\#{1}") == MapSet.new([1])
  end

  test "two-member set converts to Elixir" do
    assert Exdn.to_elixir!("\#{1 :foo}") == MapSet.new([1, :foo])
  end

  test "nested set converts to Elixir" do
    edn_set = "\#{1 \\a 1 \#{1}}"
    assert Exdn.to_elixir!(edn_set) == MapSet.new([1, "a", MapSet.new([1])])
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
    map2 = "{:foo, \\a, {:bar \\b} [1 2]}"
    assert Exdn.to_elixir!(map2) == %{:foo => "a", %{:bar => "b"} => [1, 2]}
  end

  # Structs
  test "empty map can be converted to Elixir struct" do
    map0 = "{}"

    converter = fn map ->
      case map do
        %{} -> struct(FooStruct, map)
        anything_else -> anything_else
      end
    end

    assert Exdn.to_elixir!(map0, converter) == %FooStruct{}
  end

  test "one-entry map can be converted to Elixir struct" do
    map1 = "{:foo 1}"

    converter = fn map ->
      case map do
        %{} -> struct(FooStruct, map)
        anything_else -> anything_else
      end
    end

    assert Exdn.to_elixir!(map1, converter) == %FooStruct{:foo => 1}
  end

  test "two-entry map can be converted to Elixir struct with loss" do
    map2 = "{:foo 1 :bar 2}"

    converter = fn map ->
      case map do
        %{:foo => _} -> struct(FooStruct, map)
        anything_else -> anything_else
      end
    end

    assert Exdn.to_elixir!(map2, converter) == %FooStruct{:foo => 1}
  end

  test "two-entry map can be made to raise an exception if keys are unrecognized when converting to Elixir struct" do
    map2 = "{:foo 1 :bar 2}"

    converter = fn map ->
      case map do
        %{:foo => _} -> struct!(FooStruct, map)
        anything_else -> anything_else
      end
    end

    assert_raise KeyError, "key :bar not found in: %FooStruct{foo: \"default\"}", fn ->
      Exdn.to_elixir!(map2, converter)
    end
  end

  test "can convert outer map of nested map to Elixir struct" do
    map2 = "{:foo, {:bar \\b}}"

    converter = fn map ->
      case map do
        %{:foo => _} -> struct!(FooStruct, map)
        anything_else -> anything_else
      end
    end

    assert Exdn.to_elixir!(map2, converter) == %FooStruct{:foo => %{:bar => "b"}}
  end

  test "can convert inner map of nested map to Elixir struct" do
    map2 = "{:bar, {:foo \\b}}"

    converter = fn map ->
      case map do
        %{:foo => _} -> struct!(FooStruct, map)
        anything_else -> anything_else
      end
    end

    assert Exdn.to_elixir!(map2, converter) == %{:bar => %FooStruct{:foo => "b"}}
  end

  test "can convert nested maps to Elixir structs" do
    map2 = "{:bar, {:foo \\b}}"

    converter = fn map ->
      case map do
        %{:foo => _} -> struct!(FooStruct, map)
        %{:bar => _} -> struct!(BarStruct, map)
        anything_else -> anything_else
      end
    end

    assert Exdn.to_elixir!(map2, converter) == %BarStruct{:bar => %FooStruct{:foo => "b"}}
  end

  # Tags
  test "tag converts irreversibly to Elixir" do
    tagged = "#inst \"1985-04-12T23:20:50.52Z\""
    timestamp = Parse.rfc3339_utc("1985-04-12T23:20:50.52Z")
    assert Exdn.to_elixir(tagged) == timestamp
  end

  test "unknown tag raises an error when irreversibly converting to Elixir" do
    tagged = "#foo [\"blarg\"]"

    assert_raise RuntimeError,
                 "Handler not found for tag foo with tagged expression [\"blarg\"]",
                 fn ->
                   Exdn.to_elixir!(tagged)
                 end
  end

  test "custom tag can be handled in irreversible conversions by providing a handler" do
    tagged = "#foo \"blarg\""
    identity = & &1
    handler = fn _tag, val, _converter, _handlers -> val <> "-converted" end
    assert Exdn.to_elixir!(tagged, identity, [{:foo, handler}]) == "blarg-converted"
  end

  test "Datomic transaction response can be converted to Elixir" do
    datomic_reply_str =
      "{:db-before {:basis-t 63}, :db-after {:basis-t 63}, :tx-data [{:a 50, :e 13194139534312, :v #inst \"2016-02-10T19:11:51.221-00:00\", :tx 13194139534312, :added true} {:a 41, :e 63, :v 35, :tx 13194139534312, :added true} {:a 62, :e 63, :v \"A person's name\", :tx 13194139534312, :added true} {:a 10, :e 63, :v :person/name, :tx 13194139534312, :added true} {:a 40, :e 63, :v 23, :tx 13194139534312, :added true} {:a 13, :e 0, :v 63, :tx 13194139534312, :added true}], :tempids {-9223367638809264704 63}}\n"

    converted = Exdn.to_elixir!(datomic_reply_str)
    %{:"db-before" => %{:"basis-t" => before_t}} = converted
    assert is_integer(before_t)
    %{:"db-after" => %{:"basis-t" => after_t}} = converted
    assert is_integer(after_t)

    %{:"tx-data" => tx_data} = converted
    assert 6 == Enum.count(tx_data)
    %{e: entity} = hd(tx_data)
    assert is_integer(entity)
    %{a: attribute} = hd(tx_data)
    assert is_integer(attribute)
    %{v: _} = hd(tx_data)
    %{tx: transaction} = hd(tx_data)
    assert is_integer(transaction)
    %{added: added?} = hd(tx_data)
    assert added?

    %{tempids: tempids} = converted
    assert 1 == Enum.count(tempids)
    assert Map.keys(tempids) |> hd |> is_integer
    assert Map.values(tempids) |> hd |> is_integer
  end

  # to_elixir - safe version. We'll test this selectively since it's based on the to_elixir! function
  test "nested map converts safely to Elixir" do
    map2 = "{:foo, \\a, \\b #inst \"1985-04-12T23:20:50.52Z\" }"
    {:ok, timestamp} = Parse.rfc3339_utc("1985-04-12T23:20:50.52Z")
    assert Exdn.to_elixir(map2) == {:ok, %{:foo => "a", "b" => timestamp}}
  end

  test "unknown tag returns :error when safely converting irreversibly to Elixir" do
    map2 = "{:foo, \\a, \\b #foo [\"blarg\"] }"

    assert Exdn.to_elixir(map2) ==
             {:error,
              %RuntimeError{
                :message => "Handler not found for tag foo with tagged expression [\"blarg\"]"
              }}
  end

  # to_reversible
  test "char converts reversibly to Elixir" do
    assert Exdn.to_reversible("\\a") == {:char, ?a}
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
    assert Exdn.to_reversible("(1, (1, \\a))") == {:list, [1, {:list, [1, {:char, ?a}]}]}
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
    assert Exdn.to_reversible("[[1 \\a], 1]") == [[1, {:char, ?a}], 1]
  end

  # Sets
  test "empty set converts reversibly to Elixir" do
    assert Exdn.to_reversible("\#{}") == MapSet.new([])
  end

  test "one-member set converts reversibly to Elixir" do
    assert Exdn.to_reversible("\#{1}") == MapSet.new([1])
  end

  test "two-member set converts reversibly to Elixir" do
    assert Exdn.to_reversible("\#{1 :foo}") == MapSet.new([1, :foo])
  end

  test "nested set converts reversibly to Elixir" do
    edn_set = "\#{1 \\a 1 \#{1}}"
    assert Exdn.to_reversible(edn_set) == MapSet.new([1, {:char, ?a}, MapSet.new([1])])
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
    map2 = "{:foo, \\a, {:bar \\b} [1 2]}"
    assert Exdn.to_reversible(map2) == %{:foo => {:char, ?a}, %{:bar => {:char, ?b}} => [1, 2]}
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

  # from_elixir!
  test "tagged char converts to EDN" do
    assert Exdn.from_elixir!({:char, ?a}) == "\\a"
  end

  test "integer converts to EDN" do
    assert Exdn.from_elixir!(41) == "41"
  end

  test "float converts to EDN" do
    assert Exdn.from_elixir!(41.2) == "41.2"
  end

  test "keyword converts to EDN" do
    assert Exdn.from_elixir!(:foo) == ":foo"
  end

  test "nil converts to EDN" do
    assert Exdn.from_elixir!(nil) == "nil"
  end

  test "tagged symbol converts to EDN" do
    assert Exdn.from_elixir!({:symbol, :foo}) == "foo"
  end

  test "true converts to EDN" do
    assert Exdn.from_elixir!(true) == "true"
  end

  test "false converts to EDN" do
    assert Exdn.from_elixir!(false) == "false"
  end

  test "string converts to EDN" do
    assert Exdn.from_elixir!("asd") == "\"asd\""
  end

  # Lists
  # NOTE: Lists are generally used (in Datomic, at least) as forms and
  # not as data structures. So we keep them distinct even in to_elixir!/1
  test "empty list converts to EDN" do
    assert Exdn.from_elixir!({:list, []}) == "()"
  end

  test "one-member list converts to EDN" do
    assert Exdn.from_elixir!({:list, [1]}) == "(1)"
  end

  test "two-member list converts to EDN" do
    assert Exdn.from_elixir!({:list, [1, :foo]}) == "(1 :foo)"
  end

  test "nested list converts to EDN" do
    assert Exdn.from_elixir!({:list, [1, {:list, [1, {:char, ?a}]}]}) == "(1 (1 \\a))"
  end

  # Vectors
  test "empty vector converts to EDN" do
    assert Exdn.from_elixir!([]) == "[]"
  end

  test "one-member vector converts to EDN" do
    assert Exdn.from_elixir!([1]) == "[1]"
  end

  test "two-member vector converts to EDN" do
    assert Exdn.from_elixir!([1, :foo]) == "[1 :foo]"
  end

  test "nested vector converts to EDN" do
    assert Exdn.from_elixir!([[1, {:char, ?a}], 1]) == "[[1 \\a] 1]"
  end

  # Sets
  test "empty set converts to EDN" do
    assert Exdn.from_elixir!(MapSet.new([])) == "\#{}"
  end

  test "one-member set converts to EDN" do
    assert Exdn.from_elixir!(MapSet.new([1])) == "\#{1}"
  end

  test "two-member set converts to EDN" do
    assert Exdn.from_elixir!(MapSet.new([1, :foo])) == "\#{1 :foo}"
  end

  test "nested set converts to EDN" do
    set_to_convert = MapSet.new([1, {:char, ?a}, MapSet.new([1])])
    assert Exdn.from_elixir!(set_to_convert) == "\#{1 \\a \#{1}}"
  end

  # Maps
  test "empty map converts to EDN" do
    map0 = %{}
    assert Exdn.from_elixir!(map0) == "{}"
  end

  test "one-entry map converts to EDN" do
    map1 = %{1 => :foo}
    assert Exdn.from_elixir!(map1) == "{1 :foo}"
  end

  test "two-entry map converts to EDN" do
    map2 = %{1 => :foo, 2 => :bar}
    assert Exdn.from_elixir!(map2) == "{1 :foo 2 :bar}"
  end

  test "nested map converts to EDN" do
    map2 = %{:foo => {:char, ?a}, %{:bar => {:char, ?b}} => [1, 2]}
    assert Exdn.from_elixir!(map2) == "{:foo \\a {:bar \\b} [1 2]}"
  end

  # Structs
  test "simple struct can be converted to EDN" do
    struct1 = %FooStruct{:foo => 1}
    assert Exdn.from_elixir!(struct1) == "{:foo 1}"
  end

  test "struct with nested map can be converted to EDN" do
    struct2 = %FooStruct{:foo => %{:bar => "b"}}
    assert Exdn.from_elixir!(struct2) == "{:foo {:bar \"b\"}}"
  end

  test "map with nested struct can be converted to EDN" do
    struct2 = %{:bar => %FooStruct{:foo => "b"}}
    assert Exdn.from_elixir!(struct2) == "{:bar {:foo \"b\"}}"
  end

  test "nested structs can be converted to EDN" do
    struct2 = %BarStruct{:bar => %FooStruct{:foo => {:char, ?b}}}
    assert Exdn.from_elixir!(struct2) == "{:bar {:foo \\b}}"
  end

  # Tags
  test "tag converts to EDN" do
    tagged = {:tag, :inst, "1985-04-12T23:20:50.52Z"}
    assert Exdn.from_elixir!(tagged) == "#inst \"1985-04-12T23:20:50.52Z\""
  end

  test "unknown tag converts to EDN" do
    tagged = {:tag, :foo, "blarg"}
    assert Exdn.from_elixir!(tagged) == "#foo \"blarg\""
  end

  # from_elixir - safe version. We'll test this selectively since it's based on the from_elixir! function
  test "nested map converts safely to EDN" do
    map2 = %{:foo => {:char, ?a}, {:char, ?b} => {:tag, :inst, "1985-04-12T23:20:50.52Z"}}

    assert Exdn.from_elixir(map2) == {:ok, "{:foo \\a \\b #inst \"1985-04-12T23:20:50.52Z\"}"}
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
    identity = & &1
    handler = fn _tag, val, _converter, _handlers -> val <> "-converted" end
    assert Exdn.evaluate_tagged_expr(tagged, identity, [{:foo, handler}]) == "blarg-converted"
  end
end
