package com.telovpn.app

object VpnCore {
    init {
        System.loadLibrary("vpncore")
    }

    external fun startTun2Socks(tunFd: Int, mtu: Int, proxy: String): Int
    external fun stopTun2Socks()
}
