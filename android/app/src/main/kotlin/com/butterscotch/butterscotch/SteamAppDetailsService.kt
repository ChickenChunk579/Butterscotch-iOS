package com.butterscotch.butterscotch

import java.text.SimpleDateFormat
import java.util.Locale
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

object SteamAppDetailsService {

    data class Details(
        val name: String,
        val developers: List<String>,
        val publishers: List<String>,
        val shortDescription: String,
        val genres: List<String>,
        val categories: List<String>,
        val platforms: List<String>,
        val releaseDate: Long?
    )

    sealed class ServiceError(
        message: String
    ) : Exception(message) {

        class InvalidAppID :
            ServiceError("Invalid Steam App ID.")

        class InvalidResponse :
            ServiceError("Steam returned an invalid response.")

        class AppNotFound :
            ServiceError("Steam could not find that app.")

        class Network(
            cause: Throwable
        ) : ServiceError(
            cause.message ?: "Unable to contact Steam."
        )
    }

    private val json = Json {
        ignoreUnknownKeys = true
    }

    suspend fun fetchDetails(
        steamAppID: String
    ): Details {

        val appID =
            steamAppID
                .trim()

        if (
            appID.isEmpty() ||
            appID.toIntOrNull() == null
        ) {
            throw ServiceError.InvalidAppID()
        }

        val url =
            "https://store.steampowered.com/api/appdetails" +
                "?appids=$appID&cc=us&l=en"

        val data: String

        try {

            data =
                java.net.URL(url)
                    .openConnection()
                    .let { connection ->

                        connection.connectTimeout = 10_000
                        connection.readTimeout = 10_000

                        connection.getInputStream()
                            .bufferedReader()
                            .use {
                                it.readText()
                            }
                    }

        } catch (exception: Exception) {

            throw ServiceError.Network(
                exception
            )
        }

        val root: JsonObject

        try {
            root =
                json.parseToJsonElement(data)
                    .jsonObject
        } catch (exception: Exception) {

            throw ServiceError.InvalidResponse()
        }

        val envelope =
            root[appID]
                ?.jsonObject
                ?: throw ServiceError.AppNotFound()

        val success =
            envelope["success"]
                ?.jsonPrimitive
                ?.booleanOrNull
                ?: false

        if (!success) {
            throw ServiceError.AppNotFound()
        }

        val appData =
            envelope["data"]
                ?.jsonObject
                ?: throw ServiceError.AppNotFound()

        return Details(

            name =
                appData.stringValue(
                    "name"
                ),

            developers =
                appData.stringArray(
                    "developers"
                ),

            publishers =
                appData.stringArray(
                    "publishers"
                ),

            shortDescription =
                appData.stringValue(
                    "short_description"
                ),

            genres =
                appData.objectDescriptionArray(
                    "genres"
                ),

            categories =
                appData.objectDescriptionArray(
                    "categories"
                ),

            platforms =
                parsePlatforms(
                    appData["platforms"]
                        ?.jsonObject
                ),

            releaseDate =
                parseReleaseDate(
                    appData["release_date"]
                        ?.jsonObject
                        ?.get("date")
                        ?.jsonPrimitive
                        ?.contentOrNull
                )
        )
    }

    private fun JsonObject.stringValue(
        key: String
    ): String {

        return this[key]
            ?.jsonPrimitive
            ?.contentOrNull
            .orEmpty()
    }

    private fun JsonObject.stringArray(
        key: String
    ): List<String> {

        val array =
            this[key]
                as? JsonArray
                ?: return emptyList()

        return array.mapNotNull { element ->

            (element as? JsonPrimitive)
                ?.contentOrNull
        }
    }

    private fun JsonObject.objectDescriptionArray(
        key: String
    ): List<String> {

        val array =
            this[key]
                as? JsonArray
                ?: return emptyList()

        return array.mapNotNull { element ->

            element
                .jsonObject
                .stringValue("description")
                .takeIf {
                    it.isNotEmpty()
                }
        }
    }

    private fun parsePlatforms(
        platforms: JsonObject?
    ): List<String> {

        if (platforms == null) {
            return emptyList()
        }

        val result =
            mutableListOf<String>()

        if (
            platforms["windows"]
                ?.jsonPrimitive
                ?.booleanOrNull == true
        ) {
            result += "Windows"
        }

        if (
            platforms["mac"]
                ?.jsonPrimitive
                ?.booleanOrNull == true
        ) {
            result += "macOS"
        }

        if (
            platforms["linux"]
                ?.jsonPrimitive
                ?.booleanOrNull == true
        ) {
            result += "Linux"
        }

        return result
    }

    private fun parseReleaseDate(
        value: String?
    ): Long? {

        if (
            value.isNullOrBlank() ||
            value.equals(
                "Coming soon",
                ignoreCase = true
            )
        ) {
            return null
        }

        return try {

            val formatter =
                SimpleDateFormat(
                    "d MMM, yyyy",
                    Locale.US
                )

            formatter.parse(value)
                ?.time

        } catch (_: Exception) {

            null
        }
    }
}