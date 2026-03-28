package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
)

var ALL_CONNECTIONS_FILE string
var CURRENT_CONNECTION_FILE string

type connection struct {
	Name     string `json:"name"`
	Username string `json:"username"`
	Host     string `json:"host"`
	Port     int    `json:"port"`
	Password string `json:"password"`
	Database string `json:"database"`
}

type JsonData struct {
	Connections []connection `json:"connections"`
}

func (c connection) toString() string {
	return fmt.Sprintf("postgresql://%s:%s@%s:%d/%s", c.Username, c.Password, c.Host, c.Port, c.Database)
}

func readConnections() ([]connection, error) {
	allConnFile, err := os.ReadFile(ALL_CONNECTIONS_FILE)
	if err != nil {
		return nil, fmt.Errorf("error opening all connections file: %w", err)
	}

	if len(allConnFile) == 0 {
		return []connection{}, nil
	}

	var payload JsonData
	if err := json.Unmarshal(allConnFile, &payload); err != nil {
		return nil, err
	}

	return payload.Connections, nil
}

func currentConnection() string {
	data, err := os.ReadFile(CURRENT_CONNECTION_FILE)
	if err != nil || len(data) == 0 {
		return ""
	}
	parts := strings.SplitN(strings.TrimSpace(string(data)), "=", 2)
	if len(parts) == 2 {
		return parts[1]
	}
	return ""
}

func writeConnections(conns []connection) error {
	payload := JsonData{Connections: conns}
	data, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(ALL_CONNECTIONS_FILE, data, 0644)
}

func setCurrentConnection(conn connection) error {
	content := "PSQL_CONNECTION=" + conn.toString()

	return os.WriteFile(CURRENT_CONNECTION_FILE, []byte(content), 0644)
}

func prompt(scanner *bufio.Scanner, label string) string {
	fmt.Printf("%s: ", label)
	scanner.Scan()
	return strings.TrimSpace(scanner.Text())
}

func setup() error {
	if os.Getenv("HOME") == "" {
		return fmt.Errorf("HOME environment variable not set")
	}

	DIR_PATH := os.Getenv("HOME") + "/.local/state/pcm/"
	CURRENT_CONNECTION_FILE = DIR_PATH + "current_connection"
	ALL_CONNECTIONS_FILE = DIR_PATH + "connections.json"

	_, err := os.Stat(DIR_PATH)
	if err != nil {
		if os.IsNotExist(err) {
			os.MkdirAll(DIR_PATH, 0755)
		} else {
			return err
		}
	}
	_, err = os.Stat(CURRENT_CONNECTION_FILE)
	if err != nil {
		if os.IsNotExist(err) {
			os.Create(CURRENT_CONNECTION_FILE)
		} else {
			return err
		}
	}
	_, err = os.Stat(ALL_CONNECTIONS_FILE)
	if err != nil {
		if os.IsNotExist(err) {
			os.Create(ALL_CONNECTIONS_FILE)
		} else {
			return err
		}
	}

	return nil
}

func cmdAdd() error {
	scanner := bufio.NewScanner(os.Stdin)

	name := prompt(scanner, "Name")
	username := prompt(scanner, "Username")
	host := prompt(scanner, "Host")
	portStr := prompt(scanner, "Port")
	password := prompt(scanner, "Password")
	database := prompt(scanner, "Database")

	port, err := strconv.Atoi(portStr)
	if err != nil {
		return fmt.Errorf("invalid port: %s", portStr)
	}

	conn := connection{
		Name:     name,
		Username: username,
		Host:     host,
		Port:     port,
		Password: password,
		Database: database,
	}

	conns, err := readConnections()
	if err != nil {
		return err
	}

	conns = append(conns, conn)
	if err := writeConnections(conns); err != nil {
		return err
	}

	if err := setCurrentConnection(conn); err != nil {
		return err
	}

	fmt.Printf("Connection '%s' added and set as current.\n", conn.Name)
	return nil
}

