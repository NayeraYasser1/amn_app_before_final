package com.example.amn_app

import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.util.concurrent.Executors
import kotlin.concurrent.thread

object AndroidCallBridgeServer {
    @Volatile private var running = false
    @Volatile private var serverThread: Thread? = null
    @Volatile private var serverSocket: ServerSocket? = null
    @Volatile private var currentPort: Int = 8765
    @Volatile private var authToken: String = ""

    private val clientPool = Executors.newCachedThreadPool()

    fun start(port: Int, token: String) {
        synchronized(this) {
            if (running && currentPort == port && authToken == token) {
                return
            }
            stop()
            currentPort = port
            authToken = token
            val socket = ServerSocket()
            socket.reuseAddress = true
            socket.bind(InetSocketAddress("0.0.0.0", port))
            serverSocket = socket
            running = true
            serverThread = thread(
                start = true,
                isDaemon = true,
                name = "AMN-AndroidCallBridge",
            ) {
                runServerLoop(socket)
            }
        }
    }

    fun stop() {
        synchronized(this) {
            running = false
            try {
                serverSocket?.close()
            } catch (_: Exception) {
            }
            serverSocket = null
            serverThread?.interrupt()
            serverThread = null
        }
    }

    fun statusMap(): Map<String, Any?> {
        return mapOf(
            "ok" to true,
            "running" to running,
            "port" to currentPort,
            "default_dialer" to AndroidCallController.isDefaultDialer(),
            "permissions_granted" to AndroidCallController.hasRequiredPermissions(),
            "battery_optimization_ignored" to AndroidCallController.isIgnoringBatteryOptimizations(),
            "message" to if (running) {
                "Foreground Android call bridge is running."
            } else {
                "Foreground Android call bridge is stopped."
            },
        )
    }

    private fun runServerLoop(socket: ServerSocket) {
        while (running) {
            try {
                val client = socket.accept()
                clientPool.execute { handleClient(client) }
            } catch (_: SocketException) {
                break
            } catch (_: Exception) {
            }
        }
    }

    private fun handleClient(client: Socket) {
        client.use { socket ->
            socket.soTimeout = 3000
            val reader = BufferedReader(InputStreamReader(socket.getInputStream(), Charsets.UTF_8))
            val requestLine = reader.readLine() ?: return
            val requestParts = requestLine.split(" ")
            if (requestParts.size < 2) {
                writeJson(socket.getOutputStream(), 400, mapOf("ok" to false, "state" to "error", "error" to "Bad request"))
                return
            }

            val method = requestParts[0].uppercase()
            val path = requestParts[1].substringBefore("?")
            val headers = mutableMapOf<String, String>()

            var contentLength = 0
            while (true) {
                val line = reader.readLine() ?: break
                if (line.isBlank()) break
                val separator = line.indexOf(':')
                if (separator <= 0) continue
                val key = line.substring(0, separator).trim().lowercase()
                val value = line.substring(separator + 1).trim()
                headers[key] = value
                if (key == "content-length") {
                    contentLength = value.toIntOrNull() ?: 0
                }
            }

            if (!isAuthorized(headers["authorization"])) {
                writeJson(socket.getOutputStream(), 401, mapOf("ok" to false, "state" to "error", "error" to "Unauthorized"))
                return
            }

            val body = if (contentLength > 0) {
                val buffer = CharArray(contentLength)
                var offset = 0
                while (offset < contentLength) {
                    val read = reader.read(buffer, offset, contentLength - offset)
                    if (read <= 0) break
                    offset += read
                }
                String(buffer, 0, offset)
            } else {
                ""
            }

            val payload = if (body.isBlank()) JSONObject() else JSONObject(body)
            val result = route(method, path, payload)
            val statusCode = (result["http_status"] as? Int) ?: if (result["ok"] == true) 200 else 500
            writeJson(socket.getOutputStream(), statusCode, result)
        }
    }

    private fun route(method: String, path: String, payload: JSONObject): Map<String, Any?> {
        if (method == "GET" && path == "/status") {
            return CallControlState.statusMap()
        }

        if (method != "POST") {
            return mapOf("ok" to false, "state" to "error", "error" to "Route not found", "http_status" to 404)
        }

        return when (path) {
            "/answer" -> CallControlState.answerCall()
            "/reject" -> CallControlState.rejectCall()
            "/end" -> CallControlState.endCall()
            "/mute" -> CallControlState.setMuted(payload.optBoolean("enabled", false))
            "/speaker" -> CallControlState.setSpeaker(payload.optBoolean("enabled", true))
            else -> mapOf("ok" to false, "state" to "error", "error" to "Route not found", "http_status" to 404)
        }
    }

    private fun isAuthorized(headerValue: String?): Boolean {
        if (authToken.isBlank()) {
            return true
        }
        return headerValue == "Bearer $authToken"
    }

    private fun writeJson(output: OutputStream, statusCode: Int, payload: Map<String, Any?>) {
        val json = JSONObject(payload).toString()
        val response = buildString {
            append("HTTP/1.1 $statusCode ${reasonPhrase(statusCode)}\r\n")
            append("Content-Type: application/json; charset=utf-8\r\n")
            append("Content-Length: ${json.toByteArray(Charsets.UTF_8).size}\r\n")
            append("Connection: close\r\n")
            append("\r\n")
            append(json)
        }
        output.write(response.toByteArray(Charsets.UTF_8))
        output.flush()
    }

    private fun reasonPhrase(statusCode: Int): String {
        return when (statusCode) {
            200 -> "OK"
            400 -> "Bad Request"
            401 -> "Unauthorized"
            404 -> "Not Found"
            409 -> "Conflict"
            500 -> "Internal Server Error"
            else -> "OK"
        }
    }
}
