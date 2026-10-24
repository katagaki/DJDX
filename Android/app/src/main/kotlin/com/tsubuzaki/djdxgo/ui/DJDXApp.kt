package com.tsubuzaki.djdxgo.ui

import android.content.Intent
import android.net.Uri
import android.webkit.CookieManager
import android.webkit.WebStorage
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.SaveAlt
import androidx.compose.material.icons.outlined.Hexagon
import androidx.compose.material.icons.outlined.Storage
import androidx.compose.material3.AlertDialog
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
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.DJDXApplication
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.analyticsLayoutKeys
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRVersionInfo
import com.tsubuzaki.djdxgo.data.external.ExternalDataSource
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordVersionInfo
import com.tsubuzaki.djdxgo.data.removeSettings
import com.tsubuzaki.djdxgo.data.sdvx.SDVXVersion
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import com.tsubuzaki.djdxgo.ui.analytics.ChartAnalyticsDetailScreen
import com.tsubuzaki.djdxgo.ui.analytics.DDRAnalyticsSection
import com.tsubuzaki.djdxgo.ui.analytics.IIDXAnalyticsDetailScreen
import com.tsubuzaki.djdxgo.ui.analytics.IIDXAnalyticsSection
import com.tsubuzaki.djdxgo.ui.analytics.PolarisChordAnalyticsSection
import com.tsubuzaki.djdxgo.ui.analytics.SDVXAnalyticsSection
import com.tsubuzaki.djdxgo.ui.analytics.TowerDetailScreen
import com.tsubuzaki.djdxgo.ui.games.DDRScoresScreen
import com.tsubuzaki.djdxgo.ui.games.PolarisChordScoresScreen
import com.tsubuzaki.djdxgo.ui.games.SDVXScoreViewerScreen
import com.tsubuzaki.djdxgo.ui.games.SDVXScoresScreen
import com.tsubuzaki.djdxgo.ui.iidx.IIDXScoreViewerScreen
import com.tsubuzaki.djdxgo.ui.iidx.IIDXScoresScreen
import com.tsubuzaki.djdxgo.ui.importer.ImportScreen
import com.tsubuzaki.djdxgo.ui.more.AttributionsScreen
import com.tsubuzaki.djdxgo.ui.more.DeleteScoreDataDialog
import com.tsubuzaki.djdxgo.ui.more.ExternalDataSourcesScreen
import com.tsubuzaki.djdxgo.ui.more.RadarMakerScreen
import com.tsubuzaki.djdxgo.ui.onboarding.OnboardingScreen
import com.tsubuzaki.djdxgo.ui.profile.DDRDataSourceWarning
import com.tsubuzaki.djdxgo.ui.profile.DDRProfileHeader
import com.tsubuzaki.djdxgo.ui.profile.IIDXProfileHeader
import com.tsubuzaki.djdxgo.ui.profile.PolarisChordProfileHeader
import com.tsubuzaki.djdxgo.ui.profile.SDVXProfileHeader
import com.tsubuzaki.djdxgo.ui.web.SDVXInChartViewerScreen
import com.tsubuzaki.djdxgo.ui.web.TextageViewerScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class PendingDialog { DELETE_WEB, DELETE_SCORE_CODE, DELETE_SCORE, RESET_LAYOUT, DISCLAIMER }

private fun gameIconRes(game: Game): Int = when (game) {
    Game.IIDX_ARCADE -> R.drawable.ic_game_iidx
    Game.SOUND_VOLTEX -> R.drawable.ic_game_sdvx
    Game.POLARIS_CHORD -> R.drawable.ic_game_polaris
    Game.DANCE_DANCE_REVOLUTION -> R.drawable.ic_game_ddr
}

private fun gameNamed(name: String): Game? = when (name.lowercase()) {
    "iidx", "iidxarcade", "beatmania" -> Game.IIDX_ARCADE
    "sdvx", "soundvoltex" -> Game.SOUND_VOLTEX
    "polaris", "polarischord" -> Game.POLARIS_CHORD
    "ddr", "ddrworld", "dancedancerevolution" -> Game.DANCE_DANCE_REVOLUTION
    else -> null
}

