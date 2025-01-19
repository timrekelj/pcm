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
    setup()

    if len(os.args) == 1 {
        print_command_help()
    }

    switch os.args[1] {
        case "add":
            add_new_postgres_conn()
        case "remove":
            fmt.println("removing postgres connection")
        case "list":
            list_all_postgres_conns()
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
    conn_str: string = strings.to_string(conn_sb)

    write_new_conn(conn_name, conn_str)
    set_curr_conn(conn_str)

    fmt.println("Connection added successfully")
}

list_all_postgres_conns :: proc() {
    if !os.exists(ALL_CONNECTIONS_FILE) || !os.exists(CURRENT_CONNECTION_FILE) {
        fmt.panicf("Files do not exist")
    }

    all_conns_file, all_conns_err := os.read_entire_file_or_err(ALL_CONNECTIONS_FILE)
    if all_conns_err != nil {
        fmt.panicf("Error reading the file: %s", all_conns_err)
    }

    curr_conn_file, curr_conn_err := os.read_entire_file_or_err(CURRENT_CONNECTION_FILE)
    if curr_conn_err != nil {
        fmt.panicf("Error reading the file: %s", curr_conn_file)
    }

    curr_conn := strings.split(string(curr_conn_file), "\n")[0]
    curr_conn = strings.split(curr_conn, "=")[1]

    fmt.println("Saved connections:")
    for line in strings.split(string(all_conns_file), "\n") {
        if len(line) == 0 {
            continue
        }

        conn, split_err := strings.split(line, "=")
        if split_err != nil {
            fmt.panicf("Error splitting the line: %s", split_err)
        }

        if strings.compare(conn[1], curr_conn) == 0 {
            fmt.println(strings.concatenate({" - ", conn[0], " (", conn[1], ")", " [current]"}))
        } else {
            fmt.println(strings.concatenate({" - ", conn[0], " (", conn[1], ")"}))
        }
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

write_new_conn :: proc(conn_name: string, conn_str: string) {
    conn: string = strings.concatenate({conn_name, "=", conn_str, "\n"})
    conn_bytes: []byte = transmute([]u8)conn

    file, err := os.open(ALL_CONNECTIONS_FILE, os.O_RDWR | os.O_APPEND | os.O_CREATE, 0o644)
    if err != nil {
        fmt.panicf("Error writing to the file: %s", err)
    }
    defer os.close(file)

    _, err = os.write(file, conn_bytes)
    if err != nil {
        fmt.panicf("Error writing to the file: %s", err)
    }
}

set_curr_conn :: proc(conn_str: string) {
    conn: string = strings.concatenate({"PSQL_CONNECTION=", conn_str, "\n"})
    conn_bytes: []byte = transmute([]u8)conn

    file, err := os.open(CURRENT_CONNECTION_FILE, os.O_RDWR | os.O_CREATE, 0o644)
    if err != nil {
        fmt.panicf("Error writing to the file: %s", err)
    }
    defer os.close(file)

    _, err = os.write(file, conn_bytes)
    if err != nil {
        fmt.panicf("Error writing to the file: %s", err)
    }
}
