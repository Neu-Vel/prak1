package common

import "time"

type Replica struct {
    ID     string    `json:"id"`
    Host   string    `json:"host"`
    Port   int       `json:"port"`
    Status string    `json:"status"`
    Start  time.Time `json:"start"`
}

type ClusterStatus struct {
    Replicas []Replica `json:"replicas"`
    Agents   []string  `json:"agents"`
}

type DeployRequest struct {
    ServiceName string `json:"service_name"`
    Replicas    int    `json:"replicas"`
}

type AgentCommand struct {
    Action string `json:"action"`
    ID     string `json:"id,omitempty"`
}