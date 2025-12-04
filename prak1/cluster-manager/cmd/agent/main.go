package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/exec"
    "sync"
    "time"

    "cluster-manager/pkg/common"
)

const controllerURL = "http://127.0.0.1:8080"

var (
    mu       sync.Mutex
    replicas = make(map[string]*exec.Cmd)
)

func main() {
    port := ":8081"
    if len(os.Args) > 1 {
        port = ":" + os.Args[1]
    }

    go registerAgent(port)

    http.HandleFunc("/cmd", commandHandler)
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    })

    log.Printf("Agent started on %s", port)
    log.Fatal(http.ListenAndServe(port, nil))
}

func registerAgent(port string) {
    portNum := port[1:]

    url := controllerURL + "/register?port=" + portNum

    for {
        resp, err := http.Get(url)
        if err == nil && resp.StatusCode == 200 {
            resp.Body.Close()
            log.Printf("Successfully registered at controller on port %s", port)
            return
        }
        log.Printf("Registration failed, retry in 5s: %v", err)
        time.Sleep(5 * time.Second)
    }
}

func commandHandler(w http.ResponseWriter, r *http.Request) {
    var cmd common.AgentCommand
    if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
        http.Error(w, "bad json", 400)
        return
    }

    mu.Lock()
    defer mu.Unlock()

    if cmd.Action == "start" {
        if _, err := os.Stat("payload.exe"); os.IsNotExist(err) {
            http.Error(w, "payload.exe not found", 500)
            return
        }

        process := exec.Command("./payload.exe")
        process.Stdout = os.Stdout
        process.Stderr = os.Stderr
        if err := process.Start(); err != nil {
            http.Error(w, err.Error(), 500)
            return
        }

        id := fmt.Sprintf("rep-%d", time.Now().UnixNano())
        replicas[id] = process

        json.NewEncoder(w).Encode(map[string]string{"id": id})
        log.Printf("Started replica %s (PID %d)", id, process.Process.Pid)
        return
    }

    if cmd.Action == "stop" && cmd.ID != "" {
        if process, ok := replicas[cmd.ID]; ok {
            process.Process.Kill()
            delete(replicas, cmd.ID)
            log.Printf("Stopped replica %s", cmd.ID)
        }
        w.WriteHeader(http.StatusOK)
        return
    }

    http.Error(w, "unknown action", 400)
}