@Composable
fun DJDXApp() {
    val context = LocalContext.current
    val container = (context.applicationContext as DJDXApplication).container
    val scope = rememberCoroutineScope()
    val navController = rememberNavController()

    val onboardingSeen by context.settingFlow(SettingsKeys.onboardingLastSeenVersion, "")
        .collectAsState(initial = "seen")

    LaunchedEffect(Unit) {
        container.profileRepository.loadCached()
    }

    LaunchedEffect(Unit) {
        container.deepLinks.collect { uri ->
            container.consumeDeepLink()
            handleDeepLink(uri, container, navController, context)
        }
    }

    if (onboardingSeen.isEmpty()) {
        OnboardingScreen(
            onContinue = {
                scope.launch { context.setSetting(SettingsKeys.onboardingLastSeenVersion, "1.0") }
            }
        )
        return
    }

    val navigate: (String) -> Unit = { route -> navController.navigate(route) }
    val back: () -> Unit = { navController.popBackStack() }

    NavHost(navController = navController, startDestination = Routes.SCORES) {
        composable(Routes.SCORES) {
            ScoresShell(container = container, onNavigate = navigate)
        }
        composable(Routes.IMPORT) {
            val selectedGameId by context.settingFlow(SettingsKeys.selectedGame, 0)
                .collectAsState(initial = 0)
            ImportScreen(container = container, game = Game.fromId(selectedGameId), onDismiss = back)
        }
        composable(
            route = Routes.IIDX_VIEWER,
            arguments = listOf(
                navArgument("title") { type = NavType.StringType; defaultValue = "" },
                navArgument("playType") { type = NavType.StringType; defaultValue = "single" },
                navArgument("level") { type = NavType.StringType; defaultValue = "" },
                navArgument("date") { type = NavType.LongType; defaultValue = 0L }
            )
        ) { entry ->
            val args = entry.arguments!!
            IIDXScoreViewerScreen(
                container = container,
                title = args.getString("title").orEmpty(),
                playType = args.getString("playType") ?: "single",
                initialLevel = args.getString("level").orEmpty(),
                dateEpoch = args.getLong("date"),
                onBack = back,
                onOpenTextage = { legacy, chart -> navigate(Routes.textageViewer(legacy, chart)) }
            )
        }
        composable(
            route = Routes.SDVX_VIEWER,
            arguments = listOf(
                navArgument("title") { type = NavType.StringType; defaultValue = "" },
                navArgument("date") { type = NavType.LongType; defaultValue = 0L },
                navArgument("difficulty") { type = NavType.StringType; defaultValue = "" }
            )
        ) { entry ->
            val args = entry.arguments!!
            SDVXScoreViewerScreen(
                container = container,
                title = args.getString("title").orEmpty(),
                dateEpoch = args.getLong("date"),
                initialDifficulty = args.getString("difficulty").orEmpty(),
                onBack = back,
                onOpenChart = { chart -> navigate(Routes.sdvxInViewer(chart)) }
            )
        }
        composable(
            route = Routes.TEXTAGE_VIEWER,
            arguments = listOf(
                navArgument("legacy") { type = NavType.StringType; defaultValue = "" },
                navArgument("chart") { type = NavType.StringType; defaultValue = "" }
            )
        ) { entry ->
            val args = entry.arguments!!
            TextageViewerScreen(
                legacyURL = args.getString("legacy")?.takeIf { it.isNotEmpty() },
                chartViewerURL = args.getString("chart")?.takeIf { it.isNotEmpty() },
                onBack = back
            )
        }
        composable(
            route = Routes.SDVX_IN_VIEWER,
            arguments = listOf(
                navArgument("legacy") { type = NavType.StringType; defaultValue = "" },
                navArgument("viewer") { type = NavType.StringType; defaultValue = "" },
                navArgument("data") { type = NavType.StringType; defaultValue = "" }
            )
        ) { entry ->
            val args = entry.arguments!!
            SDVXInChartViewerScreen(
                legacyURL = args.getString("legacy").orEmpty(),
                viewerURL = args.getString("viewer").orEmpty(),
                dataURL = args.getString("data").orEmpty(),
                onBack = back
            )
        }
        composable(
            route = Routes.TOWER,
            arguments = listOf(navArgument("mode") { type = NavType.StringType; defaultValue = Routes.TOWER_RECENT })
        ) { entry ->
            TowerDetailScreen(
                container = container,
                initialMode = entry.arguments?.getString("mode") ?: Routes.TOWER_RECENT,
                onBack = back
            )
        }
        composable(
            route = Routes.IIDX_ANALYTICS,
            arguments = listOf(
                navArgument("detail") { type = NavType.StringType },
                navArgument("param") { type = NavType.StringType; defaultValue = "" }
            )
        ) { entry ->
            IIDXAnalyticsDetailScreen(
                container = container,
                detail = entry.arguments?.getString("detail").orEmpty(),
                param = entry.arguments?.getString("param").orEmpty(),
                onBack = back,
                onNavigate = navigate
            )
        }
        composable(
            route = Routes.CHART_ANALYTICS,
            arguments = listOf(
                navArgument("game") { type = NavType.IntType },
                navArgument("detail") { type = NavType.StringType },
                navArgument("param") { type = NavType.StringType; defaultValue = "" }
            )
        ) { entry ->
            ChartAnalyticsDetailScreen(
                container = container,
                game = Game.fromId(entry.arguments?.getInt("game") ?: 0),
                detail = entry.arguments?.getString("detail").orEmpty(),
                param = entry.arguments?.getString("param").orEmpty(),
                onBack = back
            )
        }
        composable(Routes.EXTERNAL_DATA) {
            ExternalDataSourcesScreen(container = container, onBack = back)
        }
        composable(Routes.ATTRIBUTIONS) {
            AttributionsScreen(onBack = back)
        }
        composable(Routes.RADAR_MAKER) {
            RadarMakerScreen(onBack = back)
        }
    }
}

