; Inject SQL into strings starting with --sql (e.g. "--sql\nSELECT ...")
((string
  (string_content) @injection.content)
 (#lua-match? @injection.content "^%-%-%s*sql")
 (#set! injection.language "sql")
 (#set! injection.include-children))
