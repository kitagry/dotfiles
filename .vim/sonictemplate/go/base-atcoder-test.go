package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestRun(t *testing.T) {
	tests := []struct {
		input  string
		output string
	}{
		{
			input:  `{{_cursor_}}`,
			output: ``,
		},
	}

	for _, test := range tests {
		r := strings.NewReader(test.input)
		var buffer bytes.Buffer
		run(r, &buffer)
		got := buffer.String()
		if got != test.output {
			t.Errorf(`input:\n%s\nexpect:\n%s\ngot:\n%s`, test.input, test.output, got)
		}
	}
}
