package main

import "core:fmt"
import "core:os"
import "core:crypto"
import "core:strings"
import "core:sys/posix"

main :: proc() {
    if len(os.args) == 1 {
        print_command_help()
    }

    switch os.args[1] {
        case "add":
            add_new_postgres_connection()
        case "remove":
            fmt.println("removing postgres connection")
        case "list":
            fmt.println("listing all postgres connections")
        case:
            print_command_help()
    }
}

print_command_help :: proc() {
    fmt.println("Wrong usage of the command")
}

add_new_postgres_connection :: proc() {
    fmt.println("Adding new postgres connection")
    buff: [256]byte

    connection_name: string
    {
        fmt.print("Enter the name of the connection name: ")
        n, err := os.read(os.stdin, buff[:])
        if err != nil {
            fmt.panicf("Error reading connection name from stdin")
        }
        connection_name = strings.clone(string(buff[:n-1]))
    }

    host: string
    {
        fmt.print("Host: ")
        n, err := os.read(os.stdin, buff[:])
        if err != nil {
            fmt.panicf("Error reading host from stdin")
        }
        host = strings.clone(string(buff[:n-1]))
    }

    port: string
    {
        fmt.print("Port: ")
        n, err := os.read(os.stdin, buff[:])
        if err != nil {
            fmt.panicf("Error reading port from stdin")
        }
        port = strings.clone(string(buff[:n-1]))
    }

    database_name: string
    {
        fmt.print("Database name: ")
        n, err := os.read(os.stdin, buff[:])
        if err != nil {
            fmt.panicf("Error reading database_name from stdin")
        }
        database_name = strings.clone(string(buff[:n-1]))
    }

    username: string
    {
        fmt.print("Username: ")
        n, err := os.read(os.stdin, buff[:])
        if err != nil {
            fmt.panicf("Error reading username from stdin")
        }
        username = strings.clone(string(buff[:n-1]))
    }

    password: string
    {
        fmt.print("Password: ")
        password = read_password()
        fmt.println()
    }

    fmt.printf("postgres://%s:%s@%s:%s/%s\n", username, password, host, port, database_name)
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
