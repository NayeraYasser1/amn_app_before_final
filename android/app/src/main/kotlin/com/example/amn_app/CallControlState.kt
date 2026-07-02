package com.example.amn_app

import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.DisconnectCause
import android.telecom.InCallService
import android.telecom.VideoProfile

object CallControlState {
    private var activeCall: Call? = null
    var currentService: AmnInCallService? = null
    var lastState: String = "idle"
    var callerName: String = ""
    var callerNumber: String = ""
    var muted: Boolean = false
    var speakerOn: Boolean = true
    var bluetoothAudio: Boolean = false
    var startedAtMillis: Long = 0L

    private val callback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            updateFromCall(call, state)
        }

        override fun onDetailsChanged(call: Call, details: Call.Details) {
            updateCallerDetails(call)
        }
    }

    fun attachService(service: AmnInCallService) {
        currentService = service
        muted = service.callAudioState?.isMuted ?: muted
        bluetoothAudio = (service.callAudioState?.route ?: 0 and CallAudioState.ROUTE_BLUETOOTH) != 0
        speakerOn = (service.callAudioState?.route ?: 0 and CallAudioState.ROUTE_SPEAKER) != 0
    }

    fun detachService(service: AmnInCallService) {
        if (currentService === service) {
            currentService = null
        }
    }

    fun setCurrentCall(call: Call?) {
        activeCall?.unregisterCallback(callback)
        activeCall = call
        if (call == null) {
            if (lastState == "active" || lastState == "ringing") {
                lastState = "ended"
            }
            startedAtMillis = 0L
            callerName = ""
            callerNumber = ""
            return
        }
        call.registerCallback(callback)
        updateCallerDetails(call)
        updateFromCall(call, call.state)
    }

    fun updateCallerDetails(call: Call) {
        val details = call.details
        callerName = details.callerDisplayName ?: ""
        callerNumber = details.handle?.schemeSpecificPart ?: ""
        if (callerName.isBlank()) {
            callerName = if (callerNumber.isNotBlank()) callerNumber else "Android Call"
        }
    }

    fun updateFromCall(call: Call, state: Int) {
        updateCallerDetails(call)
        lastState = when (state) {
            Call.STATE_RINGING -> "ringing"
            Call.STATE_ACTIVE, Call.STATE_CONNECTING, Call.STATE_DIALING, Call.STATE_HOLDING -> "active"
            Call.STATE_DISCONNECTED -> mapDisconnectState(call)
            else -> if (activeCall == null) "idle" else lastState
        }
        if (lastState == "active" && startedAtMillis == 0L) {
            startedAtMillis = System.currentTimeMillis()
        }
        if (lastState != "active" && state == Call.STATE_DISCONNECTED) {
            startedAtMillis = 0L
        }
    }

    private fun mapDisconnectState(call: Call): String {
        return when (call.details.disconnectCause?.code) {
            DisconnectCause.MISSED -> "missed"
            DisconnectCause.REJECTED -> "rejected"
            else -> "ended"
        }
    }

    fun updateAudioState(audioState: CallAudioState?) {
        if (audioState == null) {
            return
        }
        muted = audioState.isMuted
        bluetoothAudio = (audioState.route and CallAudioState.ROUTE_BLUETOOTH) != 0
        speakerOn = (audioState.route and CallAudioState.ROUTE_SPEAKER) != 0
    }

    fun statusMap(additionalMessage: String? = null): Map<String, Any?> {
        val elapsedSeconds = if (lastState == "active" && startedAtMillis > 0L) {
            ((System.currentTimeMillis() - startedAtMillis) / 1000L).toInt()
        } else {
            0
        }
        return mapOf(
            "ok" to true,
            "state" to lastState,
            "platform" to "android",
            "caller_name" to callerName,
            "caller_number" to callerNumber,
            "elapsed_seconds" to elapsedSeconds,
            "muted" to muted,
            "speaker_on" to speakerOn,
            "bluetooth_audio" to bluetoothAudio,
            "message" to (additionalMessage ?: statusMessage()),
            "default_dialer" to AndroidCallController.isDefaultDialer(),
            "permissions_granted" to AndroidCallController.hasRequiredPermissions(),
            "http_status" to 200,
        )
    }

    private fun statusMessage(): String {
        if (!AndroidCallController.hasRequiredPermissions()) {
            return "Android call permissions are not granted yet."
        }
        if (!AndroidCallController.isDefaultDialer()) {
            return "AMN is not the default dialer yet. Grant the dialer role on Android."
        }
        return when (lastState) {
            "ringing" -> "Incoming call detected on Android companion."
            "active" -> "Call is active."
            "ended" -> "Call ended."
            "missed" -> "Call was missed."
            "rejected" -> "Call was rejected."
            else -> "No active call."
        }
    }

    fun answerCall(): Map<String, Any?> {
        val prerequisiteError = validatePrerequisites()
        if (prerequisiteError != null) return prerequisiteError
        val call = activeCall
            ?: return errorMap("No ringing call to answer", 409, "idle")
        if (call.state != Call.STATE_RINGING) {
            return errorMap("No ringing call to answer", 409, lastState)
        }
        call.answer(VideoProfile.STATE_AUDIO_ONLY)
        if (startedAtMillis == 0L) {
            startedAtMillis = System.currentTimeMillis()
        }
        lastState = "active"
        return statusMap("Call answered successfully.")
    }

    fun rejectCall(): Map<String, Any?> {
        val prerequisiteError = validatePrerequisites()
        if (prerequisiteError != null) return prerequisiteError
        val call = activeCall
            ?: return errorMap("No ringing call to reject", 409, "idle")
        if (call.state != Call.STATE_RINGING) {
            return errorMap("No ringing call to reject", 409, lastState)
        }
        call.reject(false, null)
        lastState = "rejected"
        startedAtMillis = 0L
        return statusMap("Call rejected successfully.")
    }

    fun endCall(): Map<String, Any?> {
        val prerequisiteError = validatePrerequisites()
        if (prerequisiteError != null) return prerequisiteError
        val call = activeCall
            ?: return errorMap("Cannot end call because no active call exists", 409, "idle")
        if (call.state == Call.STATE_DISCONNECTED) {
            return errorMap("Cannot end call because no active call exists", 409, "idle")
        }
        call.disconnect()
        lastState = "ended"
        startedAtMillis = 0L
        return statusMap("Call ended successfully.")
    }

    fun setMuted(enabled: Boolean): Map<String, Any?> {
        val prerequisiteError = validatePrerequisites()
        if (prerequisiteError != null) return prerequisiteError
        val service = currentService
            ?: return errorMap("InCallService is not bound yet.", 409, lastState)
        service.setMuted(enabled)
        muted = enabled
        return statusMap("Mute state updated.")
    }

    fun setSpeaker(enabled: Boolean): Map<String, Any?> {
        val prerequisiteError = validatePrerequisites()
        if (prerequisiteError != null) return prerequisiteError
        val service = currentService
            ?: return errorMap("InCallService is not bound yet.", 409, lastState)
        if (enabled) {
            service.routeToCarAudio()
        } else {
            service.routeAwayFromCarAudio()
        }
        speakerOn = enabled
        bluetoothAudio = enabled
        return statusMap("Speaker state updated.")
    }

    fun errorMap(message: String, httpStatus: Int = 500, state: String = "error"): Map<String, Any?> {
        return mapOf(
            "ok" to false,
            "state" to state,
            "error" to message,
            "http_status" to httpStatus,
        )
    }

    private fun validatePrerequisites(): Map<String, Any?>? {
        if (!AndroidCallController.hasRequiredPermissions()) {
            return errorMap("Required Android call permissions are not granted yet.", 409, "error")
        }
        if (!AndroidCallController.isDefaultDialer()) {
            return errorMap("AMN must be the default dialer before call controls can work.", 409, "error")
        }
        return null
    }
}
