package main

import (
	"os"
	"fmt"

	tea "charm.land/bubbletea/v2"
)

var ALL_CONNECTIONS_FILE string
var CURRENT_CONNECTION_FILE string

type connection struct {
	name   	  string
	username  string
	host      string
	port      int
	password  string
	database  string
	isCurrent bool
}

func (c connection) toString() string {
	return fmt.Sprintf("postgresql://%s:%s@%s:%d/%s", c.username, c.password, c.host, c.port, c.database)
}

func readConnections() ([]connection, error) {
	all_conns_file, err := os.ReadFile(ALL_CONNECTIONS_FILE)
	if err != nil {
		return nil, err
	}

	curr_conn_file, err := os.ReadFile(CURRENT_CONNECTION_FILE)
	if err != nil {
		return nil, err
	}

	if len(all_conns_file) == 0 || len(curr_conn_file) == 0 {
		return []connection{}, nil
	}

	return []connection{}, nil
}

func setup() error {
	if os.Getenv("HOME") == "" {
		return fmt.Errorf("HOME environment variable not set")
	}

	DIR_PATH := os.Getenv("HOME") + "/.local/state/pcm/"
	CURRENT_CONNECTION_FILE := DIR_PATH + "current_connection"
	ALL_CONNECTIONS_FILE := DIR_PATH + "connections"

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

type model struct {
    connections []connection
    cursor   int
    selected int
}

func initialModel() model {
	connections, err := readConnections()
	if err != nil {
		connections = []connection{}
	}

	return model{
		connections: connections,
		selected: 0,
	}
}

func (m model) Init() tea.Cmd {
    return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {

    case tea.KeyPressMsg:
        switch msg.String() {

        case "ctrl+c", "q":
            return m, tea.Quit
        case "up", "k":
            if m.cursor > 0 {
                m.cursor--
            }
        case "down", "j":
            if m.cursor < len(m.connections)-1 {
                m.cursor++
            }
        case "enter", "space":
            m.selected = m.cursor
        }
    }

    return m, nil
}

func (m model) View() tea.View {
    s := "Which connection do you want to select?"

    // Iterate over our choices
    for i, connection := range m.connections {

        cursor := " " // no cursor
        if m.cursor == i {
            cursor = ">" // cursor!
        }

        checked := " "
        if m.selected == i {
            checked = "x" // selected!
        }

        s += fmt.Sprintf("%s [%s] %s\n", cursor, checked, connection)
    }

    s += "\nPress q to quit.\n"
    return tea.NewView(s)
}

func main() {
	setup()

    p := tea.NewProgram(initialModel())
    if _, err := p.Run(); err != nil {
        fmt.Printf("Alas, there's been an error: %v", err)
        os.Exit(1)
    }
}
