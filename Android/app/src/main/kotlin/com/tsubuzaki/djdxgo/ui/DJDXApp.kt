package com.tsubuzaki.djdxgo.ui

import android.content.Intent
import android.webkit.CookieManager
import android.webkit.WebStorage
import android.widget.Toast
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.SaveAlt
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import android.net.Uri
import com.tsubuzaki.djdxgo.DJDXApplication
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.ddr.DDRVersionInfo
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordVersionInfo
import com.tsubuzaki.djdxgo.data.sdvx.SDVXVersion
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import com.tsubuzaki.djdxgo.ui.analytics.DDRAnalyticsSection
import com.tsubuzaki.djdxgo.ui.analytics.IIDXAnalyticsSection
import com.tsubuzaki.djdxgo.ui.analytics.PolarisChordAnalyticsSection
import com.tsubuzaki.djdxgo.ui.analytics.SDVXAnalyticsSection
import com.tsubuzaki.djdxgo.ui.analytics.TowerDetailScreen
import com.tsubuzaki.djdxgo.ui.games.DDRScoresScreen
import com.tsubuzaki.djdxgo.ui.games.PolarisChordScoresScreen
import com.tsubuzaki.djdxgo.ui.games.SDVXScoresScreen
import com.tsubuzaki.djdxgo.ui.games.SDVXScoreViewerScreen
import com.tsubuzaki.djdxgo.ui.iidx.IIDXScoresScreen
import com.tsubuzaki.djdxgo.ui.iidx.IIDXScoreViewerScreen
import com.tsubuzaki.djdxgo.ui.importer.ImportScreen
import com.tsubuzaki.djdxgo.ui.more.AttributionsScreen
import com.tsubuzaki.djdxgo.ui.more.ExternalDataSourcesScreen
import com.tsubuzaki.djdxgo.ui.onboarding.OnboardingScreen
import com.tsubuzaki.djdxgo.ui.web.WebViewScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

sealed interface ViewerTarget {
    data class IIDX(val title: String, val playType: String, val level: String, val date: Long) : ViewerTarget
    data class SDVX(val title: String, val date: Long) : ViewerTarget
    data class Web(val url: String, val title: String) : ViewerTarget
}

private fun ViewerTarget.toRoute(): String = when (this) {
    is ViewerTarget.IIDX ->
        "viewer/iidx?title=${Uri.encode(title)}&playType=${Uri.encode(playType)}" +
            "&level=${Uri.encode(level)}&date=$date"
    is ViewerTarget.SDVX ->
        "viewer/sdvx?title=${Uri.encode(title)}&date=$date"
    is ViewerTarget.Web ->
        "viewer/web?url=${Uri.encode(url)}&title=${Uri.encode(title)}"
}

private enum class PendingDelete { WEB, SCORE }

private fun gameIconRes(game: Game): Int = when (game) {
    Game.IIDX_ARCADE -> R.drawable.ic_game_iidx
    Game.SOUND_VOLTEX -> R.drawable.ic_game_sdvx
    Game.POLARIS_CHORD -> R.drawable.ic_game_polaris
    Game.DANCE_DANCE_REVOLUTION -> R.drawable.ic_game_ddr
}