private suspend fun handleDeepLink(
    uri: Uri,
    container: AppContainer,
    navController: NavHostController,
    context: android.content.Context
) {
    if (uri.scheme != "djdx") return
    fun value(name: String): String? =
        uri.queryParameterNames.firstOrNull { it.equals(name, ignoreCase = true) }
            ?.let { uri.getQueryParameter(it) }
    when (uri.host) {
        "update" -> {
            if (value("type")?.lowercase() != "datasource") return
            val source = value("id")?.let(ExternalDataSource::fromId) ?: return
            if (container.externalDataReloader.reload(source).isSuccess) container.notifyDataChanged()
        }
        "open" -> {
            val game = value("game")?.let(::gameNamed)
            if (value("type")?.lowercase() == "detail") {
                val songName = value("songName")
                if (game != Game.IIDX_ARCADE || songName.isNullOrEmpty()) return
                openIIDXDetail(songName, container, navController, context)
            } else if (game != null) {
                navController.popBackStack(Routes.SCORES, inclusive = false)
                context.setSetting(SettingsKeys.selectedGame, game.id)
            }
        }
        "reonboard" -> context.setSetting(SettingsKeys.onboardingLastSeenVersion, "")
    }
}

private suspend fun openIIDXDetail(
    songName: String,
    container: AppContainer,
    navController: NavHostController,
    context: android.content.Context
) {
    val playTypeValue = context.settingsValue(SettingsKeys.iidxPlayType, IIDXPlayType.SINGLE.value)
    val playType = IIDXPlayType.fromValue(playTypeValue)
    val nowEpoch = System.currentTimeMillis() / 1000L
    val record = withContext(Dispatchers.IO) {
        val records = container.iidxRepository.songRecords(nowEpoch, playType)
        records.firstOrNull { it.title.compact == songName.compact }
            ?: records.firstOrNull { it.title.contains(songName, ignoreCase = true) }
    } ?: return
    val level = record.playedLevels().maxByOrNull { it.second.difficulty }?.first
    context.setSetting(SettingsKeys.selectedGame, Game.IIDX_ARCADE.id)
    navController.popBackStack(Routes.SCORES, inclusive = false)
    navController.navigate(Routes.iidxViewer(record.title, record.playType, level?.code.orEmpty(), nowEpoch))
}

