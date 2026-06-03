package main

/*
// Minimal JNI type definitions — avoids needing jni.h from NDK sysroot.
typedef void*  JNIEnv;
typedef void*  jclass;
typedef int    jint;
*/
import "C"

import (
	"fmt"

	"github.com/xjasonlyu/tun2socks/v2/engine"
)

//export Java_com_telovpn_app_VpnCore_startTun2Socks
func Java_com_telovpn_app_VpnCore_startTun2Socks(env *C.JNIEnv, cls C.jclass, tunFd C.jint, socksPort C.jint) {
	key := engine.Key{
		Proxy:    fmt.Sprintf("socks5://127.0.0.1:%d", int(socksPort)),
		Device:   fmt.Sprintf("fd://%d", int(tunFd)),
		LogLevel: "warning",
		MTU:      1500,
	}
	engine.Insert(&key)
	engine.Start()
}

//export Java_com_telovpn_app_VpnCore_stopTun2Socks
func Java_com_telovpn_app_VpnCore_stopTun2Socks(env *C.JNIEnv, cls C.jclass) {
	defer func() { recover() }()
	engine.Stop()
}

func main() {}
