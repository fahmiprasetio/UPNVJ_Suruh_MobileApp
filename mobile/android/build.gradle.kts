allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

/**
 * Menyamakan compileSdk seluruh plugin dengan compileSdk aplikasi.
 *
 * `flutter_secure_storage` 11 menyetel compileSdk 37 untuk dirinya sendiri, dan Android
 * Gradle Plugin 8.11 lalu mencari platform bernama `android-37`. Platform dengan nama itu
 * tidak pernah diterbitkan: yang ada di repositori SDK cuma `android-37.0` dan
 * `android-37.1`. Akibatnya build rilis berhenti dengan "Failed to find target with hash
 * string 'android-37'" sesudah Gradle rela mengunduh dan memasang SDK-nya sendiri, dan
 * tidak ada yang bisa diperbaiki dengan memasang apa pun lagi.
 *
 * Diturunkan, bukan dinaikkan, karena yang dituntut plugin itu versi kompilasinya saja,
 * bukan API baru: ia menyimpan lewat Keystore, yang sudah ada sejak API 23. Kalau suatu
 * hari ia benar-benar memakai sesuatu yang belum ada di 36, kompilasinya akan gagal di
 * sini menyebut nama kelasnya, bukan diam-diam menghasilkan aplikasi yang salah.
 *
 * Dipasang lewat refleksi karena berkas ini tidak punya Android Gradle Plugin di
 * classpath-nya (lihat settings.gradle.kts: AGP dideklarasikan `apply false`), jadi
 * tipe-tipenya belum ada saat berkas ini dikompilasi.
 *
 * Letaknya harus di atas blok `evaluationDependsOn` di bawah, bukan di bawahnya. Blok itu
 * memaksa tiap subproyek dievaluasi saat itu juga, dan `afterEvaluate` yang didaftarkan
 * sesudahnya ditolak Gradle: "Cannot run Project.afterEvaluate(Action) when the project is
 * already evaluated."
 */
val compileSdkSeragam = 36

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate

        val setCompileSdk = android.javaClass.methods.firstOrNull {
            it.name == "compileSdkVersion" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0] == Int::class.javaPrimitiveType
        }

        // Sengaja tidak didiamkan kalau tidak ketemu. Kalau Android Gradle Plugin suatu saat
        // mengganti bentuk method ini, yang terjadi tanpa lemparan adalah build yang kembali
        // gagal dengan galat SDK yang sama persis, dan tidak ada yang menghubungkannya
        // dengan berkas ini.
        requireNotNull(setCompileSdk) {
            "Tidak menemukan compileSdkVersion(Int) di ekstensi android milik ${project.name}. " +
                "Android Gradle Plugin kemungkinan berganti bentuk; sesuaikan blok ini."
        }

        setCompileSdk.invoke(android, compileSdkSeragam)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