private suspend fun <T> android.content.Context.settingsValue(
    key: androidx.datastore.preferences.core.Preferences.Key<T>,
    default: T
): T = settingFlow(key, default).first()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScoresShell(container: AppContainer, onNavigate: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val selectedGameId by context.settingFlow(SettingsKeys.selectedGame, 0).collectAsState(initial = 0)
    val selectedGame = Game.fromId(selectedGameId)
    val showAnalytics by context.settingFlow(SettingsKeys.showAnalytics, true).collectAsState(initial = true)
    val showProfileHeader by context.settingFlow(SettingsKeys.showProfileHeader, true)
        .collectAsState(initial = true)
    val isDDRExternalDataEnabled by context.settingFlow(SettingsKeys.externalDDREnabled, false)
        .collectAsState(initial = true)
    val sdvxVersionNumber by context.settingFlow(SettingsKeys.sdvxVersion, SDVXVersion.NABLA.number)
        .collectAsState(initial = SDVXVersion.NABLA.number)
    val iidxPlayTypeValue by context.settingFlow(SettingsKeys.iidxPlayType, IIDXPlayType.SINGLE.value)
        .collectAsState(initial = IIDXPlayType.SINGLE.value)
    val iidxPlayType = IIDXPlayType.fromValue(iidxPlayTypeValue)
    val ddrPlayStyleValue by context.settingFlow(SettingsKeys.ddrPlayStyle, DDRPlayStyle.SINGLE.value)
        .collectAsState(initial = DDRPlayStyle.SINGLE.value)
    val ddrPlayStyle = DDRPlayStyle.fromValue(ddrPlayStyleValue)

    var isGameMenuExpanded by remember { mutableStateOf(false) }
    var isMoreMenuExpanded by remember { mutableStateOf(false) }
    var pendingDialog by remember { mutableStateOf<PendingDialog?>(null) }
    var selectedTab by rememberSaveable(selectedGame) { mutableIntStateOf(0) }
    var isEditingAnalytics by rememberSaveable(selectedGame) { mutableStateOf(false) }
    var isRefreshing by remember { mutableStateOf(false) }
    val showAnalyticsTab = showAnalytics && selectedTab == 1

    suspend fun refreshProfile() {
        when (selectedGame) {
            Game.IIDX_ARCADE -> container.profileRepository.refreshIIDX()
            Game.SOUND_VOLTEX -> container.profileRepository.refreshSDVX(SDVXVersion.fromNumber(sdvxVersionNumber))
            Game.POLARIS_CHORD -> container.profileRepository.refreshPolarisChord()
            Game.DANCE_DANCE_REVOLUTION -> container.profileRepository.refreshDDR()
        }
    }

    LaunchedEffect(selectedGame) {
        container.importCompleted.collect { refreshProfile() }
    }

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
                    DropdownMenu(expanded = isGameMenuExpanded, onDismissRequest = { isGameMenuExpanded = false }) {
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
                                    if (game == selectedGame) Icon(Icons.Default.Check, contentDescription = null)
                                },
                                onClick = {
                                    scope.launch { context.setSetting(SettingsKeys.selectedGame, game.id) }
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
                        val versionName = when (selectedGame) {
                            Game.IIDX_ARCADE -> IIDXVersionInfo.MARKETING_NAME
                            Game.SOUND_VOLTEX -> SDVXVersion.fromNumber(sdvxVersionNumber).marketingName
                            Game.POLARIS_CHORD -> PolarisChordVersionInfo.MARKETING_NAME
                            Game.DANCE_DANCE_REVOLUTION -> DDRVersionInfo.MARKETING_NAME
                        }
                        DropdownMenuItem(
                            text = { Text(versionName) },
                            leadingIcon = { Icon(Icons.Default.Check, contentDescription = null) },
                            onClick = { isGameMenuExpanded = false }
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = { onNavigate(Routes.IMPORT) }) {
                        Icon(Icons.Default.SaveAlt, contentDescription = stringResource(R.string.shared_import))
                    }
                },
                actions = {
                    if (showAnalyticsTab) {
                        IconButton(onClick = { isEditingAnalytics = !isEditingAnalytics }) {
                            Icon(
                                if (isEditingAnalytics) Icons.Default.Check else Icons.Default.Edit,
                                contentDescription = stringResource(
                                    if (isEditingAnalytics) R.string.shared_done else R.string.shared_edit
                                )
                            )
                        }
                    }
                    IconButton(onClick = { isMoreMenuExpanded = true }) {
                        Icon(Icons.Default.MoreVert, contentDescription = stringResource(R.string.more_title))
                    }
                    MoreMenu(
                        expanded = isMoreMenuExpanded,
                        showProfileHeader = showProfileHeader,
                        showAnalytics = showAnalytics,
                        onDismiss = { isMoreMenuExpanded = false },
                        onNavigate = {
                            isMoreMenuExpanded = false
                            onNavigate(it)
                        },
                        onShowDialog = {
                            isMoreMenuExpanded = false
                            pendingDialog = it
                        }
                    )
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            when (selectedGame) {
                Game.IIDX_ARCADE -> PlayStyleSwitcher(
                    labels = IIDXPlayType.entries.map { it.displayName },
                    selectedIndex = IIDXPlayType.entries.indexOf(iidxPlayType)
                ) { index ->
                    scope.launch { context.setSetting(SettingsKeys.iidxPlayType, IIDXPlayType.entries[index].value) }
                }
                Game.DANCE_DANCE_REVOLUTION -> PlayStyleSwitcher(
                    labels = DDRPlayStyle.entries.map { it.value },
                    selectedIndex = DDRPlayStyle.entries.indexOf(ddrPlayStyle)
                ) { index ->
                    scope.launch { context.setSetting(SettingsKeys.ddrPlayStyle, DDRPlayStyle.entries[index].value) }
                }
                else -> Unit
            }
            if (showAnalytics) {
                PrimaryTabRow(selectedTabIndex = selectedTab) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = {
                            selectedTab = 0
                            isEditingAnalytics = false
                        },
                        text = { Text(stringResource(R.string.tab_scores)) }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text(stringResource(R.string.tab_analytics)) }
                    )
                }
            }
            PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = {
                    scope.launch {
                        isRefreshing = true
                        refreshProfile()
                        container.notifyDataChanged()
                        isRefreshing = false
                    }
                },
                modifier = Modifier.fillMaxSize()
            ) {
                val header: @Composable () -> Unit = {
                    Column(
                        modifier = Modifier.padding(horizontal = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        if (selectedGame == Game.DANCE_DANCE_REVOLUTION && !isDDRExternalDataEnabled) {
                            DDRDataSourceWarning(
                                onOpenDataSources = { onNavigate(Routes.EXTERNAL_DATA) },
                                modifier = Modifier.padding(top = 16.dp)
                            )
                        }
                        if (showProfileHeader) {
                            val headerModifier = Modifier.padding(top = 16.dp)
                            when (selectedGame) {
                                Game.IIDX_ARCADE -> IIDXProfileHeader(container, iidxPlayType, headerModifier)
                                Game.SOUND_VOLTEX -> SDVXProfileHeader(container, headerModifier)
                                Game.POLARIS_CHORD -> PolarisChordProfileHeader(container, headerModifier)
                                Game.DANCE_DANCE_REVOLUTION -> DDRProfileHeader(container, headerModifier)
                            }
                        }
                    }
                }
                if (showAnalyticsTab) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(bottom = 24.dp)
                    ) {
                        header()
                        Column(modifier = Modifier.padding(top = 20.dp)) {
                            when (selectedGame) {
                                Game.IIDX_ARCADE -> IIDXAnalyticsSection(
                                    container, iidxPlayType, isEditingAnalytics, onNavigate
                                )
                                Game.SOUND_VOLTEX -> SDVXAnalyticsSection(container, isEditingAnalytics, onNavigate)
                                Game.POLARIS_CHORD ->
                                    PolarisChordAnalyticsSection(container, isEditingAnalytics, onNavigate)
                                Game.DANCE_DANCE_REVOLUTION -> DDRAnalyticsSection(
                                    container, ddrPlayStyle, isEditingAnalytics, onNavigate
                                )
                            }
                        }
                    }
                } else {
                    when (selectedGame) {
                        Game.IIDX_ARCADE -> IIDXScoresScreen(
                            container = container,
                            contentPadding = PaddingValues(),
                            analyticsContent = header,
                            onOpenSong = { title, playType, level, date ->
                                onNavigate(Routes.iidxViewer(title, playType, level, date))
                            }
                        )
                        Game.SOUND_VOLTEX -> SDVXScoresScreen(
                            container = container,
                            contentPadding = PaddingValues(),
                            analyticsContent = header,
                            onOpenSong = { title, date, difficulty ->
                                onNavigate(Routes.sdvxViewer(title, date, difficulty))
                            }
                        )
                        Game.POLARIS_CHORD -> PolarisChordScoresScreen(
                            container = container,
                            contentPadding = PaddingValues(),
                            analyticsContent = header
                        )
                        Game.DANCE_DANCE_REVOLUTION -> DDRScoresScreen(
                            container = container,
                            contentPadding = PaddingValues(),
                            analyticsContent = header
                        )
                    }
                }
            }
        }
    }

    when (pendingDialog) {
        PendingDialog.DELETE_WEB -> ConfirmDialog(
            title = stringResource(R.string.more_delete_web_data_title),
            message = stringResource(R.string.more_delete_web_data_message),
            confirmLabel = stringResource(R.string.more_delete_web_data_confirm_button),
            onDismiss = { pendingDialog = null }
        ) {
            CookieManager.getInstance().removeAllCookies(null)
            CookieManager.getInstance().flush()
            WebStorage.getInstance().deleteAllData()
            Toast.makeText(context, context.getString(R.string.more_delete_web_data_done), Toast.LENGTH_SHORT).show()
        }
        PendingDialog.DELETE_SCORE_CODE -> DeleteScoreDataDialog(
            onConfirm = { pendingDialog = PendingDialog.DELETE_SCORE },
            onDismiss = { pendingDialog = null }
        )
        PendingDialog.DELETE_SCORE -> ConfirmDialog(
            title = stringResource(R.string.more_delete_score_data_title),
            message = stringResource(R.string.more_delete_score_data_subtitle),
            confirmLabel = stringResource(R.string.more_delete_score_data),
            onDismiss = { pendingDialog = null }
        ) {
            scope.launch(Dispatchers.IO) {
                container.iidxRepository.deleteAllData()
                container.sdvxRepository.deleteAllData()
                container.polarisChordRepository.deleteAllData()
                container.ddrRepository.deleteAllData()
                container.notifyDataChanged()
            }
            Toast.makeText(context, context.getString(R.string.more_delete_score_data_done), Toast.LENGTH_SHORT).show()
        }
        PendingDialog.RESET_LAYOUT -> ConfirmDialog(
            title = stringResource(R.string.more_reset_layout_title),
            message = stringResource(R.string.more_reset_layout_message),
            confirmLabel = stringResource(R.string.more_reset_layout),
            onDismiss = { pendingDialog = null }
        ) {
            isEditingAnalytics = false
            scope.launch { context.removeSettings(analyticsLayoutKeys) }
        }
        PendingDialog.DISCLAIMER -> AlertDialog(
            onDismissRequest = { pendingDialog = null },
            title = { Text(stringResource(R.string.more_disclaimer)) },
            text = { Text(stringResource(R.string.more_disclaimer_text)) },
            confirmButton = {
                TextButton(onClick = { pendingDialog = null }) { Text(stringResource(R.string.shared_ok)) }
            }
        )
        null -> Unit
    }
}

