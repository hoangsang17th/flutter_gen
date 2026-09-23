import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("dev") {
            dimension = "flavor-type"
            applicationId = "vn.com.finvoras.stageone.dev"
            resValue(type = "string", name = "app_name", value = "Stage One App DEV")
        }
        create("stg") {
            dimension = "flavor-type"
            applicationId = "vn.com.finvoras.stageone.stg"
            resValue(type = "string", name = "app_name", value = "Stage One App STG")
        }
        create("prod") {
            dimension = "flavor-type"
            applicationId = "vn.com.finvoras.stageone"
            resValue(type = "string", name = "app_name", value = "Stage One App PROD")
        }
    }

    buildFeatures.resValues = true
}