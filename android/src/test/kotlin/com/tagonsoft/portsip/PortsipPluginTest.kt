package com.tagonsoft.portsip

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/*
 * Unit tests for the plugin's method-call routing.
 *
 * These run on a plain JVM, with no Android runtime and no PortSIP SDK, so they
 * cover the edges that don't dispatch into PortsipController: the enum that maps
 * Flutter's method-name strings onto handlers, and what happens to a name it
 * doesn't recognise. Anything past that reaches the SDK and belongs in an
 * instrumented test.
 *
 * Run with `./gradlew testDebugUnitTest` in `example/android/`, or from an IDE
 * that supports JUnit.
 */
internal class PortsipPluginTest {

    @Test
    fun onMethodCall_unknownMethod_reportsNotImplemented() {
        val plugin = PortsipPlugin()

        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("noSuchMethod", null), result)

        Mockito.verify(result).notImplemented()
        Mockito.verifyNoMoreInteractions(result)
    }

    @Test
    fun fromMethodName_resolvesEveryDeclaredMethod() {
        // The Dart side addresses these handlers by string. A typo in either
        // enum column is otherwise invisible until the call silently returns
        // MissingPluginException at runtime.
        for (method in PortsipMethodCall.values()) {
            assertEquals(
                method,
                PortsipMethodCall.fromMethodName(method.methodName),
                "${method.name} does not resolve from its own method name"
            )
        }
    }

    @Test
    fun fromMethodName_methodNamesAreUnique() {
        // Two entries sharing a name means one of them is unreachable: the
        // lookup returns whichever comes first in declaration order.
        val duplicates = PortsipMethodCall.values()
            .groupBy { it.methodName }
            .filterValues { it.size > 1 }

        assertEquals(emptyMap(), duplicates, "duplicate method names")
    }

    @Test
    fun fromMethodName_unknownNameIsNull() {
        assertNull(PortsipMethodCall.fromMethodName("noSuchMethod"))
        assertNull(PortsipMethodCall.fromMethodName(""))
    }

    @Test
    fun fromMethodName_pcmRecordingIsWired() {
        assertNotNull(PortsipMethodCall.fromMethodName("startPcmRecord"))
        assertNotNull(PortsipMethodCall.fromMethodName("stopPcmRecord"))
    }
}
