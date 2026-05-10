;; extends

; --- Auto-highlight strings starting with SELECT/INSERT/UPDATE/DELETE/WITH ---
(
  [(interpreted_string_literal (interpreted_string_literal_content) @injection.content)
   (raw_string_literal (raw_string_literal_content) @injection.content)]
  (#lua-match? @injection.content "^%s*[Ss][Ee][Ll][Ee][Cc][Tt]")
  (#set! injection.language "sql")
)

; --- Enable magic comment (// language=sql) ---
(
  (comment) @_comment
  .
  (short_var_declaration
    right: (expression_list
      [(interpreted_string_literal (interpreted_string_literal_content) @injection.content)
       (raw_string_literal (raw_string_literal_content) @injection.content)]))
  (#match? @_comment "^//\\s*language=sql")
  (#set! injection.language "sql")
)

; --- Auto-highlight when variable name ends with "sql", "SQL", "query", or "Query" ---
(short_var_declaration
  left: (expression_list (identifier) @_name)
  right: (expression_list
    [(interpreted_string_literal (interpreted_string_literal_content) @injection.content)
     (raw_string_literal (raw_string_literal_content) @injection.content)])
  (#match? @_name "(sql|SQL|query|Query)$")
  (#set! injection.language "sql"))

; --- Auto-highlight SQL in db.Query/Exec/QueryRow and their Context variants ---
(call_expression
  function: (selector_expression
    field: (field_identifier) @_func
    (#match? @_func "^(Query|Exec|QueryRow|QueryContext|ExecContext|QueryRowContext)$"))
  arguments: (argument_list
    [(interpreted_string_literal (interpreted_string_literal_content) @injection.content)
     (raw_string_literal (raw_string_literal_content) @injection.content)])
  (#set! injection.language "sql"))