@Composable
fun DJDXApp() {
    val context = LocalContext.current
    val container = (context.applicationContext as DJDXApplication).container
    val scope = rememberCoroutineScope()
    val navController = rememberNavController()

    val onboardingSeen by context.settingFlow(SettingsKeys.onboardingLastSeenVersion, "")
        .collectAsState(initial = "seen")

    if (onboardingSeen.isEmpty()) {
        OnboardingScreen(
            onContinue = {
                scope.launch { context.setSetting(SettingsKeys.onboardingLastSeenVersion, "1.0") }
            }
        )
        return
    }

    fun openViewer(target: ViewerTarget) {
        navController.navigate(target.toRoute())
    }

    NavHost(navController = navController, startDestination = "scores") {
        composable("scores") {
            ScoresShell(
                onOpenViewer = ::openViewer,
                onNavigate = { route -> navController.navigate(route) }
            )
        }
        composable("import") {
            val selectedGameId by context.settingFlow(SettingsKeys.selectedGame, 0)
                .collectAsState(initial = 0)
            ImportScreen(
                container = container,
                game = Game.fromId(selectedGameId),
                onDismiss = { navController.popBackStack() }
            )
        }
        composable(
            route = "viewer/iidx?title={title}&playType={playType}&level={level}&date={date}",
            arguments = listOf(
                navArgument("title") { type = NavType.StringType; defaultValue = "" },
                navArgument("playType") { type = NavType.StringType; defaultValue = "single" },
                navArgument("level") { type = NavType.StringType; defaultValue = "" },
                navArgument("date") { type = NavType.LongType; defaultValue = 0L }
            )
        ) { entry ->
            val args = entry.arguments!!
            val title = args.getString("title").orEmpty()
            IIDXScoreViewerScreen(
                container = container,
                title = title,
                playType = args.getString("playType") ?: "single",
                initialLevel = args.getString("level").orEmpty(),
                dateEpoch = args.getLong("date"),
                onBack = { navController.popBackStack() },
                onOpenWeb = { url -> openViewer(ViewerTarget.Web(url, title)) }
            )
        }
        composable(
            route = "viewer/sdvx?title={title}&date={date}",
            arguments = listOf(
                navArgument("title") { type = NavType.StringType; defaultValue = "" },
                navArgument("date") { type = NavType.LongType; defaultValue = 0L }
            )
        ) { entry ->
            val args = entry.arguments!!
            val title = args.getString("title").orEmpty()
            SDVXScoreViewerScreen(
                container = container,
                title = title,
                dateEpoch = args.getLong("date"),
                onBack = { navController.popBackStack() },
                onOpenWeb = { url -> openViewer(ViewerTarget.Web(url, title)) }
            )
        }
        composable(
            route = "viewer/web?url={url}&title={title}",
            arguments = listOf(
                navArgument("url") { type = NavType.StringType; defaultValue = "" },
                navArgument("title") { type = NavType.StringType; defaultValue = "" }
            )
        ) { entry ->
            val args = entry.arguments!!
            WebViewScreen(
                url = args.getString("url").orEmpty(),
                title = args.getString("title").orEmpty(),
                onBack = { navController.popBackStack() }
            )
        }
        composable("tower") {
            TowerDetailScreen(container = container, onBack = { navController.popBackStack() })
        }
        composable("externalData") {
            ExternalDataSourcesScreen(container = container, onBack = { navController.popBackStack() })
        }
        composable("attributions") {
            AttributionsScreen(onBack = { navController.popBackStack() })
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScoresShell(
    onOpenViewer: (ViewerTarget) -> Unit,
    onNavigate: (String) -> Unit
) {
    val context = LocalContext.current
    val container = (context.applicationContext as DJDXApplication).container
    val scope = rememberCoroutineScope()

    val selectedGameId by context.settingFlow(SettingsKeys.selectedGame, 0)
        .collectAsState(initial = 0)
    val selectedGame = Game.fromId(selectedGameId)
    val showAnalytics by context.settingFlow(SettingsKeys.showAnalytics, true)
        .collectAsState(initial = true)
    val sdvxVersionNumber by context.settingFlow(
        SettingsKeys.sdvxVersion, SDVXVersion.NABLA.number
    ).collectAsState(initial = SDVXVersion.NABLA.number)
    val iidxPlayType by context.settingFlow(SettingsKeys.iidxPlayType, "single")
        .collectAsState(initial = "single")

    var isGameMenuExpanded by remember { mutableStateOf(false) }
    var isMoreMenuExpanded by remember { mutableStateOf(false) }
    var pendingDelete by remember { mutableStateOf<PendingDelete?>(null) }
    var isDisclaimerShowing by remember { mutableStateOf(false) }

    val nowEpoch = remember { System.currentTimeMillis() / 1000 }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    TextButton(onClick = { isGameMenuExpanded = true }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                painter = painterResource(gameIconRes(selectedGame)),
                                contentDescription = null,
                                modifier = Modifier
                                    .padding(end = 6.dp)
                                    .size(22.dp),
                                tint = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                selectedGame.shortName,
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Icon(
                                Icons.Default.ArrowDropDown,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                    DropdownMenu(
                        expanded = isGameMenuExpanded,
                        onDismissRequest = { isGameMenuExpanded = false }
                    ) {
                        Game.entries.forEach { game ->
                            DropdownMenuItem(
                                text = { Text(game.displayName) },
                                leadingIcon = {
                                    Icon(
                                        painter = painterResource(gameIconRes(game)),
                                        contentDescription = null,
                                        modifier = Modifier.size(24.dp),
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                },
                                trailingIcon = {
                                    if (game == selectedGame) {
                                        Icon(Icons.Default.Check, contentDescription = null)
                                    }
                                },
                                onClick = {
                                    scope.launch {
                                        context.setSetting(SettingsKeys.selectedGame, game.id)
                                    }
                                    isGameMenuExpanded = false
                                }
                            )
                        }
                        HorizontalDivider()
                        Text(
                            stringResource(R.string.game_version_sdvx),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                        )
                        if (selectedGame == Game.SOUND_VOLTEX) {
                            SDVXVersion.entries.forEach { version ->
                                DropdownMenuItem(
                                    text = { Text(version.marketingName) },
                                    leadingIcon = {
                                        if (version.number == sdvxVersionNumber) {
                                            Icon(Icons.Default.Check, contentDescription = null)
                                        }
                                    },
                                    onClick = {
                                        scope.launch {
                                            context.setSetting(SettingsKeys.sdvxVersion, version.number)
                                        }
                                        isGameMenuExpanded = false
                                    }
                                )
                            }
                        } else {
                            val versionName = when (selectedGame) {
                                Game.IIDX_ARCADE -> IIDXVersionInfo.MARKETING_NAME
                                Game.POLARIS_CHORD -> PolarisChordVersionInfo.MARKETING_NAME
                                Game.DANCE_DANCE_REVOLUTION -> DDRVersionInfo.MARKETING_NAME
                                else -> ""
                            }
                            DropdownMenuItem(
                                text = { Text(versionName) },
                                leadingIcon = {
                                    Icon(Icons.Default.Check, contentDescription = null)
                                },
                                onClick = { isGameMenuExpanded = false }
                            )
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = { onNavigate("import") }) {
                        Icon(
                            Icons.Default.SaveAlt,
                            contentDescription = stringResource(R.string.shared_import)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { isMoreMenuExpanded = true }) {
                        Icon(Icons.Default.MoreVert, contentDescription = stringResource(R.string.more_title))
                    }
                    DropdownMenu(
                        expanded = isMoreMenuExpanded,
                        onDismissRequest = { isMoreMenuExpanded = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.more_external_data)) },
                            onClick = {
                                isMoreMenuExpanded = false
                                onNavigate("externalData")
                            }
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.more_show_analytics)) },
                            leadingIcon = {
                                if (showAnalytics) Icon(Icons.Default.Check, contentDescription = null)
                            },
                            onClick = {
                                scope.launch {
                                    context.setSetting(SettingsKeys.showAnalytics, !showAnalytics)
                                }
                            }
                        )
                        HorizontalDivider()
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.more_delete_web_data)) },
                            onClick = {
                                isMoreMenuExpanded = false
                                pendingDelete = PendingDelete.WEB
                            }
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.more_delete_score_data)) },
                            onClick = {
                                isMoreMenuExpanded = false
                                pendingDelete = PendingDelete.SCORE
                            }
                        )
                        HorizontalDivider()
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.more_github)) },
                            onClick = {
                                isMoreMenuExpanded = false
                                context.startActivity(
                                    Intent(
                                        Intent.ACTION_VIEW,
                                        "https://github.com/katagaki/DJDXGo".toUri()
                                    )
                                )
                            }
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.more_attributions)) },
                            onClick = {
                                isMoreMenuExpanded = false
                                onNavigate("attributions")
                            }
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.more_disclaimer)) },
                            onClick = {
                                isMoreMenuExpanded = false
                                isDisclaimerShowing = true
                            }
                        )
                    }
                }
            )
        }
    ) { padding ->
        var selectedTab by rememberSaveable(selectedGame) { mutableIntStateOf(0) }
        Column(modifier = Modifier.padding(padding)) {
            if (showAnalytics) {
                PrimaryTabRow(selectedTabIndex = selectedTab) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text(stringResource(R.string.tab_scores)) }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text(stringResource(R.string.tab_analytics)) }
                    )
                }
            }
            val showAnalyticsTab = showAnalytics && selectedTab == 1
            if (showAnalyticsTab) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = 12.dp)
                ) {
                    when (selectedGame) {
                        Game.IIDX_ARCADE -> IIDXAnalyticsSection(
                            container = container,
                            dateEpoch = nowEpoch,
                            playType = iidxPlayType,
                            onOpenTower = { onNavigate("tower") }
                        )
                        Game.SOUND_VOLTEX ->
                            SDVXAnalyticsSection(container = container, dateEpoch = nowEpoch)
                        Game.POLARIS_CHORD ->
                            PolarisChordAnalyticsSection(container = container, dateEpoch = nowEpoch)
                        Game.DANCE_DANCE_REVOLUTION ->
                            DDRAnalyticsSection(container = container, dateEpoch = nowEpoch)
                    }
                }
            } else {
                when (selectedGame) {
                    Game.IIDX_ARCADE -> IIDXScoresScreen(
                        container = container,
                        contentPadding = PaddingValues(),
                        onOpenSong = { title, playType, level, date ->
                            onOpenViewer(ViewerTarget.IIDX(title, playType, level, date))
                        }
                    )
                    Game.SOUND_VOLTEX -> SDVXScoresScreen(
                        container = container,
                        contentPadding = PaddingValues(),
                        onOpenSong = { title, date -> onOpenViewer(ViewerTarget.SDVX(title, date)) }
                    )
                    Game.POLARIS_CHORD -> PolarisChordScoresScreen(
                        container = container,
                        contentPadding = PaddingValues()
                    )
                    Game.DANCE_DANCE_REVOLUTION -> DDRScoresScreen(
                        container = container,
                        contentPadding = PaddingValues()
                    )
                }
            }
        }
    }

    when (pendingDelete) {
        PendingDelete.WEB -> androidx.compose.material3.AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text(stringResource(R.string.more_delete_web_data)) },
            text = { Text(stringResource(R.string.more_delete_web_data_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    pendingDelete = null
                    CookieManager.getInstance().removeAllCookies(null)
                    CookieManager.getInstance().flush()
                    WebStorage.getInstance().deleteAllData()
                    Toast.makeText(
                        context,
                        context.getString(R.string.more_delete_web_data_done),
                        Toast.LENGTH_SHORT
                    ).show()
                }) { Text(stringResource(R.string.shared_delete)) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) {
                    Text(stringResource(R.string.shared_cancel))
                }
            }
        )
        PendingDelete.SCORE -> androidx.compose.material3.AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text(stringResource(R.string.more_delete_score_data)) },
            text = { Text(stringResource(R.string.more_delete_score_data_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    pendingDelete = null
                    scope.launch(Dispatchers.IO) {
                        container.iidxRepository.deleteAllData()
                        container.sdvxRepository.deleteAllData()
                        container.polarisChordRepository.deleteAllData()
                        container.ddrRepository.deleteAllData()
                    }
                    Toast.makeText(
                        context,
                        context.getString(R.string.more_delete_score_data_done),
                        Toast.LENGTH_SHORT
                    ).show()
                }) { Text(stringResource(R.string.shared_delete)) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) {
                    Text(stringResource(R.string.shared_cancel))
                }
            }
        )
        null -> {}
    }

    if (isDisclaimerShowing) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { isDisclaimerShowing = false },
            title = { Text(stringResource(R.string.more_disclaimer)) },
            text = { Text(stringResource(R.string.more_disclaimer_text)) },
            confirmButton = {
                TextButton(onClick = { isDisclaimerShowing = false }) {
                    Text(stringResource(R.string.shared_ok))
                }
            }
        )
    }
}
