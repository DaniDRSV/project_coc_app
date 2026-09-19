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
    // 1. Configuración de directorios de build
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // 2. Solución para el error lStar (Forzar SDK 34)
    // Definimos la lógica de actualización en una variable
    val updateAndroidConfig = {
        val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        android?.compileSdkVersion(34)
    }

    // Si el proyecto ya se evaluó (por evaluationDependsOn), lo aplicamos directo
    // Si no, esperamos al afterEvaluate
    if (project.state.executed) {
        updateAndroidConfig()
    } else {
        project.afterEvaluate {
            updateAndroidConfig()
        }
    }
}

subprojects {
    // 3. Dependencia de evaluación requerida por Flutter
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}