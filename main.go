package main

import (
	"fmt"
	"log"
	"os"

	"github.com/armon/go-socks5"
)

func main() {
	// check args
	if len(os.Args) < 2 {
		log.Fatal("USAGE: <", os.Args[0], "> <port>")
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