func cmdList() error {
	conns, err := readConnections()
	if err != nil {
		return err
	}

	if len(conns) == 0 {
		fmt.Println("No connections found.")
		return nil
	}

	current := currentConnection()
	for i, c := range conns {
		marker := "  "
		if c.toString() == current {
			marker = "* "
		}
		fmt.Printf("%s%d. %s (%s@%s:%d/%s)\n", marker, i+1, c.Name, c.Username, c.Host, c.Port, c.Database)
	}
	return nil
}

func cmdRemove() error {
	conns, err := readConnections()
	if err != nil {
		return err
	}

	if len(conns) == 0 {
		fmt.Println("No connections to remove.")
		return nil
	}

	current := currentConnection()
	fmt.Println("Select a connection to remove:")
	for i, c := range conns {
		marker := "  "
		if c.toString() == current {
			marker = "* "
		}
		fmt.Printf("%s%d. %s (%s@%s:%d/%s)\n", marker, i+1, c.Name, c.Username, c.Host, c.Port, c.Database)
	}

	scanner := bufio.NewScanner(os.Stdin)
	choice := prompt(scanner, "Enter number")
	idx, err := strconv.Atoi(choice)
	if err != nil || idx < 1 || idx > len(conns) {
		return fmt.Errorf("invalid selection: %s", choice)
	}

	removed := conns[idx-1]
	conns = append(conns[:idx-1], conns[idx:]...)

	if err := writeConnections(conns); err != nil {
		return err
	}

	// If removed connection was current, clear or update current
	if removed.toString() == current {
		if len(conns) > 0 {
			if err := setCurrentConnection(conns[0]); err != nil {
				return err
			}
			fmt.Printf("Connection '%s' removed. Current set to '%s'.\n", removed.Name, conns[0].Name)
		} else {
			if err := os.WriteFile(CURRENT_CONNECTION_FILE, []byte{}, 0644); err != nil {
				return err
			}
			fmt.Printf("Connection '%s' removed. No connections remaining.\n", removed.Name)
		}
	} else {
		fmt.Printf("Connection '%s' removed.\n", removed.Name)
	}

	return nil
}

func cmdSet() error {
	conns, err := readConnections()
	if err != nil {
		return err
	}

	if len(conns) == 0 {
		fmt.Println("No connections to set as current.")
		return nil
	}

	current := currentConnection()
	fmt.Println("Select a connection to set as current:")
	for i, c := range conns {
		marker := "  "
		if c.toString() == current {
			marker = "* "
		}
		fmt.Printf("%s%d. %s (%s@%s:%d/%s)\n", marker, i+1, c.Name, c.Username, c.Host, c.Port, c.Database)
	}

	scanner := bufio.NewScanner(os.Stdin)
	choice := prompt(scanner, "Enter number")
	idx, err := strconv.Atoi(choice)
	if err != nil || idx < 1 || idx > len(conns) {
		return fmt.Errorf("invalid selection: %s", choice)
	}

	if err := setCurrentConnection(conns[idx-1]); err != nil {
		return err
	}

	fmt.Printf("Current connection set to '%s'.\n", conns[idx-1].Name)
	return nil
}

func main() {
	if err := setup(); err != nil {
		fmt.Println("Setup error:", err)
		os.Exit(1)
	}

	args := os.Args[1:]

	if len(args) != 1 {
		fmt.Println("Usage: pcm [list | add | remove | set]")
		os.Exit(1)
	}

	var err error
	switch args[0] {
	case "list":
		err = cmdList()
	case "add":
		err = cmdAdd()
	case "remove":
		err = cmdRemove()
	case "set":
		err = cmdSet()
	default:
		fmt.Printf("Unknown command: %s\n", args[0])
		fmt.Println("Usage: pcm [list | add | remove | set]")
		os.Exit(1)
	}

	if err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
}
