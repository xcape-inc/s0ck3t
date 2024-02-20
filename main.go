package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/armon/go-socks5"
)

const (
	usageFormatString string = "USAGE: %s <port>\n"
)

func main() {
	// check args
	/*if len(os.Args) < 2 {
		log.Fatal("USAGE: <", os.Args[0], "> <port>")
	}*/
	//os.Args = []string{os.Args[0], "-help"}
	oldWriter := flag.CommandLine.Output()
	flag.CommandLine = flag.NewFlagSet(os.Args[0], flag.ExitOnError)
	//restore the writer
	flag.CommandLine.SetOutput(oldWriter)
	flag.Usage = func() {
		callerPath := os.Args[0]
		_, callerName := filepath.Split(callerPath)
		fmt.Fprintf(flag.CommandLine.Output(), usageFormatString, callerName)
		flag.PrintDefaults()
	}
	flag.CommandLine.Usage = flag.Usage

	flag.Parse()
	if flag.NArg() != 1 {
		flag.Usage()
		os.Exit(1)
	}

	// build socks server
	server, err := socks5.New(&socks5.Config{})
	if err != nil {
		log.Panic(err)
	}

	// start listener
	fmt.Println("Running...")
	if err := server.ListenAndServe("tcp", "127.0.0.1:"+fmt.Sprint(os.Args[1])); err != nil {
		log.Panic(err)
	}
}
