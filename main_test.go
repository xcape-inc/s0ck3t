package main

import (
	"bytes"
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"regexp"
	"runtime/debug"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func waitTimeout(timeout time.Duration, f func()) (funcDidPanic bool, panicValue interface{}, panickedStack string, err error) {
	c := make(chan []interface{})
	defer func() {
		close(c)
	}()
	go func() {
		funcDidPanic, panicValue, panickedStack := didPanic(f)
		var x []interface{}
		x = append(x, funcDidPanic, panicValue, panickedStack, nil)
		c <- x
	}()
	select {
	case msg1 := <-c:
		var ok bool
		if funcDidPanic, ok = msg1[0].(bool); !ok {
			err = errors.New("waitTimeout unable to unwrap didPanic bool")
			return
		}
		panicValue = msg1[1]
		if panickedStack, ok = msg1[2].(string); !ok {
			err = errors.New("waitTimeout unable to unwrap stack trace string")
			return
		}
		if err != nil {
			if err, ok = msg1[3].(error); !ok {
				err = errors.New("waitTimeout unable to unwrap error")
				return
			}
		}
		return // completed normally
	case <-time.After(timeout):
		err = errors.New("exec timeout")
		return // timed out
	}
}

func captureOutput(f func(), data *bytes.Buffer) (v interface{}) {
	oldLogOutput := log.Writer()
	oldFlagOutput := flag.CommandLine.Output()
	defer func() {
		log.SetOutput(oldLogOutput)
		flag.CommandLine.SetOutput(oldFlagOutput)
	}()
	log.SetOutput(data)
	flag.CommandLine.SetOutput(data)

	f()
	return
}

type panicCatcher func(func()) (bool, interface{}, string)

func didPanic(f func()) (didPanic bool, message interface{}, stack string) {
	didPanic = true

	defer func() {
		message = recover()
		if didPanic {
			stack = string(debug.Stack())
		}
	}()

	// call the target function
	f()
	didPanic = false

	return
}

type tHelper interface {
	Helper()
}

func panicsWithValueMatchesRegex(t assert.TestingT, rx interface{}, f assert.PanicTestFunc, panicCatcherFunc panicCatcher, msgAndArgs ...interface{}) bool {
	if h, ok := t.(tHelper); ok {
		h.Helper()
	}
	if panicCatcherFunc == nil {
		panicCatcherFunc = didPanic
	}

	funcDidPanic, panicValue, panickedStack := panicCatcherFunc(f)
	if !funcDidPanic {
		return assert.Fail(t, fmt.Sprintf("func %#v should panic\n\tPanic value:\t%#v", f, panicValue), msgAndArgs...)
	}

	return assert.Regexpf(t, rx, panicValue, fmt.Sprintf("func %#v should panic with value expected to  match \"%v\"\n\tPanic value:\t%#v\n\tPanic stack:\t%s", f, rx, panicValue, panickedStack), msgAndArgs...)
}

func requirePanicsWithValueMatchesRegex(t require.TestingT, rx interface{}, f assert.PanicTestFunc, panicCatcherFunc panicCatcher, msgAndArgs ...interface{}) {
	if h, ok := t.(tHelper); ok {
		h.Helper()
	}
	if panicsWithValueMatchesRegex(t, rx, f, panicCatcherFunc, msgAndArgs...) {
		return
	}
	t.FailNow()
}

func Test_main(t *testing.T) {
	if os.Getenv("TEST_USAGE") == "1" {
		oldArgs := os.Args
		defer func() { os.Args = oldArgs }()
		os.Args = []string{oldArgs[0]}
		main()
		return
	}
	if os.Getenv("TEST_EXTRA_ARG") == "1" {
		oldArgs := os.Args
		defer func() { os.Args = oldArgs }()
		os.Args = []string{oldArgs[0], "1", "2"}
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

		cmd := exec.CommandContext(ctx, os.Args[0], "-test.run", "^Test_main/usage$")
		cmd.Env = append(os.Environ(), "TEST_USAGE=1")

		out, err := cmd.Output()

		// Command was killed
		aaa := ctx.Err()
		require.NotEqual(t, aaa, context.DeadlineExceeded)

		require.NotNil(t, err)
		require.IsType(t, &exec.ExitError{}, err)
		if ee, ok := err.(*exec.ExitError); ok {
			require.False(t, ee.Success())
			require.Equal(t, 1, ee.ExitCode())
			// If the command was killed, err will be "signal: killed"
			// If the command wasn't killed, it contains the actual error, e.g. invalid command
			require.Equal(t, "USAGE: s0ck3t.test <port>\n", string(ee.Stderr))
		} else {
			t.Fatal("err asserted to be exec.ExitError, but casting failed; test has bug!")
		}
		// there should be no data on stdout
		require.Empty(t, string(out))
	})

	t.Run("help", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
		defer cancel()

		cmd := exec.CommandContext(ctx, os.Args[0], "-test.run", "^Test_main/help$")
		cmd.Env = append(os.Environ(), "TEST_HELP=1")

		out, err := cmd.Output()

		// Command was killed
		require.NotEqual(t, ctx.Err(), context.DeadlineExceeded)
		require.Nil(t, err)
		require.Empty(t, string(out))

		// Now call it again now that we know it wont burn
		oldArgs := os.Args
		defer func() { os.Args = oldArgs }()
		os.Args = []string{oldArgs[0], "-help"}

		// TODO: capture output
		var a bytes.Buffer
		require.PanicsWithValue(t, "unexpected call to os.Exit(0) during test", func() { captureOutput(main, &a) })
		require.Equal(t, "USAGE: s0ck3t.test <port>\n", a.String())
	})

	t.Run("too_many_args", func(t *testing.T) {

		ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
		defer cancel()

		cmd := exec.CommandContext(ctx, os.Args[0], "-test.run", "^Test_main/too_many_args$")
		cmd.Env = append(os.Environ(), "TEST_EXTRA_ARG=1")

		out, err := cmd.Output()

		// Command was killed
		aaa := ctx.Err()
		require.NotEqual(t, aaa, context.DeadlineExceeded)

		require.NotNil(t, err)
		require.IsType(t, &exec.ExitError{}, err)
		if ee, ok := err.(*exec.ExitError); ok {
			require.False(t, ee.Success())
			require.Equal(t, 1, ee.ExitCode())
			// If the command was killed, err will be "signal: killed"
			// If the command wasn't killed, it contains the actual error, e.g. invalid command
			require.Equal(t, "USAGE: s0ck3t.test <port>\n", string(ee.Stderr))
		} else {
			t.Fatal("err asserted to be exec.ExitError, but casting failed; test has bug!")
		}
		// there should be no data on stdout
		require.Empty(t, string(out))
	})

	t.Run("bad_arg_value", func(t *testing.T) {
		// Now call it again now that we know it wont burn
		oldArgs := os.Args
		defer func() { os.Args = oldArgs }()
		os.Args = []string{oldArgs[0], "junk"}

		// capture output and any timeout error
		var a bytes.Buffer

		funcDidPanic, panicValue, panickedStack, err := waitTimeout(
			1*time.Second,
			func() {
				captureOutput(main, &a)
			})
		require.Nil(t, err)
		replayDidPanic := func(f func()) (bool, interface{}, string) {
			return funcDidPanic, panicValue, panickedStack
		}

		requirePanicsWithValueMatchesRegex(
			t,
			regexp.MustCompile("^listen tcp: address tcp/junk: unknown port$"),
			func() {
				waitTimeout(
					1*time.Second,
					func() {
						captureOutput(main, &a)
					})
			},
			replayDidPanic)
		require.Regexp(t, regexp.MustCompile("^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2} listen tcp: address tcp/junk: unknown port\n$"), a.String())
	})

	// TODO: test actual server
}
