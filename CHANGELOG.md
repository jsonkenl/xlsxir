# Change Log

## Unreleased

- Fixed leading empty-cell padding for rows starting in columns such as `AA`
  and `AB`, following [#132](https://github.com/jsonkenl/xlsxir/pull/132).
  Materialized lists and MDA maps now retain the correct column positions;
  cell counts include the inserted `nil` placeholders. Callers compensating
  for the previous left shift should remove that workaround. Streaming gap
  behavior is unchanged.
- Fixed workbook parsing crashes for relationship IDs such as `R1` and
  `rIdSheet1` by removing unused numeric-ID parsing. Thanks to @coop for
  [#137](https://github.com/jsonkenl/xlsxir/pull/137), addressing
  [#106](https://github.com/jsonkenl/xlsxir/issues/106).
- **Breaking change for parser-state consumers:** sheet maps in
  `Xlsxir.ParseWorkbook.sheets` now contain only `name` and `sheet_id`; `rid`
  has been removed. Remove `rid` accesses and pattern matches from callers.
  `sheet_id` is not a substitute relationship ID. General workbook relationship
  resolution is still unsupported; worksheet selection and naming are unchanged.

## 1.6.4
- Cleaned up several warnings due to Elixir versioning deprecations. Thanks to @michaelst and @getong for contributions. 

## 1.6.3
- Fixed bug where multi_extract did not return {:error, msg} for non existent file. Thanks to Peter Sumskas (@brushbox) for contribution.
- Fixed bug where formula was returned if calculated value was empty. Thanks to Ken Ip (@kenips) for contribution.
- Sheet name added to `Xlsxir.get_info/1` and updated formatting. Thanks to Hongseok Yoon (@hongseokyoon) for contribution.
- Updated docs.

## 1.6.2
- Fixed bug where `Xlsxir.get_list/1` was not populating empty cells with `nil` propely.
- Pattern matching on error cells was widened to include additional use cases. Thanks to Peter Sumskas (@brushbox) for contribution.
- Updated tests, docs and various code styles.

## 1.6.1
- Fixed bug where `Xlsxir.get_cell/2` raised instead of returning `nil` on non-existing cell. Thanks to @ZombieHarvester for contribution.
- Various documentation updates.

## 1.6.0
- Huge parsing performance improvement thanks to Alex Kovalevych's (@AlexKovalevych) contribution.
- Ability to choose between parsing in-memory or on the file system added as well as the ability to stream via the `Xlsxir.stream_list/2`. Thanks to Thibaut Decaudain (@Tricote) for contribution. 
- Code improved to better handle complex multi-formatted strings. Thanks to Peter Sumskas (@brushbox) for contribution.
- Bug fix to handle additional date format. Thanks to Sudhir Rao (@sudrao) for contribution.
- Fixes for some `xlsx` variants and repeatable stream issues. Thanks to @rhetzler for contribution.
- Various error message improvements. Thanks to Craig Lyons (@craiglyons) for contribution. 

## 1.5.2 (not published on Hex)
- Fixed bug that occured when a worksheet was empty. Thanks to Alex Kovalevych (@AlexKovalevych) for contribution. 
- Changed `get_cell/1` to return `nil` if the requested cell doesn't exist. Thanks to Peter Sumskas (@brushbox) for contribution.

## 1.5.1
- Removed `Timex` dependency. Thanks to Paulo Almeida (@pma) for contribution.

## 1.5.0
- ***Xlsxir requires Elixir v1.4+ with this update***
- Added ability to extract only a given number of rows from a worksheet via `Xlsxir.peek/3`. Thanks to Ali Tahbaz (@tahbaza) for contribution.
- `DateTime` type values are now converted to an Elixir `Naive DateTime` type upon extraction. Regular `Date` types are still converted to Erlang `:calendar.date()` type. Thanks to Ali Tahbaz (@tahbaza) for contribution.
- A bug in `convert_char_number/1` was fixed to allow support for floats with scientific notation in them. Thanks to Daniel Parnell (@dparnell) for contribution.
- Minor bug fixes and documentation updates. 

## 1.4.1
- Added parsing support for time values. Thanks to Edgar Cabrera (@aleandros) for contribution.
- Fixed bug that prevented worksheet ETS tables from closing. Thanks to Alex Kovalevych (@AlexKovalevych) for contribution.
- Minor documentation updates.

## 1.4.0
- `Xlsxir.extract/3` and `Xlsxir.multi_extract/3` now parse all worksheets of the file given by default, returning a list of tuple results (i.e. `[{:ok, table_1_id}, {:ok, table_2_id}, ...]`). See [updated docs](https://hexdocs.pm/xlsxir/overview.html) for more detail. Thanks to Alex Kovalevych (@AlexKovalevych) for contribution. 
- Fixed bug where the string(s) from merged cells that contained multiple formatting leaked into other cells thereby corrupting other rows of data.
- Sorted cell attribute keys to ensure consistent pattern matching. Thanks to Alex Kovalevych (@AlexKovalevych) for contribution.
- Updated documentation to reflect changes and added additional doc tests.

## 1.3.6

- Added boolean value support. Thanks to Pikender Sharma (@pikender) for contribution.
- Added support for data type `inlineStr`.
- `Xlsxir.extract/3` and `Xlsxir.multi_extract/3` now return `{:error, reason}` instead of throwing an exception when an invalid file type or worksheet index are provided as arguments.
- Changed the way file paths are validated prior to parsing. It no longer matters whether or not the extension is `.xlsx`. As long as it is a valid file, Xlsxir will attempt to parse it. 
- Refactored `Unzip.delete_dir/1` for simplification.
- Minor documentation updates.

## 1.3.5

- Fixed bug where unnecessary cells with `nil` values were added to worksheets with rows containing data beyond column `"Z"`.

## 1.3.4

- Fixed bug related to parsing a worksheet containing conditional formatting. Thanks to Justin Nauman (@jrnt30) for contribution.
- Fixed bug where row number was erroneously represented as a string (instead of integer) in the ETS table causing `Enum.sort` to not work as expected on larger files.
- Minor documentation updates.

## 1.3.3

- Minor bug fixes.

## 1.3.2

- Fixed bug where dates in the year 1900 were off by one day due to the fact that Excel erroneously considers the year 1900 a leap year. 
- Minor documentation updates.

## 1.3.1

- Fixed issue where empty cells were skipped. Empty cells will now be represented as `nil`. For example, if cells "A1" = 1, "B1" = 2, and "D1" = 4, `Xlsxir.get_list/1` would return `[[1, 2, 4]]`. The same situation will now return `[[1, 2, nil, 4]]` to account for the fact that cell "C1" was empty. 
- Minor updates to documentation to reflect change.

## 1.3.0

- Added ability to parse multiple worksheets via `Xlsxir.multi_extract/3` which returns a unique table identifier for each ETS process created, enabling the user to access parsed data from multiple worksheets simultaneously. 
- Created an `Xlsxir.TableId` module which controls an agent process that temporarily holds a table identifier during the extraction process.
- Refactored `Xlsxir` access functions to work with `Xlsxir.multi_extract/3` whereby a table identifier is passed through the various functions to specify which ETS process is to be accessed. 
- Refactored `Xlsxir.SaxParser`, `Xlsxir.ParseWorksheet` and `Xlsxir.Worksheet` modules to support new functionality.
- Refactored `Xlsxir.ParseWorksheet` to ignore empty cells.
- Updated documentation and tests
- Fixed a few minor bugs that were generating warning messages. 

## 1.2.1

- Removed Ex-Doc and Earmark dependencies from Hex.
- Added Change Log link to Hex.
- Minor doc changes and bug fixes.

## 1.2.0

- Added `Xlsxir` access function `Xlsxir.get_mda/0` that accesses `:worksheet` ETS table and returns an indexed map which functions like a multi-dimensional array in other languages.

## 1.1.0

- Modified the way rows are saved to the `:worksheet` ETS table. Replaced the generic index with the actual row number to allow for performance imporovement of supporting  `Xlsxir` access functions.
- Refactored `Xlsxir` access functions to improve performance.
- Created `Xlsxir.get_info/1` function which returns number of rows, columns and cells. 
- Various minor modifications to docs. 

## 1.0.0

Major changes in version 1.0.0 (non-backwards compatible) to improve performance and incorporate new functionality, including: 

- Refactored the `Xlsxir.Unzip` module to extract `.xlsx` contents to file instead of memory to improve memory usage. The following functions were created to support this functionality:
    * `Xlsxir.Unzip.extract_xml_to_file/2` - Extracts necessary files to a `./temp` directory for use during the parsing process
    * `Xlsxir.Unzip.delete_dir/1` - Deletes './temp' directory and all of its contents
- Implemented Simple API for XML (SAX) parsing functionalty via the [Erlsom](https://github.com/willemdj/erlsom) Erlang library to improve performance and allow support for large `.xlsx` files. The `SweetXml` parsing library has been deprecated from `Xlsxir` and is no longer utilized in v1.0.0.    
- Implemented Erlang Term Storage (ETS) for temporary storage of extracted data.
- Replaced `option` argument from the initial extract function (`Xlsxir.extract/3`) with `timer` which is a boolean flag that controls `Xlsxir.Timer` functionality. Data is no longer returned via `Xlsxir.extract/3` and is instead stored in an ETS process.
- Implemented various functions for accessing the extracted data:
    * `Xlsxir.get_list/0` - Return entire worksheet data in the form of a list of row lists 
    * `Xlsxir.get_map/0` - Return entire worksheet data in the form of a map of cell names and values
    * `Xlsxir.get_cell/1` - Return value of specified cell
    * `Xlsxir.get_row/1` - Return values of specified row
    * `Xlsxir.get_col/1` - Return values of specified column
- Implemented `Xlsxir.close/0` function to allow the deletion of the ETS process containing extracted worksheet data to free up memory.
- Implemented `Xlsxir.Timer` module for tracking elapsed time of extraction process.
- Changed cell references from `atoms` to `strings` due to Elixir `atom` limitations (i.e. `:A1` to `"A1"`).
- Updated documentation and testing to incorporate changes.

## 0.0.5

- Minor bug fixes and documentation updates.

## 0.0.4

- Expanded coverage of Office Open XML standard `numFmt` (Standard Number Format). The `formatCode` for a standard `numFmt` is implied rather than explicitly identified in the XML file.
- Implemented support for Office Open XML custom `numFmt` (Custom Number Format) utilizing the `formatCode` explicitly identified in the XML file. 
- Added `Number Styles` documentation covering standard and custom `numFmt` and how to manually add an unsupported `numFmt`.
- Fixed issue resulting when no strings exist in a worksheet and therefore there is no `sharedStrings.xml` file (`:file_not_found` error).

## 0.0.3

- Fixed issue related to strings that contain special characters. Refactored `Xlsxir.Parse.shared_strings/1` to properly parse strings with special characters.

## 0.0.2

- Refactored `Xlsxir.Parse` functions to improve `extract` performance on larger files.
- Expanded documentation and test coverage.
- Completed `Xlsxir.ConvertDate` module.

## 0.0.1

- Initial draft. Functionality limited to very small Excel worksheets.
- `Xlsxir.ConvertDate` functionality incomplete.
