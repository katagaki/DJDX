package com.tsubuzaki.djdxgo.ui.more

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import kotlin.random.Random

private data class Attribution(val name: String, val license: String, val url: String)

private val attributions = listOf(
    Attribution("Jetpack Compose", "Apache License 2.0", "https://developer.android.com/compose"),
    Attribution("AndroidX Room", "Apache License 2.0", "https://developer.android.com/jetpack/androidx/releases/room"),
    Attribution("AndroidX DataStore", "Apache License 2.0", "https://developer.android.com/jetpack/androidx/releases/datastore"),
    Attribution("AndroidX WebKit", "Apache License 2.0", "https://developer.android.com/jetpack/androidx/releases/webkit"),
    Attribution("Kotlin Coroutines", "Apache License 2.0", "https://github.com/Kotlin/kotlinx.coroutines"),
    Attribution("kotlinx.serialization", "Apache License 2.0", "https://github.com/Kotlin/kotlinx.serialization"),
    Attribution("jsoup", "MIT License", "https://jsoup.org")
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttributionsScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.more_attributions)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            attributions.sortedBy { it.name.lowercase() }.forEach { attribution ->
                Card(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            attribution.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            attribution.license,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            attribution.url,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun DeleteScoreDataDialog(
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    val code = remember { Random.nextInt(100000, 1000000).toString() }
    var input by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.more_delete_score_data)) },
        text = {
            Column {
                Text(stringResource(R.string.more_delete_score_data_message, code))
                OutlinedTextField(
                    value = input,
                    onValueChange = { input = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                enabled = input == code
            ) {
                Text(stringResource(R.string.shared_delete))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.shared_cancel))
            }
        }
    )
}
