package main

/*
#include <jni.h>
#include <stdlib.h>
*/
import "C"

import (
	"fmt"

	"github.com/xjasonlyu/tun2socks/v2/engine"
)

//export Java_com_telovpn_app_VpnCore_startTun2Socks
func Java_com_telovpn_app_VpnCore_startTun2Socks(env *C.JNIEnv, cls C.jclass, tunFd C.jint, mtu C.jint, proxyUrl *C.char) C.jint {
	engine.Stop()

	key := &engine.Key{
		Device:   fmt.Sprintf("fd://%d", int(tunFd)),
		Proxy:    C.GoString(proxyUrl),
		LogLevel: "warn",
		MTU:      int(mtu),
	}
	engine.Insert(key)
	if err := engine.Start(); err != nil {
		return -1
	}
	return 0
}

//export Java_com_telovpn_app_VpnCore_stopTun2Socks
func Java_com_telovpn_app_VpnCore_stopTun2Socks(env *C.JNIEnv, cls C.jclass) {
	engine.Stop()
}

func main() {}
