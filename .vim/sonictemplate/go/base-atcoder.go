package main

import (
	"io"
	"os"
)

func run(r io.Reader, w io.Writer) {
	{{_cursor_}}
}

func main() {
	run(os.Stdin, os.Stdout)
}
