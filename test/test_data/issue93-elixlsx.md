# Issue 93 regression fixture

`issue93-elixlsx.xlsx` is the unchanged public `bug.xlsx` attachment from
https://github.com/jsonkenl/xlsxir/issues/93, downloaded 2026-09-19:
https://github.com/jsonkenl/xlsxir/files/3418707/bug.xlsx

SHA-256: `cde6585a0a06a080a732a3be137637b61a26d96f4d622fa9cb0a0e5b3a27f5ab`.

The issue describes generating it with Elixlsx. Sheet1 contains A; Sheet2
contains A and B. Workbook sheet IDs are 1 and 2, while relationship IDs are
rId2 and rId3, targeting sheet1.xml and sheet2.xml. This protects the original
name/data association fixed by dc035ce, not general relationship resolution.
Later producer reports and reordered/nonstandard targets remain A7 work.
