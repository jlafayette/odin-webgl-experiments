package main

import (
	"bytes"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"time"

	"github.com/fsnotify/fsnotify"
)

func main() {
	noWatchPtr := flag.Bool("no-watch", false, "turn off file watcher")
	noBuildPtr := flag.Bool("no-build", false, "turn off initial odin build")
	flag.Parse()
	odin_exe := flag.Arg(0)
	if !*noBuildPtr {
		build(odin_exe)
	}
	if !*noWatchPtr {
		go watch("../", odin_exe)
		go watch("../../shared/", odin_exe)
	}

	fs := http.FileServer(http.Dir("./"))
	http.Handle("/", fs)

	log.Print("Listening on :3000 ...")
	err := http.ListenAndServe(":3000", nil)
	if err != nil {
		log.Fatal(err)
	}
}

func build(odin_exe string) {
	cmd := exec.Command(
		odin_exe, "build", "../", "-out:_main.wasm", "-target:js_wasm32",
		"-o:minimal",
		// "-o:speed", "-disable-assert", "-no-bounds-check",
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

func watch(src string, odin_exe string) error {
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
					build(odin_exe)
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
