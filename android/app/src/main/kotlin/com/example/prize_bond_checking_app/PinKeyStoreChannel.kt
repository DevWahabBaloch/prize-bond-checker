package com.example.prize_bond_checking_app

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey

/** Owns only new PIN keys. Existing FlutterSecureStorage entries are left in their original store. */
internal class PinKeyStoreChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(
        messenger,
        "prize_bond/pin_keystore",
        StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue(),
    )
    private val uuid = Regex("[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}")
    private val pinPattern = Regex("[0-9]{4}")

    init {
        channel.setMethodCallHandler(::handle)
    }

    fun close() = channel.setMethodCallHandler(null)

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val create = when (call.method) {
            "create" -> true
            "read" -> false
            else -> {
                result.notImplemented()
                return
            }
        }
        val accountId = call.argument<String>("accountId")
        val generation = call.argument<String>("generation")
        val pin = call.argument<String>("pin")
        if (accountId == null || generation == null || !uuid.matches(accountId) || !uuid.matches(generation) ||
            (pin != null && !pinPattern.matches(pin)) || (create && pin == null)
        ) {
            result.error("invalid-pin-key-request", null, null)
            return
        }

        val alias = "fyp_pin_hmac_v3_${accountId}_$generation"
        try {
            if (create) {
                // Refuse a collision. The previous verifier's alias stays available even if this write fails.
                check(!openKeyStore().containsAlias(alias))
                val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, PROVIDER)
                generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN).setKeySize(256).build())
                generator.generateKey()
            }

            // Android Keystore stores the generated key under the alias before returning.
            // Open it again through the provider and prove it works before acknowledging creation.
            val key = openKeyStore().getKey(alias, null)
            if (key == null) {
                if (create) result.error("pin-keystore-unavailable", null, null) else result.success(null)
            } else if (key !is SecretKey || !key.algorithm.equals(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, ignoreCase = true)) {
                result.error("invalid-pin-key", null, null)
            } else {
                val proof = mutableMapOf("check" to mac(key, "fyp-pin-key:$accountId:$generation"))
                if (pin != null) proof["pinDigest"] = mac(key, "$accountId:$generation:$pin")
                result.success(proof)
            }
        } catch (_: KeyPermanentlyInvalidatedException) {
            result.error("invalid-pin-key", null, null)
        } catch (_: Exception) {
            result.error("pin-keystore-unavailable", null, null)
        }
    }

    private fun openKeyStore(): KeyStore = KeyStore.getInstance(PROVIDER).apply { load(null) }

    private fun mac(key: SecretKey, message: String): String {
        val mac = Mac.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256)
        mac.init(key)
        return mac.doFinal(message.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    private companion object {
        const val PROVIDER = "AndroidKeyStore"
    }
}
