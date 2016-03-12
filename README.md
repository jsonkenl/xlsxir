# Xlsxir

Xlsxir is an Elixir library that parses Microsoft Excel worksheets (currently only 
`.xlsx` format) and returns the data in either a `list` or a `map`. 

## Installation

You can add Xlsxir as a dependancy to your Elixir project by adding the following to your `mix.exs` file: 

```elixir
def deps do
  [ { :xlsxir, github: "kennellroxco/xlsxir" } ]
end
```

Xlsxir will be added to [Hex](https://hex.pm) soon.

## Basic Usage

Xlsxir can parse an excel file and return the data in one of two ways depending on the option chosen. The main function takes 2 or 3 arguments:

```elixir
Xlsxir.extract(path, index, option \\ :rows)
```

Argument descriptions:
- `path` the path of the file to be parsed in `string` format
- `index` is the position of the worksheet you wish to parse, starting with `0`
- `option` is the method in which you want the data returned

Options:
  - `:rows` - a list of row value lists (default) - i.e. `[[row_1_values], [row_2_values], ...] `
  - `:cells` - a map of cell/value pairs - i.e. `%{ A1: value_of_cell, B1: value_of_cell, ...}`

Refer to [Xlsxir library](https://kennellroxco.github.io) documentation for more detailed examples. 

## Considerations

Strings will be returned as type `string`, resulting values for functions from within Excel are returned as type `string`, `integer` or `float` depending on the type of theresulting value, data formatted as a number in Excel will be returned as type `integer` or `float`, and Excel date formatted values will be returned in Erlang `:calendar.date()` type format (i.e. `{year, month, day}`). 

## Contributing

Contributions are encouraged. Feel free to fork the repo, add your code along with appropriate tests and documentation (ensuring all existing tests continue to pass) and submit a pull request. 

## Bug Reporting

Please report any bugs or request future enhancements via the [Issues](https://github.com/kennellroxco/xlsxir/issues) page. 