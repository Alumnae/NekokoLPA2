package ee.nekoko.nlpa2

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.os.Looper
import android.os.Process
import kotlin.system.exitProcess

/**
 * The entry point a person runs over ADB.
 *
 * `adb shell` can start a process as the `shell` user, which the platform
 * trusts with the card operations the app is not allowed to do. The app shows a
 * command that loads its own code and runs this `main` in such a process:
 *
 *     CLASSPATH=$(pm path <pkg> | sed -n 's/^package://p' | head -n1) \
 *         app_process / ee.nekoko.nlpa2.AdbBridgeStarter <pkg>
 *
 * The command carries no secret and downloads nothing; it resolves the
 * installed APK by package each time. The one argument is the running package,
 * which names the app's provider ([AdbBridgeProvider]).
 *
 * This process builds a system context, asks the provider for the nonce of the
 * connection window the app has open, and hands over an [AdbBridgeServer] with
 * that nonce. The app checks that the caller really is `shell` before it takes
 * the binder. Then the process stays, serving the app's calls, until the app
 * stops it or the window is closed.
 */
class AdbBridgeStarter {
    companion object {
        @JvmStatic
        fun main(args: Array<String>) {
            val packageName = args.firstOrNull()
            if (packageName.isNullOrBlank()) {
                fail("Run the command the app shows; it names the package to connect to.", 1)
            }

            val context = systemContext()
            val authority = packageName + AdbBridgeProvider.AUTHORITY_SUFFIX
            val uri = Uri.parse("content://$authority")

            val acquired = try {
                context.contentResolver.call(uri, AdbBridgeProvider.METHOD_ACQUIRE, null, null)
            } catch (e: Throwable) {
                fail("Could not reach the app. Is it installed and open? (${e.message})", 2)
            }

            val protocol = acquired?.getInt(AdbBridgeProvider.KEY_PROTOCOL, -1) ?: -1
            if (protocol != AdbBridgeHub.PROTOCOL_VERSION) {
                fail(
                    "This command and the installed app disagree on version " +
                        "($protocol vs ${AdbBridgeHub.PROTOCOL_VERSION}). Update both.",
                    3,
                )
            }

            val nonce = acquired?.getString(AdbBridgeProvider.KEY_NONCE)
            if (nonce.isNullOrBlank()) {
                fail(
                    "No connection is waiting. Open \"Connect using computer\" in the app, " +
                        "then run this within the time it shows.",
                    4,
                )
            }

            val server = AdbBridgeServer(context)
            val registration = Bundle().apply {
                putString(AdbBridgeProvider.KEY_NONCE, nonce)
                putBinder(AdbBridgeProvider.KEY_BINDER, server.asBinder())
            }

            val answer = try {
                context.contentResolver.call(
                    uri,
                    AdbBridgeProvider.METHOD_REGISTER,
                    null,
                    registration,
                )
            } catch (e: Throwable) {
                fail("Handing the connection over failed (${e.message}).", 5)
            }

            if (answer?.getBoolean(AdbBridgeProvider.KEY_OK, false) != true) {
                fail(
                    "The app did not accept this connection. It may have timed out; " +
                        "start the connection again from the app.",
                    6,
                )
            }

            println(
                "Connected to the app as shell (uid ${Process.myUid()}). " +
                    "Keep this window open — closing it disconnects.",
            )
            Looper.loop()
        }

        /** Called by the server when the app asks the helper to stop. */
        fun stop() {
            exitProcess(0)
        }

        /**
         * Build a context for a process that the app framework did not start.
         *
         * `ActivityThread.systemMain()` attaches this thread the way a system
         * process is attached and prepares its main looper, which [main] then
         * runs so the handed-over binder is served.
         */
        private fun systemContext(): Context {
            val activityThread = Class.forName("android.app.ActivityThread")
            val thread = activityThread.getMethod("systemMain").invoke(null)
            return activityThread.getMethod("getSystemContext").invoke(thread) as Context
        }

        private fun fail(message: String, code: Int): Nothing {
            System.err.println(message)
            exitProcess(code)
        }
    }
}
