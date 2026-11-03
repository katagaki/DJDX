package com.tsubuzaki.djdxgo.ui.more

import android.content.Context
import android.text.format.Formatter
import android.webkit.WebView
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun FreeUpSpaceDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var isCleaningUp by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = { if (!isCleaningUp) onDismiss() },
        title = { Text(stringResource(R.string.more_free_up_space_title)) },
        text = {
            if (isCleaningUp) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    Text(stringResource(R.string.more_free_up_space_cleaning_up))
                }
            } else {
                Text(stringResource(R.string.more_free_up_space_message, stringResource(R.string.app_name)))
            }
        },
        confirmButton = {
            TextButton(
                enabled = !isCleaningUp,
                onClick = {
                    isCleaningUp = true
                    scope.launch {
                        val minimumDuration = async { delay(1000) }
                        val freed = freeUpSpace(context)
                        minimumDuration.await()
                        onDismiss()
                        Toast.makeText(
                            context,
                            context.getString(
                                R.string.more_free_up_space_done,
                                Formatter.formatShortFileSize(context, freed)
                            ),
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }
            ) {
                Text(stringResource(R.string.more_free_up_space_clean_up))
            }
        },
        dismissButton = {
            TextButton(enabled = !isCleaningUp, onClick = onDismiss) {
                Text(stringResource(R.string.shared_cancel))
            }
        }
    )
}

private suspend fun freeUpSpace(context: Context): Long {
    val directories = listOfNotNull(context.cacheDir, context.codeCacheDir, context.externalCacheDir)
    val before = withContext(Dispatchers.IO) { directories.sumOf(::sizeOf) }
    WebView(context).apply {
        clearCache(true)
        destroy()
    }
    return withContext(Dispatchers.IO) {
        directories.forEach { directory ->
            directory.listFiles()?.forEach { it.deleteRecursively() }
        }
        maxOf(0L, before - directories.sumOf(::sizeOf))
    }
}

private fun sizeOf(file: File): Long =
    if (file.isDirectory) file.listFiles()?.sumOf(::sizeOf) ?: 0L else file.length()
