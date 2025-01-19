package main

import "core:strings"
import "core:fmt"
import "core:os"

Connection :: struct {
    name: string,
    conn: string,
    is_curr: bool
}

conns: [dynamic]Connection

AddConnectionErr :: enum {
    NAME_EXISTS,
    CONN_EXISTS
}

RemoveConnectionErr :: enum {
    CONN_NOT_FOUND
}

reset_all_conns :: proc() {
    for &conn in conns {
        conn.is_curr = false
    }
}

add_conn :: proc(name: string, conn: string) -> AddConnectionErr {
    for c in conns {
        if strings.compare(c.name, name) == 0 {
            return .NAME_EXISTS
        } else if strings.compare(c.conn, conn) == 0 {
            return .CONN_EXISTS
        }
    }

    reset_all_conns()

    append(&conns, Connection{ name, conn, true })

    return nil
}

remove_conn :: proc(name: string) -> RemoveConnectionErr {
    for c, i in conns {
        if strings.compare(c.name, name) == 0 {
            if c.is_curr {
                ordered_remove(&conns, i)
                conns[0].is_curr = true
                write_curr_conn()
            } else {
                ordered_remove(&conns, i)
            }
            write_conns()
            return nil
        }
    }

    return .CONN_NOT_FOUND
}

write_conns :: proc() {
    output_str: strings.Builder

    for conn in conns {
        fmt.sbprintf(&output_str, "%s=%s\n", conn.name, conn.conn)
    }

    conn_bytes: []byte = transmute([]u8)strings.to_string(output_str)

    err := os.write_entire_file_or_err(ALL_CONNECTIONS_FILE, conn_bytes)
    if err != nil {
        fmt.panicf("Error writing to the file: %s", err)
    }
}

write_curr_conn :: proc() {
    for conn in conns {
        if conn.is_curr {
            conn_str: string = strings.concatenate({"PSQL_CONNECTION=", conn.conn, "\n"})
            conn_bytes: []byte = transmute([]u8)conn_str

            err := os.write_entire_file_or_err(CURRENT_CONNECTION_FILE, conn_bytes)
            if err != nil {
                fmt.panicf("Error writing to the file: %s", err)
            }
        }
    }
}

read_conns :: proc() {
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

    for line in strings.split(string(all_conns_file), "\n") {
        if len(line) == 0 { continue }

        conn, split_err := strings.split(line, "=")
        if split_err != nil {
            fmt.panicf("Error splitting the line: %s", split_err)
        }

        if strings.compare(conn[1], curr_conn) == 0 {
            append(&conns, Connection{ conn[0], conn[1], true })
        } else {
            append(&conns, Connection{ conn[0], conn[1], false })
        }
    }
}
