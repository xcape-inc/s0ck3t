package main

import (
	"context"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

/*func captureOutput(f func()) string {
	var buf bytes.Buffer
	log.SetOutput(&buf)
	f()
	log.SetOutput(os.Stderr)
	return buf.String()
}*/

func Test_main(t *testing.T) {
	if os.Getenv("TEST_USAGE") == "1" {
		oldArgs := os.Args
		defer func() { os.Args = oldArgs }()
		os.Args = []string{oldArgs[0]}
		main()
		return
	}
	if os.Getenv("TEST_HELP") == "1" {
		oldArgs := os.Args
		defer func() { os.Args = oldArgs }()
		os.Args = []string{oldArgs[0], "-help"}
		main()
		return
	}

	t.Run("usage", func(t *testing.T) {

		ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
		defer cancel()

		cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=Test_main")
		cmd.Env = append(os.Environ(), "TEST_USAGE=1")

		out, err := cmd.Output()

		// Command was killed
		assert.NotEqual(t, ctx.Err(), context.DeadlineExceeded)

		assert.IsType(t, exec.ExitError{}, err)
		if ee, ok := err.(*exec.ExitError); ok {
			assert.False(t, ee.Success())
			assert.Equal(t, 1, ee.ExitCode())
			// If the command was killed, err will be "signal: killed"
			// If the command wasn't killed, it contains the actual error, e.g. invalid command
			assert.Equal(t, "USAGE: s0ck3t <port>", string(ee.Stderr))
		} else {
			t.Fatal("err asserted to be exec.ExitError, but casting failed; test has bug!")
		}
		// there should be no data on stdout
		assert.Empty(t, string(out))
	})

	t.Run("help", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
		defer cancel()

		cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=Test_main")
		cmd.Env = append(os.Environ(), "TEST_HELP=1")

		out, err := cmd.Output()

		// Command was killed
		assert.NotEqual(t, ctx.Err(), context.DeadlineExceeded)

		assert.IsType(t, exec.ExitError{}, err)
		if ee, ok := err.(*exec.ExitError); ok {
			assert.False(t, ee.Success())
			assert.Equal(t, 0, ee.ExitCode())
			// If the command was killed, err will be "signal: killed"
			// If the command wasn't killed, it contains the actual error, e.g. invalid command
		} else {
			t.Fatal("err asserted to be exec.ExitError, but casting failed; test has bug!")
		}
		// there should be no data on stdout
		assert.Empty(t, string(out))

		// Now call it again now that we know it wont burn
		oldArgs := os.Args
		defer func() { os.Args = oldArgs }()
		os.Args = []string{oldArgs[0], "-help"}

		assert.PanicsWithValue(t, "USAGE: s0ck3t <port>", func() { main() })
	})
}
