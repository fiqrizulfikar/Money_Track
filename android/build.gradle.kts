allprojects {
    repositories {
        google()
        mavenCentral()
    }
}


val rootBuildDir = file("${project.projectDir}/../build")
subprojects {
    val newBuildDir = file("${rootBuildDir.absolutePath}/${project.name}")
    project.layout.buildDirectory.set(newBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootBuildDir)
}
