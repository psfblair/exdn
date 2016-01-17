defmodule Exdn do

  # to_elixir and to_elixir!
  #
  # edn	               elixir
  # ---                ---
  # integer	           integer
  # float	             float
  # boolean	           boolean
  # nil	               nil (atom)
  # char               string
  # char               string
  # string	           string
  # list	             tagged list {:list, [...]}
  # vector	           list
  # map	               map
  # set	               mapset
  # symbol	           tagged atom {:symbol, atom}
  # tagged elements	   call registered handler for that tag, fail if not found

  def to_elixir(val, handlers \\ standard_handlers) do
    try do
      {:ok, to_elixir!(val, handlers)}
    rescue
      e -> {:error, e}
    end
  end

  def to_elixir!(edn, handlers \\ standard_handlers) do
    erlang_str = edn |> to_char_list
    {:ok, erlang_intermediate } = :erldn.parse_str(erlang_str)
    elrldn_to_elixir!(erlang_intermediate, handlers)
  end

  defp elrldn_to_elixir!( {:char, char},   _handlers ), do: to_string([char])
  defp elrldn_to_elixir!( {:keyword, nil}, _handlers ), do: nil

  defp elrldn_to_elixir!( {:tag, tag, val}, handlers )  do
    evaluate_tagged_expr({:tag, tag, val}, handlers)
  end

  defp elrldn_to_elixir!( {:vector, items}, handlers )  do
    Enum.map(items, fn(item) -> elrldn_to_elixir!(item, handlers) end)
  end

  defp elrldn_to_elixir!( {:set, items},    handlers )  do
    convert_set(items, fn(x) -> elrldn_to_elixir!(x, handlers) end)
  end

  defp elrldn_to_elixir!( {:map, pairs},    handlers )  do
    convert_map(pairs, fn(x) -> elrldn_to_elixir!(x, handlers) end)
  end

  defp elrldn_to_elixir!( items,            handlers) when is_list(items) do
    {:list, Enum.map(items, fn(item) -> elrldn_to_elixir!(item, handlers) end)}
  end

  defp elrldn_to_elixir!(val, _handlers), do: val

  # to_reversible
  #
  # edn	               reversible representation
  # ---                ---
  # integer	           integer
  # float	             float
  # boolean	           boolean
  # nil	               nil (atom)
  # char               tagged integer -> {:char, <integer>}
  # string	           binary string (utf-8)
  # list	             tagged list {:list, [...]}
  # vector	           list
  # map	               map
  # set	               mapset
  # symbol	           tagged atom {:symbol, atom}
  # tagged elements	   tagged tuple with tag and value -> {:tag, Symbol, Value}
  def to_reversible(edn) do
    erlang_str = edn |> to_char_list
    {:ok, erlang_intermediate } = :erldn.parse_str(erlang_str)
    reversible(erlang_intermediate)
  end

  defp reversible({:char, char}), do: {:char, char}
  defp reversible({:keyword, nil}), do: nil
  defp reversible({:tag, tag, val}), do: {:tag, tag, val}
  defp reversible({:vector, items}), do: Enum.map(items, fn(item) -> reversible(item) end)
  defp reversible({:set, items}), do: convert_set(items, fn(x) -> reversible(x) end)
  defp reversible({:map, pairs}), do: convert_map(pairs, fn(x) -> reversible(x) end)
  defp reversible(items) when is_list(items), do: {:list, Enum.map(items, fn(item) -> reversible(item) end)}
  defp reversible(val), do: val

  defp convert_map(pairs, converter) do
    convert_pair = fn({key, val}) -> { converter.(key), converter.(val) } end
    pairs |> Enum.map(convert_pair) |> Map.new
  end

  defp convert_set(items, converter) do
    convert_item = fn (item) -> converter.(item) end
    items |> Enum.map(convert_item) |> MapSet.new
  end

  # from_elixir
  #
  # elixir                                                       edn
  # ---                                                          ---
  # integer                                                      integer
  # float                                                        float
  # boolean                                                      boolean
  # nil (atom)                                                   nil
  # tagged integer -> {:char, <integer>}                         char
  # string                                                       string
  # tagged list {:list, [...]}                                   list
  # list                                                         vector
  # map                                                          map
  # mapset                                                       set
  # tagged atom {:symbol, atom}                                  symbol
  # tagged tuple with tag and value -> {:tag, Symbol, Value}     tagged elements
  def from_elixir(elixir_data) do
    try do
      {:ok, from_elixir!(elixir_data)}
    rescue
      e -> {:error, e}
    end
  end

  def from_elixir!(elixir_data) do
    erldn_intermediate = to_erldn_intermediate(elixir_data)
    :erldn.to_string(erldn_intermediate) |> to_string
  end

  defp to_erldn_intermediate(items) when is_list(items) do
    {:vector, Enum.map(items, fn(x) -> to_erldn_intermediate(x) end)}
  end

  defp to_erldn_intermediate( {:list, items} )  do
    Enum.map(items, fn(x) -> to_erldn_intermediate(x) end)
  end

  defp to_erldn_intermediate(%MapSet{} = set) do
    items = Enum.map(set, fn(x) -> to_erldn_intermediate(x) end)
    {:set, items}
  end

  defp to_erldn_intermediate(pairs) when is_map(pairs) do
    convert_pair = fn({key, val}) -> { to_erldn_intermediate(key), to_erldn_intermediate(val) } end
    keyword_list = pairs |> Enum.map(convert_pair)
    {:map, keyword_list}
  end

  defp to_erldn_intermediate( {:tag, tag, val} ), do: {:tag, tag, to_erldn_intermediate(val) }

  defp to_erldn_intermediate(val), do: val

  # Converters
  def tagged_list_to_list({:list, list}), do: list

  def tagged_char_to_string({:char, code}), do: to_string([code])

  def evaluate_tagged_expr({:tag, tag, expr}, handlers) do
    handler = handlers[tag]
    if handler do
      handler.(tag, expr, handlers)
    else
      raise "Handler not found for tag #{tag} with tagged expression #{expr}"
    end
  end

  # Handlers
  def standard_handlers do
    timestamp_handler = { :inst, fn(_tag, val, _handlers) -> inst_handler(val) end }
    uuid_handler = { :uuid, fn(_tag, val, _handlers) -> val |> to_string end }
    # TODO Discard Handler This shouldn't return nil; it should swallow the val.
    # discard_handler = { :_, fn(tag, val, handlers) -> ??? end }
    [ timestamp_handler, uuid_handler ]
  end

  defp inst_handler(char_list) do
    {:ok, result} = char_list |> to_string |> Calendar.DateTime.Parse.rfc3339_utc
    result
  end
end