@Composable
private fun PlayStyleSwitcher(labels: List<String>, selectedIndex: Int, onSelect: (Int) -> Unit) {
    SingleChoiceSegmentedButtonRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        labels.forEachIndexed { index, label ->
            SegmentedButton(
                selected = selectedIndex == index,
                onClick = { onSelect(index) },
                shape = SegmentedButtonDefaults.itemShape(index, labels.size)
            ) {
                Text(label)
            }
        }
    }
}

@Composable
private fun MoreMenu(
    expanded: Boolean,
    showProfileHeader: Boolean,
    showAnalytics: Boolean,
    onDismiss: () -> Unit,
    onNavigate: (String) -> Unit,
    onShowDialog: (PendingDialog) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    DropdownMenu(expanded = expanded, onDismissRequest = onDismiss) {
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_external_data)) },
            leadingIcon = { Icon(Icons.Outlined.Storage, contentDescription = null) },
            onClick = { onNavigate(Routes.EXTERNAL_DATA) }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_show_profile_header)) },
            leadingIcon = { if (showProfileHeader) Icon(Icons.Default.Check, contentDescription = null) },
            onClick = { scope.launch { context.setSetting(SettingsKeys.showProfileHeader, !showProfileHeader) } }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_show_analytics)) },
            leadingIcon = { if (showAnalytics) Icon(Icons.Default.Check, contentDescription = null) },
            onClick = { scope.launch { context.setSetting(SettingsKeys.showAnalytics, !showAnalytics) } }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.radar_maker_title)) },
            leadingIcon = { Icon(Icons.Outlined.Hexagon, contentDescription = null) },
            onClick = { onNavigate(Routes.RADAR_MAKER) }
        )
        HorizontalDivider()
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_reset_layout)) },
            onClick = { onShowDialog(PendingDialog.RESET_LAYOUT) }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_delete_web_data)) },
            onClick = { onShowDialog(PendingDialog.DELETE_WEB) }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_delete_score_data)) },
            onClick = { onShowDialog(PendingDialog.DELETE_SCORE_CODE) }
        )
        HorizontalDivider()
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_github)) },
            onClick = {
                onDismiss()
                context.startActivity(Intent(Intent.ACTION_VIEW, "https://github.com/katagaki/DJDXGo".toUri()))
            }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_attributions)) },
            onClick = { onNavigate(Routes.ATTRIBUTIONS) }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.more_disclaimer)) },
            onClick = { onShowDialog(PendingDialog.DISCLAIMER) }
        )
    }
}

@Composable
private fun ConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(message) },
        confirmButton = {
            TextButton(onClick = {
                onDismiss()
                onConfirm()
            }) {
                Text(confirmLabel, color = MaterialTheme.colorScheme.error)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.shared_cancel)) }
        }
    )
}
