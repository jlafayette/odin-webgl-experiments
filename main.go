package main

import (
	"bytes"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"time"

	"github.com/fsnotify/fsnotify"
)

func main() {
	build()
	go watch("../")
	go watch("../../shared/")

	fs := http.FileServer(http.Dir("./"))
	http.Handle("/", fs)

	log.Print("Listening on :3000 ...")
	err := http.ListenAndServe(":3000", nil)
	if err != nil {
		log.Fatal(err)
	}
}

func build() {
	cmd := exec.Command(
		"odin", "build", "../", "-out:_main.wasm", "-target:js_wasm32",
		"-o:minimal",
		// "-o:aggressive", "-disable-assert", "-no-bounds-check",
	)
	log.Println("Running command and waiting for it to finish...")
	var outb, errb bytes.Buffer
	cmd.Stdout = &outb
	cmd.Stderr = &errb
	err := cmd.Run()
	fmt.Println("out:", outb.String(), "err:", errb.String())
	if err != nil {
		log.Printf("Finished cmd with err: %v\n", err)
	} else {
		log.Println("Done")
	}
}

func watch(src string) error {
	log.Printf("Starting watch %v\n", src)

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		fmt.Println("ERROR", err)
		return err
	}
	defer watcher.Close()

	done := make(chan bool)
	go func() {
		rebuild := false
		build_time := time.Now()
		for {
			select {
			case event := <-watcher.Events:
				if strings.HasSuffix(event.Name, ".bck") || strings.HasSuffix(event.Name, "public") {
					// log.Println("Skipping backup-file/public")
				} else {
					// log.Printf("EVENT: %#v\n", event)
					log.Println("-> ", event.Op.String())
					rebuild = true
				}
			case err := <-watcher.Errors:
				log.Println("WatcherError:", err)
			default:
				fmt.Print(".")
				if rebuild && time.Since(build_time)*time.Millisecond > 200 {
					build()
					rebuild = false
					build_time = time.Now()
				}
				time.Sleep(100 * time.Millisecond)
			}
		}
	}()
	if err := watcher.Add(src); err != nil {
		fmt.Println("ERROR", err)
		return err
	}
	<-done
	return nil
}
