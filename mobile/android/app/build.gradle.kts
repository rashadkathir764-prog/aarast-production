import java.io.FileInputStream
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Base64
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Android plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun decodedDartDefines(): Map<String, String> {
    val encodedDefines = project.findProperty("dart-defines")
        ?.toString()
        ?.takeIf { it.isNotBlank() }
        ?: return emptyMap()

    return encodedDefines.split(',').associate { encoded ->
        val decoded = try {
            String(
                Base64.getDecoder().decode(encoded),
                StandardCharsets.UTF_8,
            )
        } catch (error: IllegalArgumentException) {
            throw GradleException("Release dart-defines contain invalid Base64.", error)
        }
        val parts = decoded.split('=', limit = 2)
        if (parts.size != 2 || parts[0].isBlank()) {
            throw GradleException("Release dart-defines contain an invalid entry.")
        }
        parts[0] to parts[1]
    }
}

fun isLocalOrPrivateHost(value: String): Boolean {
    val host = value.trim().lowercase()
    if (
        host == "localhost" ||
        host.endsWith(".localhost") ||
        host == "::1" ||
        host == "[::1]" ||
        host.contains(':') ||
        host == "0.0.0.0"
    ) {
        return true
    }

    val octets = host.split('.').map { it.toIntOrNull() }
    val looksNumeric = host.matches(Regex("^[0-9.]+$"))
    if (octets.size != 4 || octets.any { it == null }) return looksNumeric
    if (octets.any { it !in 0..255 }) return true
    val first = octets[0]!!
    val second = octets[1]!!
    return first == 10 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second in 16..31) ||
        (first == 192 && second == 168)
}

fun validateReleaseDartDefines(requireStoreObservability: Boolean) {
    val defines = decodedDartDefines()
    val apiBaseUrl = defines["AARAST_API_BASE_URL"]?.trim().orEmpty()
    if (apiBaseUrl.isEmpty()) {
        throw GradleException(
            "Release builds require --dart-define=" +
                "AARAST_API_BASE_URL=https://your-production-api.",
        )
    }

    val uri = try {
        URI(apiBaseUrl)
    } catch (error: Exception) {
        throw GradleException("AARAST_API_BASE_URL is not a valid URI.", error)
    }
    if (
        !uri.scheme.equals("https", ignoreCase = true) ||
        uri.host.isNullOrBlank() ||
        uri.userInfo != null ||
        uri.query != null ||
        uri.fragment != null ||
        isLocalOrPrivateHost(uri.host)
    ) {
        throw GradleException(
            "AARAST_API_BASE_URL must be a public HTTPS origin without " +
                "credentials, query parameters, or fragments.",
        )
    }

    val bypassLoginGates = defines["AARAST_DEV_BYPASS_LOGIN_GATES"]?.trim()
    if (
        bypassLoginGates.equals("true", ignoreCase = true) ||
        bypassLoginGates == "1"
    ) {
        throw GradleException(
            "AARAST_DEV_BYPASS_LOGIN_GATES must stay disabled in release builds.",
        )
    }

    val requiredFirebaseDefines = listOf(
        "AARAST_FIREBASE_API_KEY",
        "AARAST_FIREBASE_APP_ID",
        "AARAST_FIREBASE_MESSAGING_SENDER_ID",
        "AARAST_FIREBASE_PROJECT_ID",
    )
    val missingFirebaseDefines = requiredFirebaseDefines.filter { key ->
        defines[key].isNullOrBlank()
    }
    if (missingFirebaseDefines.isNotEmpty()) {
        throw GradleException(
            "Release builds require Firebase push dart-defines: " +
                missingFirebaseDefines.joinToString() +
                ".",
        )
    }

    if (requireStoreObservability) {
        val requiredSentryDefines = listOf(
            "AARAST_SENTRY_DSN",
            "AARAST_SENTRY_TRACES_SAMPLE_RATE",
            "SENTRY_RELEASE",
        )
        val missingSentryDefines = requiredSentryDefines.filter { key ->
            defines[key].isNullOrBlank()
        }
        val requiredSentryEnvironment = listOf(
            "SENTRY_AUTH_TOKEN",
            "SENTRY_ORG",
            "SENTRY_PROJECT",
        )
        val missingSentryEnvironment = requiredSentryEnvironment.filter { key ->
            System.getenv(key).isNullOrBlank()
        }
        if (missingSentryDefines.isNotEmpty() || missingSentryEnvironment.isNotEmpty()) {
            throw GradleException(
                "Store app bundles require Sentry runtime and symbol-upload inputs. " +
                    "Missing dart-defines: ${missingSentryDefines.joinToString()}; " +
                    "missing environment variables: ${missingSentryEnvironment.joinToString()}.",
            )
        }
        if (defines["AARAST_ENVIRONMENT"]?.trim() != "production") {
            throw GradleException(
                "Store app bundles require AARAST_ENVIRONMENT=production.",
            )
        }
        val tracesSampleRate = defines["AARAST_SENTRY_TRACES_SAMPLE_RATE"]
            ?.trim()
            ?.toDoubleOrNull()
        if (tracesSampleRate == null || tracesSampleRate !in 0.0..1.0) {
            throw GradleException(
                "AARAST_SENTRY_TRACES_SAMPLE_RATE must be between 0 and 1.",
            )
        }
    }
}

