# Fix PR Review Comments (TDD)
1. Use GitHub MCP `pull_request_read` tool (method: `get_review_comments`) to fetch review comments
2. For each comment, write a failing test FIRST
3. Implement the fix to make the test pass
4. Run full test suite and mypy
5. Stage changes but DO NOT commit — present a summary for user approval
