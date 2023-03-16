# Xlsxir

[![Build Status](https://travis-ci.org/jsonkenl/xlsxir.svg?branch=master)](https://travis-ci.org/jsonkenl/xlsxir)
[![Hex.pm Version](http://img.shields.io/hexpm/v/xlsxir.svg)](https://hex.pm/packages/xlsxir)
[![Hex docs](http://img.shields.io/badge/hex.pm-docs-blue.svg?style=flat)](https://hexdocs.pm/xlsxir)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/kennellroxco/xlsxir/master/LICENSE)

Xlsxir is an Elixir library that parses `.xlsx` files using Simple API for XML (SAX) parsing via the [Erlsom](https://github.com/willemdj/erlsom) Erlang library, extracts the data to an Erlang Term Storage (ETS) process and provides various functions for accessing the data. Please submit any issues found and they will be addressed ASAP.

## Installation

You can add Xlsxir as a dependency to your Elixir project via the Hex package manager by adding the following to your `mix.exs` file:

```elixir
def deps do
  [ {:xlsxir, "~> 1.6.4"} ]
end
```

Or, you can directly reference the GitHub repo:

```elixir
def deps do
  [ {:xlsxir, github: "jsonkenl/xlsxir"} ]
end
```

Then start an OTP application:

```elixir
def application do
  [extra_applications: [:xlsxir]]
end
```

## Basic Usage

**Xlsxir.extract/3 is deprecated, please use Xlsxir.multi_extract/1-5 going forward.**

Xlsxir parses a `.xlsx` file located at a given `path` and extracts the data to an ETS process via the `Xlsxir.multi_extract/1-5`, `Xlsxir.peek/3-4` and `Xlsxir.stream_list/2-3` functions:

```elixir
Xlsxir.multi_extract(path, index \\ nil, timer \\ false, rows \\ nil, options \\ [])
Xlsxir.peek(path, index, rows, options \\ [])
Xlsxir.stream_list(path, index, options \\ [])
```

The `peek/3-4` functions return only the given number of rows from the worksheet at a given index. The `multi_extract/1-5` functions allow multiple worksheets to be parsed by creating a separate ETS process for each worksheet and returning a unique table identifier for each. This option will parse all worksheets by default (when `index == nil`), returning a list of tuple results.

Argument descriptions:
- `path` the path of the file to be parsed in `string` format
- `index` is the position of the worksheet you wish to parse (zero-based index)
- `timer` is a boolean flag that controls an extraction timer that returns time elapsed when set to `true`. Defalut value is `false`.
- `rows` is an integer representing the number of rows to be extracted from the given worksheet.
- `options` - see function documentation for option detail.

Upon successful completion, the extraction process returns:
- for `multi_extract/3`:
    * `[{:ok, table_1_id}, ...]` with `timer` set to `false`
    * `{:ok, table_id}` when given a specific worksheet `index`
    * `[{:ok, table_1_id, time_elapsed}, ...]` with `timer` set to `true`
    * `{:ok, table_id, time_elapsed}` when given a specific worksheet `index`
- for `peek/3`: `{:ok, table_id}`

Unsucessful parsing of a specific worksheet returns `{:error, reason}`.

<br/>
The extracted worksheet data can be accessed using any of the following functions:

```
Xlsxir.get_list(table_id)
Xlsxir.get_map(table_id)
Xlsxir.get_mda(table_id)
Xlsxir.get_cell(table_id, cell_ref)
Xlsxir.get_row(table_id, row_num)
Xlsxir.get_col(table_id, col_ltr)
Xlsxir.get_info(table_id, num_type)
```

`Xlsxir.get_list/1` returns entire worksheet in a list of row lists (i.e. `[[row 1 values], ...]`)<br/>
`Xlsxir.get_map/1` returns entire worksheet in a map of cell names and values (i.e. `%{"A1" => value, ...}`)<br/>
`Xlsxir.get_mda/1` returns entire worksheet in an indexed map which can be accessed like a multi-dimensional array (i.e. `some_var[0][0]` for cell "A1")<br/>
`Xlsxir.get_cell/2` returns value of specified cell (i.e. `"A1"` returns value contained in cell A1)<br/>
`Xlsxir.get_row/2` returns values of specified row (i.e. `1` returns the first row of data)<br/>
`Xlsxir.get_col/2` returns values of specified column (i.e. `"A"` returns the first column of data)<br/>
`Xlsxir.get_info/1` and `Xlsxir.get_multi_info/2` return count data for `num_type` specified (i.e. `:rows`, `:cols`, `:cells`, `:all`)<br/>

Once the table data is no longer needed, run the following function to delete the ETS process and free memory:
```elixir
Xlsxir.close(table_id)
```

Refer to [Xlsxir documentation](https://hexdocs.pm/xlsxir/index.html) for more detailed examples.

## Considerations

Cell references are formatted as a string (i.e. "A1"). Strings will be returned as type `string`, resulting values for functions from within the worksheet are returned as type `string`, `integer` or `float` depending on the type of the resulting value, data formatted as a number in the worksheet will be returned as type `integer` or `float`, date formatted values will be returned in Erlang `:calendar.date()` type format (i.e. `{year, month, day}`), and datetime values will be returned as an Elixir `naive datetime`. Xlsxir does not currently support dates prior to 1/1/1900.

## Contributing

Contributions are encouraged. Feel free to fork the repo, add your code along with appropriate tests and documentation (ensuring all existing tests continue to pass) and submit a pull request.

## Bug Reporting

Please report any bugs or request future enhancements via the [Issues](https://github.com/kennellroxco/xlsxir/issues) page.

## Acknowledgements

I'd like to thank the following people who were a big help in the development of this library:

- Paulo Almeida (@pma) helped with testing and has provided several great ideas for development.
- Benjamin Tan's (@benjamintanweihao) article on [SAX parsing with Elrsom](http://benjamintan.io/blog/2014/10/01/parsing-wikipedia-xml-dump-in-elixir-using-erlsom/) was invaluable.
- Daniel Berkompas' (@danielberkompas) article [Multidimensional Arrays in Elixir](http://blog.danielberkompas.com/2016/04/23/multidimensional-arrays-in-elixir.html?utm_campaign=elixir_radar_48&utm_medium=email&utm_source=RD+Station) inspired `Xlsxir.get_mda/0`.
- Alex Kovalevych's (@alexkovalevych) contributions greatly improved the parsing performance of Xlsxir. 