val productionApplicationId = "com.aarast.aarast_mobile"
val releaseApplicationId = System.getenv("AARAST_ANDROID_APPLICATION_ID")
    ?.trim()
    ?.takeIf(String::isNotEmpty)
    ?: productionApplicationId
val androidApplicationIdPattern = Regex(
    "^[a-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$",
)
if (!androidApplicationIdPattern.matches(releaseApplicationId)) {
    throw GradleException(
        "AARAST_ANDROID_APPLICATION_ID must be a valid reverse-DNS Android application ID.",
    )
}

val releaseAppLabel = System.getenv("AARAST_ANDROID_APP_LABEL")
    ?.trim()
    ?.takeIf(String::isNotEmpty)
    ?: "اعّرست"
if (releaseAppLabel.length > 40 || releaseAppLabel.any(Character::isISOControl)) {
    throw GradleException(
        "AARAST_ANDROID_APP_LABEL must be 1-40 visible characters.",
    )
}

// Store signing: android/key.properties stays out of Git and points at the
// upload keystore. Release tasks fail closed when the file or any required
// value is missing; a store artifact can never fall back to Android debug keys.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.isFile) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val signingEnvironmentKeys = mapOf(
    "storeFile" to "AARAST_ANDROID_STORE_FILE",
    "storePassword" to "AARAST_ANDROID_STORE_PASSWORD",
    "keyAlias" to "AARAST_ANDROID_KEY_ALIAS",
    "keyPassword" to "AARAST_ANDROID_KEY_PASSWORD",
)
fun releaseSigningValue(key: String): String =
    keystoreProperties.getProperty(key)?.trim().takeUnless { it.isNullOrEmpty() }
        ?: System.getenv(signingEnvironmentKeys.getValue(key))?.trim().orEmpty()

val releaseSigningValues = signingEnvironmentKeys.keys.associateWith(::releaseSigningValue)
val invalidSigningKeys = signingEnvironmentKeys.keys.filter { key ->
    val value = releaseSigningValues.getValue(key)
    value.isEmpty() || value.equals("replace-me", ignoreCase = true)
}
val releaseStoreFile = releaseSigningValues["storeFile"]
    ?.takeIf(String::isNotEmpty)
    ?.let(rootProject::file)
val hasUsableReleaseKeystore = invalidSigningKeys.isEmpty() &&
    releaseStoreFile?.isFile == true
val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}
val storeReleaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("bundle", ignoreCase = true) &&
        taskName.contains("release", ignoreCase = true)
}

if (releaseTaskRequested) {
    validateReleaseDartDefines(
        requireStoreObservability = storeReleaseTaskRequested,
    )
    if (!hasUsableReleaseKeystore) {
        val reason = when {
            invalidSigningKeys.isNotEmpty() ->
                "required non-placeholder values are missing: " +
                    invalidSigningKeys.joinToString()
            else -> "the configured storeFile does not exist"
        }
        throw GradleException(
            "Release signing is not configured: $reason. " +
                "Use android/key.properties or AARAST_ANDROID_* environment variables. " +
                "Debug signing is forbidden for release artifacts.",
        )
    }
}

android {
    namespace = "com.aarast.aarast_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        val defines = decodedDartDefines()
        applicationId = releaseApplicationId
        manifestPlaceholders["aarastAppLabel"] = releaseAppLabel
        mapOf(
            "google_api_key" to "AARAST_FIREBASE_API_KEY",
            "google_app_id" to "AARAST_FIREBASE_APP_ID",
            "gcm_defaultSenderId" to
                "AARAST_FIREBASE_MESSAGING_SENDER_ID",
            "project_id" to "AARAST_FIREBASE_PROJECT_ID",
        ).forEach { (resourceName, defineName) ->
            defines[defineName]
                ?.trim()
                ?.takeIf(String::isNotEmpty)
                ?.let { value -> resValue("string", resourceName, value) }
        }
        // flutter_secure_storage requires API 23+ (Android Keystore).
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUsableReleaseKeystore) {
            create("release") {
                keyAlias = releaseSigningValues.getValue("keyAlias")
                keyPassword = releaseSigningValues.getValue("keyPassword")
                storeFile = releaseStoreFile
                storePassword = releaseSigningValues.getValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasUsableReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
