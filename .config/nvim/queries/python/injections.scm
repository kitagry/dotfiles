;; extends
(
  (string (string_content) @injection.content)
  (#lua-match? @injection.content "^%-%-%s*sql")
  (#set! injection.language "sql")
  (#set! injection.include-children)
)

; --- Enable magic comment (# language=sql) ---
(
  (comment) @_comment
  .
  (assignment right: (string (string_content) @injection.content))
  (#match? @_comment "^#\\s*language=sql")
  (#set! injection.language "sql")
)

; --- Auto-highlight when variable name ends with "sql" or "query" ---
(assignment
  left: (identifier) @_name (#match? @_name "(sql|query)$")
  right: (string (string_content) @injection.content)
  (#set! injection.language "sql"))

; --- Auto-highlight contents of cursor.execute() ---
(call
  function: (attribute attribute: (identifier) @_attr (#eq? @_attr "execute"))
  arguments: (argument_list (string (string_content) @injection.content))
  (#set! injection.language "sql"))
