package main

import "core:fmt"
import "core:os"
import "core:crypto"
import "core:strings"
import "core:sys/posix"

DIR_PATH: string
CURRENT_CONNECTION_FILE: string
ALL_CONNECTIONS_FILE: string

main :: proc() {
    if len(os.args) == 1 {
        print_command_help()
        return
    }

    setup()
    read_conns()

    switch os.args[1] {
        case "add":
            add_new_postgres_conn()
        case "remove":
            remove_postgres_conn(os.args)
        case "list":
            list_all_postgres_conns()
        case "set":
            set_postgres_conn(os.args)
        case:
            print_command_help()
    }
}

setup :: proc() {
    if os.get_env("HOME") == "" {
        fmt.panicf("HOME environment variable not set")
    }

    DIR_PATH = strings.concatenate({os.get_env("HOME"), "/.pcm/"})
    CURRENT_CONNECTION_FILE = strings.concatenate({DIR_PATH, "current_connection"})
    ALL_CONNECTIONS_FILE = strings.concatenate({DIR_PATH, "connections"})

    if !os.exists(DIR_PATH) {
        md_err := os.make_directory(DIR_PATH)
        if md_err != nil {
            fmt.panicf("Error creating directory: %s", md_err)
        }
    }
}

print_command_help :: proc() {
    fmt.println("Wrong usage of the command")
}

add_new_postgres_conn :: proc() {
    fmt.println("Adding new postgres connection")

    fmt.print("Enter the name of the connection: ")
    conn_name: string = read_input()

    for conn in conns {
        if conn.name == conn_name {
            fmt.println("Connection with this name already exists")
            return;
        }
    }

    fmt.print("Host: ")
    host: string = read_input()

    fmt.print("Port: ")
    port: string = read_input()

    fmt.print("Database name: ")
    database_name: string = read_input()

    fmt.print("Username: ")
    username: string = read_input()

    fmt.print("Password: ")
    password: string = read_password()
    fmt.println()

    conn_sb: strings.Builder
    fmt.sbprintf(&conn_sb, "postgres://%s:%s@%s:%s/%s", username, password, host, port, database_name)

    add_conn(conn_name, strings.to_string(conn_sb))

    fmt.println("Connection added successfully")
}

list_all_postgres_conns :: proc() {
    if len(conns) == 0 {
        fmt.println("Empty list of connections")
    }

    fmt.println("Saved connections:")
    for conn, i in conns {
        if curr_conn_index == i {
            fmt.println(strings.concatenate({" - ", conn.name, " (", conn.conn, ")", " [current]"}))
        } else {
            fmt.println(strings.concatenate({" - ", conn.name, " (", conn.conn, ")"}))
        }
    }
}

remove_postgres_conn :: proc(args: []string) {
    if len(args) != 3 {
        print_command_help()
        return
    }

    err := remove_conn(args[2])
    if err != nil {
        fmt.panicf("Connection not found")
    }
}

set_postgres_conn :: proc(args: []string) {
    if len(args) != 3 {
        print_command_help()
        return
    }

    err := set_conn(args[2])
    if err != nil {
        fmt.panicf("Connection not found")
    }
}

read_input :: proc() -> string {
    buff: [256]byte
    n, err := os.read(os.stdin, buff[:])
    if err != nil {
        fmt.panicf("Error reading input from stdin: %s", err)
    }
    return strings.clone(string(buff[:n-1]))
}

read_password :: proc() -> string {
    // read terminal attributes
    old_terminal: posix.termios
    posix.tcgetattr(posix.STDIN_FILENO, &old_terminal)
    new_terminal := old_terminal

    // set the appropriate bit in the termios stuct
    new_terminal.c_lflag &= ~{.ECHO}

    // saving the new bits and defering the old terminal bits
    posix.tcsetattr(posix.STDIN_FILENO, posix.TC_Optional_Action.TCSANOW, &new_terminal)
    defer posix.tcsetattr(posix.STDIN_FILENO, posix.TC_Optional_Action.TCSANOW, &old_terminal)

    // reading the password from console
    buff: [256]byte
    n, err := os.read(os.stdin, buff[:])
    if err != nil {
        fmt.panicf("Error reading password from stdin")
    }

    return strings.clone(string(buff[:n-1]))
}
