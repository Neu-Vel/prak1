package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"
)

type Replica struct {
	ID     string    `json:"id"`
	Agent  string    `json:"agent"`
	Status string    `json:"status"`
	Start  time.Time `json:"start"`
}

type ClusterStatus struct {
	Replicas []Replica `json:"replicas"`
	Agents   []string  `json:"agents"`
}

var (
	mu              sync.RWMutex
	status          ClusterStatus
	desiredReplicas = 0
	agents          = make(map[string]bool)
)

func main() {
	http.HandleFunc("/deploy", deployHandler)
	http.HandleFunc("/status", statusHandler)
	http.HandleFunc("/register", registerHandler)

	go healthChecker()
	go autoBalancer()

	log.Println("Controller started → http://127.0.0.1:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func deployHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Replicas int `json:"replicas"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad json", 400)
		return
	}
	desiredReplicas = req.Replicas
	log.Printf("Desired replicas set to %d", desiredReplicas)
	go balance()
	w.WriteHeader(http.StatusOK)
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	defer mu.RUnlock()
	json.NewEncoder(w).Encode(status)
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
	port := r.URL.Query().Get("port")
	if port == "" {
		port = "8081"
	}

	ip := strings.Split(r.RemoteAddr, ":")[0]
	agentAddr := ip + ":" + port

	mu.Lock()
	if !agents[agentAddr] {
		agents[agentAddr] = true
		status.Agents = append(status.Agents, agentAddr)
		log.Printf("Agent registered: %s", agentAddr)
	}
	mu.Unlock()

	w.WriteHeader(http.StatusOK)
}

func healthChecker() {
	for {
		time.Sleep(10 * time.Second)
		mu.Lock()
		for agent := range agents {
			url := "http://" + agent + "/health"
			resp, err := http.Get(url)
			if err != nil || resp.StatusCode != 200 {
				log.Printf("Agent %s is DOWN → removing its replicas", agent)
				agents[agent] = false
				var alive []Replica
				for _, rep := range status.Replicas {
					if strings.HasPrefix(rep.Agent, agent) {
						log.Printf("Removed dead replica %s", rep.ID)
					} else {
						alive = append(alive, rep)
					}
				}
				status.Replicas = alive
			} else {
				resp.Body.Close()
			}
		}
		mu.Unlock()
		go balance()
	}
}

func autoBalancer() {
	for {
		time.Sleep(15 * time.Second)
		balance()
	}
}

func balance() {
	mu.Lock()
	defer mu.Unlock()

	current := len(status.Replicas)
	diff := desiredReplicas - current

	var aliveAgents []string
	for a, ok := range agents {
		if ok {
			aliveAgents = append(aliveAgents, a)
		}
	}

	if len(aliveAgents) == 0 {
		log.Println("No alive agents")
		return
	}

	if diff > 0 {
		for i := 0; i < diff; i++ {
			agent := aliveAgents[i%len(aliveAgents)]
			id := sendStart(agent)
			if id != "" {
				status.Replicas = append(status.Replicas, Replica{
					ID:     id,
					Agent:  "http://" + agent,
					Status: "running",
					Start:  time.Now(),
				})
			}
		}
	} else if diff < 0 {
		for i := 0; i < -diff; i++ {
			if len(status.Replicas) == 0 {
				break
			}
			rep := status.Replicas[0]
			status.Replicas = status.Replicas[1:]
			sendStop(rep.Agent, rep.ID)
		}
	}
}

func sendStart(agentAddr string) string {
	resp, err := http.Post("http://"+agentAddr+"/cmd", "application/json",
		strings.NewReader(`{"action":"start"}`))
	if err != nil || resp.StatusCode != 200 {
		return ""
	}
	defer resp.Body.Close()
	var result map[string]string
	json.NewDecoder(resp.Body).Decode(&result)
	return result["id"]
}

func sendStop(agentURL, id string) {
	http.Post(agentURL+"/cmd", "application/json",
		strings.NewReader(fmt.Sprintf(`{"action":"stop","id":"%s"}`, id)))
}
