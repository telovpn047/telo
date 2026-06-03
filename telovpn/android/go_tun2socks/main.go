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
	"sync"
	"time"

	"github.com/xjasonlyu/tun2socks/v2/engine"
)

var (
	mu      sync.Mutex
	running bool
)

//export Java_com_telovpn_app_VpnCore_startTun2Socks
func Java_com_telovpn_app_VpnCore_startTun2Socks(env *C.JNIEnv, cls C.jclass, tunFd C.jint, socksPort C.jint) {
	mu.Lock()
	defer mu.Unlock()
	// If engine is still marked running (e.g. previous session wasn't cleaned up),
	// stop it first so Insert+Start start from a clean state.
	if running {
		func() { defer func() { recover() }(); engine.Stop() }()
		time.Sleep(200 * time.Millisecond)
		running = false
	}
	key := engine.Key{
		Proxy:    fmt.Sprintf("socks5://127.0.0.1:%d", int(socksPort)),
		Device:   fmt.Sprintf("fd://%d", int(tunFd)),
		LogLevel: "warning",
		MTU:      1500,
	}
	engine.Insert(&key)
	engine.Start()
	running = true
}

//export Java_com_telovpn_app_VpnCore_stopTun2Socks
func Java_com_telovpn_app_VpnCore_stopTun2Socks(env *C.JNIEnv, cls C.jclass) {
	mu.Lock()
	defer mu.Unlock()
	if !running {
		return // already stopped — don't call engine.Stop() a second time
	}
	running = false
	func() { defer func() { recover() }(); engine.Stop() }()
}

func main() {}
