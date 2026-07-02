package com.example.amn_app

import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService

class AmnInCallService : InCallService() {
    override fun onCreate() {
        super.onCreate()
        CallControlState.attachService(this)
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        CallControlState.attachService(this)
        CallControlState.setCurrentCall(call)
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        CallControlState.updateFromCall(call, Call.STATE_DISCONNECTED)
        CallControlState.setCurrentCall(null)
    }

    override fun onCallAudioStateChanged(audioState: CallAudioState?) {
        super.onCallAudioStateChanged(audioState)
        CallControlState.updateAudioState(audioState)
    }

    override fun onDestroy() {
        CallControlState.detachService(this)
        super.onDestroy()
    }

    fun routeToCarAudio() {
        val supportedRouteMask = callAudioState?.supportedRouteMask ?: 0
        when {
            supportedRouteMask and CallAudioState.ROUTE_BLUETOOTH != 0 -> setAudioRoute(CallAudioState.ROUTE_BLUETOOTH)
            supportedRouteMask and CallAudioState.ROUTE_SPEAKER != 0 -> setAudioRoute(CallAudioState.ROUTE_SPEAKER)
            else -> setAudioRoute(CallAudioState.ROUTE_WIRED_HEADSET)
        }
    }

    fun routeAwayFromCarAudio() {
        val supportedRouteMask = callAudioState?.supportedRouteMask ?: 0
        when {
            supportedRouteMask and CallAudioState.ROUTE_EARPIECE != 0 -> setAudioRoute(CallAudioState.ROUTE_EARPIECE)
            supportedRouteMask and CallAudioState.ROUTE_WIRED_HEADSET != 0 -> setAudioRoute(CallAudioState.ROUTE_WIRED_HEADSET)
            else -> setAudioRoute(CallAudioState.ROUTE_SPEAKER)
        }
    }
}
