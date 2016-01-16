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
    convert_list(items, fn(x) -> elrldn_to_elixir!(x, handlers) end)
  end

  defp elrldn_to_elixir!( {:set, items},    handlers )  do
    convert_set(items, fn(x) -> elrldn_to_elixir!(x, handlers) end)
  end

  defp elrldn_to_elixir!( {:map, pairs},    handlers )  do
    convert_map(pairs, fn(x) -> elrldn_to_elixir!(x, handlers) end)
  end

  defp elrldn_to_elixir!( items,            handlers) when is_list(items) do
    {:list, convert_list(items, fn(x) -> elrldn_to_elixir!(x, handlers) end)}
  end

  defp elrldn_to_elixir!( val, handlers), do: val

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
  defp reversible({:vector, items}), do: convert_list(items, fn(x) -> reversible(x) end)
  defp reversible({:set, items}), do: convert_set(items, fn(x) -> reversible(x) end)
  defp reversible({:map, pairs}), do: convert_map(pairs, fn(x) -> reversible(x) end)
  defp reversible(items) when is_list(items), do: {:list, convert_list(items, fn(x) -> reversible(x) end)}
  defp reversible(val), do: val


  defp convert_list(items, converter) do
    convert_item = fn (item) -> converter.(item) end
    Enum.map(items, convert_item)
  end

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
  # elixir	                                                 erlang-intermediate representation                       edn
  # ---                                                       ---                                                     ---
  # integer		                                                same                                                    integer
  # float	  	                                                same                                                    float
  # boolean		                                                same                                                    boolean
  # nil	    	                                                same                                                    nil
  # tagged string -> {:char, str}                             same                                                    char
  # string	                                                  same                                                    string
  # tagged list -> {:list, [...]}                             list                                                    list
  # list                                                      tagged list -> {:vector, [...]}                         vector
  # map                                                       tagged property list -> {:map, [{key1, val1}, ...]}     map
  # mapset                                                    tagged list -> {:set, [...]}                            set
  # tagged atom {:symbol, atom}                               same                                                    symbol
  # tagged tuple with tag and value -> {:tag, Symbol, Value}  same                                                    tagged element
  def from_elixir do

  end

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
