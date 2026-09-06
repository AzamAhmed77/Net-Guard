package com.cybnux.net_speed_controller

import android.net.VpnService
import android.util.Log
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class LocalSocks5Server(private val vpnService: VpnService) {
    private val TAG = "LocalSocks5Server"
    private var serverSocket: ServerSocket? = null
    private var executor: ExecutorService? = null
    @Volatile
    private var running = false

    private val activeSockets = ConcurrentHashMap.newKeySet<Socket>()

    private val downloadLimiter = RateLimiter(-1) // -1 = unlimited
    private val uploadLimiter = RateLimiter(-1)

    class RateLimiter(@Volatile var bytesPerSecond: Long) {
        private var tokens: Long = if (bytesPerSecond > 0) bytesPerSecond else 1024 * 1024
        private var lastRefillTime: Long = System.currentTimeMillis()

        @Synchronized
        fun limit(bytes: Int) {
            val limitRate = bytesPerSecond
            if (limitRate < 0) return // Unlimited (< 0)
            if (limitRate == 0L) {
                // 0 KB/s - freeze data transfer completely
                try {
                    Thread.sleep(1000)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                }
                return
            }

            val now = System.currentTimeMillis()
            val elapsedTime = now - lastRefillTime

            if (elapsedTime > 0) {
                val refill = (elapsedTime * limitRate) / 1000
                tokens = Math.min(limitRate * 2, tokens + refill)
                lastRefillTime = now
            }

            tokens -= bytes
            if (tokens < 0) {
                val sleepTime = (-tokens * 1000) / limitRate
                if (sleepTime > 0) {
                    try {
                        Thread.sleep(Math.min(sleepTime, 1000))
                    } catch (e: InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                }
                lastRefillTime = System.currentTimeMillis()
                tokens = 0
            }
        }
    }

    fun setRates(downloadRateBps: Long, uploadRateBps: Long) {
        downloadLimiter.bytesPerSecond = downloadRateBps
        uploadLimiter.bytesPerSecond = uploadRateBps
        Log.i(TAG, "Rates updated: Download=$downloadRateBps Bps, Upload=$uploadRateBps Bps")
    }

    fun start(port: Int) {
        if (running) {
            Log.i(TAG, "SOCKS5 server already running, skipping start")
            return
        }
        running = true
        executor = Executors.newCachedThreadPool()
        executor?.execute {
            try {
                serverSocket = ServerSocket(port, 50, InetAddress.getByName("127.0.0.1"))
                Log.i(TAG, "SOCKS5 server started on port $port")
                while (running) {
                    try {
                        val clientSocket = serverSocket?.accept() ?: break
                        activeSockets.add(clientSocket)
                        executor?.execute {
                            try {
                                handleClient(clientSocket)
                            } catch (e: Exception) {
                                Log.e(TAG, "Unhandled error in client handler: ${e.message}")
                            }
                        }
                    } catch (e: SocketException) {
                        if (running) {
                            Log.e(TAG, "Socket accept error: ${e.message}")
                        }
                        // If not running, this is expected (server socket was closed)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Server socket error: ${e.message}")
                e.printStackTrace()
            }
            Log.i(TAG, "SOCKS5 server accept loop ended")
        }
    }

    fun stop() {
        running = false
        try {
            serverSocket?.close()
        } catch (e: Exception) {
            // ignore
        }
        for (socket in activeSockets) {
            try {
                socket.close()
            } catch (e: Exception) {
                // ignore
            }
        }
        activeSockets.clear()
        executor?.shutdownNow()
        Log.i(TAG, "SOCKS5 server stopped")
    }

    private fun readFully(ins: InputStream, buffer: ByteArray, length: Int) {
        var bytesRead = 0
        while (bytesRead < length) {
            val count = ins.read(buffer, bytesRead, length - bytesRead)
            if (count == -1) throw java.io.EOFException("EOF")
            bytesRead += count
        }
    }

    private fun handleClient(clientSocket: Socket) {
        var targetSocket: Socket? = null
        try {
            clientSocket.soTimeout = 30000 // 30 second timeout
            val clientIn = clientSocket.getInputStream()
            val clientOut = clientSocket.getOutputStream()

            // 1. Handshake greeting
            // Version (1 byte), NMethods (1 byte)
            val header = ByteArray(2)
            readFully(clientIn, header, 2)
            val version = header[0].toInt()
            val nMethods = header[1].toInt()
            if (version != 5) {
                Log.w(TAG, "Non-SOCKS5 connection (version=$version), rejecting")
                clientSocket.close()
                activeSockets.remove(clientSocket)
                return
            }
            val methods = ByteArray(nMethods)
            readFully(clientIn, methods, nMethods)

            // Respond: SOCKS5 (5), No Auth (0)
            clientOut.write(byteArrayOf(5, 0))
            clientOut.flush()

            // 2. Request details
            // Version (1), Cmd (1), Rsv (1), Atype (1)
            val reqHeader = ByteArray(4)
            readFully(clientIn, reqHeader, 4)
            val reqVer = reqHeader[0].toInt()
            val cmd = reqHeader[1].toInt()
            val rsv = reqHeader[2].toInt()
            val atype = reqHeader[3].toInt()

            if (reqVer != 5 || cmd != 1) { // 1 = CONNECT
                // Command not supported
                Log.w(TAG, "Unsupported SOCKS5 command: ver=$reqVer cmd=$cmd")
                clientOut.write(byteArrayOf(5, 7, 0, 1, 0, 0, 0, 0, 0, 0))
                clientSocket.close()
                activeSockets.remove(clientSocket)
                return
            }

            var destHost = ""
            when (atype) {
                1 -> { // IPv4
                    val ipv4 = ByteArray(4)
                    readFully(clientIn, ipv4, 4)
                    destHost = InetAddress.getByAddress(ipv4).hostAddress ?: ""
                }
                3 -> { // Domain name
                    val len = clientIn.read()
                    if (len == -1) throw java.io.EOFException("EOF")
                    val hostBytes = ByteArray(len)
                    readFully(clientIn, hostBytes, len)
                    destHost = String(hostBytes)
                }
                4 -> { // IPv6
                    val ipv6 = ByteArray(16)
                    readFully(clientIn, ipv6, 16)
                    destHost = InetAddress.getByAddress(ipv6).hostAddress ?: ""
                }
                else -> {
                    // Address type not supported
                    clientOut.write(byteArrayOf(5, 8, 0, 1, 0, 0, 0, 0, 0, 0))
                    clientSocket.close()
                    activeSockets.remove(clientSocket)
                    return
                }
            }

            val portBytes = ByteArray(2)
            readFully(clientIn, portBytes, 2)
            val destPort = ((portBytes[0].toInt() and 0xff) shl 8) or (portBytes[1].toInt() and 0xff)

            Log.d(TAG, "CONNECT request to $destHost:$destPort (atype=$atype)")

            // Connect to remote target
            try {
                targetSocket = Socket()
                targetSocket.soTimeout = 30000

                // CRITICAL: Protect the outgoing socket so its traffic
                // bypasses the VPN TUN interface and goes directly to the network.
                // Without this, the outgoing connection would re-enter the TUN,
                // causing an infinite routing loop.
                if (!vpnService.protect(targetSocket)) {
                    Log.e(TAG, "Failed to protect target socket to $destHost:$destPort")
                }

                targetSocket.connect(InetSocketAddress(destHost, destPort), 10000)
                Log.d(TAG, "Connected to target $destHost:$destPort")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to connect to $destHost:$destPort: ${e.message}")
                // Host unreachable
                clientOut.write(byteArrayOf(5, 4, 0, 1, 0, 0, 0, 0, 0, 0))
                clientSocket.close()
                activeSockets.remove(clientSocket)
                return
            }

            activeSockets.add(targetSocket)

            // Respond success
            // SOCKS5 (5), Success (0), Rsv (0), Atype IPv4 (1), BND ADDR (4 bytes 0), BND PORT (2 bytes 0)
            clientOut.write(byteArrayOf(5, 0, 0, 1, 0, 0, 0, 0, 0, 0))
            clientOut.flush()

            // 3. Bidirectional data transfer with rate limiting
            val targetIn = targetSocket.getInputStream()
            val targetOut = targetSocket.getOutputStream()

            val finalTargetSocket = targetSocket

            // Client -> Target (Upload)
            val uploadJob = Thread {
                try {
                    val buffer = ByteArray(16384)
                    var bytesRead: Int
                    while (running && !clientSocket.isClosed && !finalTargetSocket.isClosed) {
                        bytesRead = clientIn.read(buffer)
                        if (bytesRead == -1) break
                        if (bytesRead > 0) {
                            uploadLimiter.limit(bytesRead)
                            targetOut.write(buffer, 0, bytesRead)
                            targetOut.flush()
                        }
                    }
                } catch (e: Exception) {
                    // Connection closed or error
                } finally {
                    closeSockets(clientSocket, finalTargetSocket)
                }
            }

            // Target -> Client (Download)
            val downloadJob = Thread {
                try {
                    val buffer = ByteArray(16384)
                    var bytesRead: Int
                    while (running && !clientSocket.isClosed && !finalTargetSocket.isClosed) {
                        bytesRead = targetIn.read(buffer)
                        if (bytesRead == -1) break
                        if (bytesRead > 0) {
                            downloadLimiter.limit(bytesRead)
                            clientOut.write(buffer, 0, bytesRead)
                            clientOut.flush()
                        }
                    }
                } catch (e: Exception) {
                    // Connection closed or error
                } finally {
                    closeSockets(clientSocket, finalTargetSocket)
                }
            }

            uploadJob.start()
            downloadJob.start()

        } catch (e: Exception) {
            Log.e(TAG, "Error handling SOCKS client: ${e.message}")
            try { clientSocket.close() } catch (ex: Exception) {}
            try { targetSocket?.close() } catch (ex: Exception) {}
            activeSockets.remove(clientSocket)
            if (targetSocket != null) activeSockets.remove(targetSocket)
        }
    }

    private fun closeSockets(s1: Socket, s2: Socket) {
        try { s1.close() } catch (e: Exception) {}
        try { s2.close() } catch (e: Exception) {}
        activeSockets.remove(s1)
        activeSockets.remove(s2)
    }
}
