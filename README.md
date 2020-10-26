# Exdn - an edn parser for the Elixir platform

Exdn is a two-way translator between Elixir data structures and data 
following the [edn specification](https://github.com/edn-format/edn);
it wraps the [erldn edn parser](https://github.com/marianoguerra/erldn) 
for Erlang, with some changes in the data formats (see below).

 * [Installation](#installation)
 * [Usage](#usage)
 * [API](#api)
 * [Type Mappings](#type-mappings)
 * [Author](#author)
 * [License](#license)

## Installation

Once [available in Hex](https://hex.pm/docs/publish), the package can be installed 
by adding exdn to your list of dependencies in `mix.exs`:

    def deps do
      [{:exdn, "~> 2.2.0"}]
    end

## Usage

    iex> Exdn.to_elixir! "41.2"
      41.2

    iex> Exdn.to_elixir! ":foo"
      :foo

    iex> Exdn.to_elixir! "true"
      true

    iex> Exdn.to_elixir! "nil"
      nil

    iex> Exdn.to_elixir! "\"asd\""
      "asd"

    # Char
    iex> Exdn.to_elixir! "\\a"
      "a"
    
    # Symbol
    iex> Exdn.to_elixir! "foo"
      {:symbol, :foo}

    # edn vectors become Elixir lists:
    iex> Exdn.to_elixir! "[1 :foo]"
      [1, :foo]

    # edn lists are always tagged. Since Datomic is a principal use of edn, and since lists are 
    # used in Datomic primarily for executable expressions rather than as data structures, we 
    # use Elixir lists to represent vectors and keep edn lists specially tagged:    
    iex> Exdn.to_elixir! "(1, :foo)"
      {:list, [1, :foo]}

    # edn sets become Elixir sets:
    iex> Exdn.to_elixir! "\#{1 \\a 1}"
      #MapSet<[1, "a"]>

    # Maps become Elixir maps:
    iex> Exdn.to_elixir! "{1 :foo, 2 :bar}"
      %{1 => :foo, 2 => :bar}
      
    # You can also transform maps to Elixir structs by providing your own converter in the second argument:
    iex> defmodule FooStruct do
    ...>    defstruct foo: "default"
    ...> end
    iex> converter = fn map ->
    ...>    case map do
    ...>       %{:foo => _} -> struct(FooStruct, map)
    ...>       anything_else -> anything_else
    ...>     end
    ...>   end
    iex>  Exdn.to_elixir! "{:foo 1, :bar 2}", converter
       %FooStruct{foo: 1}      

    # Tagged expressions are converted. Standard converters for #inst and #uuid are included:
    iex> Exdn.to_elixir! "#inst \"1985-04-12T23:20:50.52Z\"" 
      %Calendar.DateTime{abbr: "UTC", day: 12, hour: 23, min: 20, month: 4, sec: 50,
        std_off: 0, timezone: "Etc/UTC", usec: 520000, utc_off: 0, year: 1985}

    iex> Exdn.to_elixir! "#uuid \"f81d4fae-7dec-11d0-a765-00a0c91e6bf6\"" 
      "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"

    # You can provide your own handlers for tagged expressions:
    iex> handler = fn(_tag, val, _converter, _handlers) -> val <> "-converted" end
    iex> identity = &(&1)
    iex> Exdn.to_elixir! "#foo \"blarg\"", identity, [{:foo, handler}] 
      "blarg-converted"

    # There is a safe version that doesn't raise exceptions:
    iex> Exdn.to_elixir "{1 :foo, 2 :bar}"
      {:ok, %{1 => :foo, 2 => :bar}}

    iex> Exdn.to_elixir "{:foo, \\a, \\b #foo \"blarg\" }"
      {:error, %RuntimeError{:message => "Handler not found for tag foo with tagged expression blarg"}}

    # There is also an "intermediate" representation that can be converted back to edn. The 
    # difference is that chars and tagged expressions are converted to tagged tuples:    
    iex> Exdn.to_reversible( "\\a" )
      {:char, ?a}
    
    iex> Exdn.to_reversible "#inst \"1985-04-12T23:20:50.52Z\""
      {:tag, :inst, "1985-04-12T23:20:50.52Z"}

    # An unknown tag raises no error when using the reversible conversion:
    iex> Exdn.to_reversible "#foo \"blarg\""
      {:tag, :foo, "blarg"}

    # The intermediate representation can be converted back to edn:
    iex> Exdn.from_elixir! 41.2
      "41.2"

    iex> Exdn.from_elixir! :foo
      ":foo"

    iex> Exdn.from_elixir! true
      "true"

    iex> Exdn.from_elixir! nil
      "nil"

    iex> Exdn.from_elixir! "asd"
      "\"asd\""

    iex> Exdn.from_elixir! {:char, ?a}
      "\\a"

    iex> Exdn.from_elixir! {:symbol, :foo}
      "foo"

    iex> Exdn.from_elixir! [1, :foo]
      "[1 :foo]"

    iex> Exdn.from_elixir! {:list, [1, :foo]}
      "(1 :foo)"

    iex> Exdn.from_elixir! MapSet.new([1, :foo])
      "\#{1 :foo}"

    iex> Exdn.from_elixir! %{1 => :foo, 2 => :bar}
      "{1 :foo 2 :bar}"

    iex> Exdn.from_elixir! %SomeStruct{foo: 1, bar: 2}
      "{:foo 1 :bar 2}"

    iex> Exdn.from_elixir! {:tag, :inst, "1985-04-12T23:20:50.52Z"}
      "#inst \"1985-04-12T23:20:50.52Z\""

    # There is a safe version for converting back to edn that doesn't raise exceptions:
    iex> Exdn.from_elixir %{:foo => {:char, ?a}, {:char, ?b} => {:tag, :inst, "1985-04-12T23:20:50.52Z"} }
      {:ok, "{:foo \\a \\b #inst \"1985-04-12T23:20:50.52Z\"}" }
    
    # There are also converters you can use if you want to handle chars, lists, or tags on an ad-hoc basis:
    iex> Exdn.tagged_list_to_list {:list, [:foo]}
      [:foo]
    
    iex> Exdn.tagged_char_to_string {:char, ?a}
      "a"
    
    iex> handler = fn(_tag, val, _handlers) -> val <> "-converted" end
    iex> Exdn.evaluate_tagged_expr {:tag, :foo, "blarg"}, [{:foo, handler}])
      "blarg-converted"

## API

##### to_elixir!/1

   parses an edn string into an Elixir data structure; this is not a reversible
   conversion as chars are converted to strings, and tagged expressions are 
   interpreted. This function can throw exceptions; for example, if a tagged
   expression cannot be interpreted.

##### to_elixir!/2

   the second argument allows you to supply your own converter function for any of the
   incoming data; your function will be applied recursively to every value in the edn 
   parse tree. Generally you will want to use it to convert maps to structs, but
   you can use it on any incoming data value, including tagged values. (The
   tagged value is first passed to the converter and then, if it is still tagged,
   to the tagged value handlers (see the three-argument version of `to_elixir!` 
   below for more on handlers). The conversion function should be a function of 
   one parameter; generally you will want to pattern-match on incoming values 
   with a default clause that returns the untransformed value.

##### to_elixir!/3

   the third argument allows you to supply your own handlers for the interpretation
   of tagged expressions. These should be in the form of a keyword list.
   The first element of each pair should be a keyword corresponding to the tag,
   and the second element a function of four parameters (tag, value, converter, handlers)
   that handles the tagged values. Generally you will want to operate only on the
   value, but you can also use the tag, the converter passed to `to_elixir!` as
   its second parameter, or the handlers passed to `to_elixir!` as the third parameter.

##### to_elixir/1

   also parses an edn string into an Elixir data structure, but does not throw
   exceptions. The parse result is returned as the second element of a pair 
   whose first element is `:ok` -- if there is an error the first element will
   be `:error` and the second the error that was raised.

##### to_elixir/2

   safe version of `to_elixir!/2`.

##### to_elixir/3

   safe version of `to_elixir!/3`.

##### from_elixir!/1

   converts an Elixir data structure in the "reversible" format (see below) into 
   an edn string. Will raise exceptions if the data structure cannot be converted.
   Structs will be converted to edn maps.

##### from_elixir/1

   safe version of `from_elixir!/1` -- the edn string is returned as the second 
   element of a pair whose first element is `:ok` -- if there is an error the first 
   element will be `:error` and the second the error that was raised.

##### to_reversible/1    

   parses an edn string into an Elixir data structure, but in a reversible way --
   chars and tagged expressions are represented using tuples whose first element
   is `:char` or `:tag`, respectively.


## Type Mappings

| edn	            | Elixir generated by `to_elixir` functions when no custom converter is provided
| --------------- | --------------------------------------------------------------------------
| integer	        | integer
| float	          | float
| boolean	        | boolean
| nil	            | nil (atom)
| char            | string
| string	        | string
| list	          | tagged list `{:list, [...]}`
| vector	        | list
| map	            | map
| set	            | mapset
| symbol	        | tagged atom `{:symbol, atom}`
| tagged elements	| call registered handler for that tag, fail if not found


### Reversible Mappings

| edn             | Elixir generated by `to_reversible` or accepted by `from_elixir` functions
| --------------- | --------------------------------------------------------------------------
| integer	        | integer
| float	          | float
| boolean	        | boolean
| nil	            | nil (atom)
| char            | tagged integer `{:char, <integer>}`
| string	        | string
| list	          | tagged list `{:list, [...]}`
| vector	        | list
| map	            | map
| struct          | map
| set	            | mapset
| symbol	        | tagged atom `{:symbol, atom}`
| tagged elements | tagged tuple with tag and value `{:tag, Symbol, Value}`

## Author

psfblair

## License

MIT license
