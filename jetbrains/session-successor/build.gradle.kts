plugins {
    id("org.jetbrains.kotlin.jvm") version "2.4.10"
    id("org.jetbrains.intellij.platform") version "2.19.0"
}

group = "dev.andy.sessionsuccessor"
version = "0.1.0"

repositories {
    mavenCentral()
    intellijPlatform {
        defaultRepositories()
    }
}

dependencies {
    intellijPlatform {
        // -PlocalIde=/path/to/ide builds against an installed IDE; otherwise WebStorm is downloaded.
        val localIde = providers.gradleProperty("localIde").orNull
        if (localIde != null) local(localIde) else webstorm("2026.2.3")
        bundledPlugin("org.jetbrains.plugins.terminal")
    }
}

intellijPlatform {
    buildSearchableOptions = false
    pluginConfiguration {
        ideaVersion {
            // The terminal tab API this plugin uses exists from 2026.2 (build 262).
            sinceBuild = "262"
            untilBuild = provider { null }
        }
    }
}
