from pathlib import Path
import re

p = Path('app/src/main/java/com/osmus/gallery/MainActivity.kt')
s = p.read_text()
s = s.replace('import androidx.activity.compose.rememberLauncherForActivityResult', 'import androidx.activity.compose.BackHandler\nimport androidx.activity.compose.rememberLauncherForActivityResult')
s = s.replace('    LaunchedEffect(Unit) { vm.start() }\n', '''    LaunchedEffect(Unit) { vm.start() }\n\n    BackHandler(enabled = screen !is Screen.Albums || selection.isNotEmpty()) {\n        if (selection.isNotEmpty()) {\n            vm.clearSelection()\n        } else {\n            screen = when (val current = screen) {\n                is Screen.Viewer -> if (current.hidden) Screen.HiddenGrid(current.hiddenFolder ?: "Nascosti") else Screen.Grid(current.bucketId, current.title)\n                is Screen.Grid -> Screen.Albums\n                is Screen.HiddenGrid -> Screen.HiddenAlbums\n                is Screen.HiddenAlbums -> Screen.Albums\n                is Screen.Duplicates -> Screen.Albums\n                is Screen.Albums -> Screen.Albums\n            }\n        }\n    }\n''')
s = s.replace('val sender = vm.trashRequest(uris)\n            if (sender != null) hideLauncher.launch', 'val sender = vm.deleteRequest(uris)\n            if (sender != null) hideLauncher.launch')
p.write_text(s)

p = Path('app/src/main/java/com/osmus/gallery/ui/GalleryViewModel.kt')
s = p.read_text()
s = s.replace('    fun trashRequest(uris: List<Uri>) = repo.requestTrash(uris)\n', '    fun trashRequest(uris: List<Uri>) = repo.requestTrash(uris)\n\n    fun deleteRequest(uris: List<Uri>) = repo.requestDelete(uris)\n')
p.write_text(s)

p = Path('app/src/main/java/com/osmus/gallery/ui/GridScreens.kt')
s = p.read_text()
s = s.replace('import coil.compose.AsyncImage\n', 'import coil.ImageLoader\nimport coil.compose.AsyncImage\nimport coil.decode.VideoFrameDecoder\n')
old = '''    Box(
        Modifier.fillMaxWidth().aspectRatio(1f).background(Color(0xFF151618))
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
    ) {
        AsyncImage(
            model = ImageRequest.Builder(androidx.compose.ui.platform.LocalContext.current)
                .data(item.uri).crossfade(false).build(),
            contentDescription = item.name,
            contentScale = if (square) ContentScale.Crop else ContentScale.Fit,
            modifier = Modifier.fillMaxSize(),
        )'''
new = '''    val context = androidx.compose.ui.platform.LocalContext.current
    val videoLoader = remember(context) {
        ImageLoader.Builder(context).components { add(VideoFrameDecoder.Factory()) }.build()
    }
    Box(
        Modifier.fillMaxWidth().aspectRatio(1f).background(Color(0xFF151618))
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
    ) {
        val request = ImageRequest.Builder(context)
            .data(if (item.hidden && item.localPath != null) java.io.File(item.localPath) else item.uri)
            .crossfade(false).build()
        if (item.isVideo) {
            AsyncImage(model = request, imageLoader = videoLoader, contentDescription = item.name, contentScale = if (square) ContentScale.Crop else ContentScale.Fit, modifier = Modifier.fillMaxSize())
        } else {
            AsyncImage(model = request, contentDescription = item.name, contentScale = if (square) ContentScale.Crop else ContentScale.Fit, modifier = Modifier.fillMaxSize())
        }'''
if old not in s: raise SystemExit('MediaThumb replace failed')
s = s.replace(old, new)
p.write_text(s)

p = Path('app/src/main/java/com/osmus/gallery/ui/ViewerScreen.kt')
s = p.read_text()
s = s.replace('import androidx.compose.material.icons.filled.Info\n', 'import androidx.compose.material.icons.filled.Info\nimport androidx.compose.material.icons.filled.Pause\nimport androidx.compose.material.icons.filled.PlayArrow\nimport androidx.compose.material.icons.filled.SkipNext\nimport androidx.compose.material.icons.filled.SkipPrevious\n')
s = s.replace('import androidx.compose.material3.IconButton\n', 'import androidx.compose.material3.IconButton\nimport androidx.compose.material3.Slider\n')
s = s.replace('import androidx.compose.runtime.mutableFloatStateOf\n', 'import androidx.compose.runtime.mutableFloatStateOf\nimport androidx.compose.runtime.mutableLongStateOf\n')
s = s.replace('import androidx.compose.runtime.remember\n', 'import androidx.compose.runtime.remember\nimport androidx.compose.runtime.rememberCoroutineScope\n')
s = s.replace('import java.util.Locale\n', 'import java.util.Locale\nimport kotlinx.coroutines.delay\nimport kotlinx.coroutines.launch\n')
s = s.replace('    val context = LocalContext.current\n    val pagerState = rememberPagerState(', '    val context = LocalContext.current\n    val scope = rememberCoroutineScope()\n    val pagerState = rememberPagerState(')

needle = '''                IconButton(onClick = { detailsVisible = !detailsVisible }) {
                    Icon(Icons.Filled.Info, "Dettagli", tint = Color.White)
                }'''
repl = '''                IconButton(onClick = {
                    if (pagerState.currentPage > 0) scope.launch { pagerState.animateScrollToPage(pagerState.currentPage - 1) }
                }, enabled = pagerState.currentPage > 0) {
                    Icon(Icons.Filled.SkipPrevious, "Precedente", tint = if (pagerState.currentPage > 0) Color.White else Color.Gray)
                }
                IconButton(onClick = {
                    if (pagerState.currentPage < items.lastIndex) scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                }, enabled = pagerState.currentPage < items.lastIndex) {
                    Icon(Icons.Filled.SkipNext, "Successivo", tint = if (pagerState.currentPage < items.lastIndex) Color.White else Color.Gray)
                }
                IconButton(onClick = { detailsVisible = !detailsVisible }) {
                    Icon(Icons.Filled.Info, "Dettagli", tint = Color.White)
                }'''
if needle not in s: raise SystemExit('viewer nav replace failed')
s = s.replace(needle, repl)

gif_re = re.compile(r'@Composable\nprivate fun GifViewer\(item: MediaItem, onTap: \(\) -> Unit\) \{.*?\n\}\n\n@Composable\nprivate fun ZoomableImage', re.S)
gif_new = '''@Composable
private fun GifViewer(item: MediaItem, onTap: () -> Unit) {
    val context = LocalContext.current
    val gifLoader = remember(context) {
        ImageLoader.Builder(context).components {
            if (Build.VERSION.SDK_INT >= 28) add(ImageDecoderDecoder.Factory()) else add(GifDecoder.Factory())
        }.build()
    }
    val request = remember(item.uri, item.localPath) {
        ImageRequest.Builder(context).data(if (item.hidden && item.localPath != null) File(item.localPath) else item.uri).crossfade(false).build()
    }
    var scale by remember(item.id) { mutableFloatStateOf(1f) }
    Box(Modifier.fillMaxSize().pointerInput(item.id) {
        detectTapGestures(onTap = { onTap() }, onDoubleTap = { scale = if (scale > 1f) 1f else 2.5f })
    }) {
        AsyncImage(model = request, imageLoader = gifLoader, contentDescription = item.name, contentScale = ContentScale.Fit,
            modifier = Modifier.fillMaxSize().graphicsLayer(scaleX = scale, scaleY = scale))
    }
}

@Composable
private fun ZoomableImage'''
s, n = gif_re.subn(gif_new, s)
if n != 1: raise SystemExit(f'GifViewer replace failed: {n}')

s = re.sub(r'\n            \.pointerInput\(item\.id\) \{\n                detectTransformGestures \{ _, pan, zoom, _ ->.*?\n                \}\n            \}', '', s, flags=re.S)

video_re = re.compile(r'@Composable\nprivate fun VideoPlayer\(item: MediaItem, isActive: Boolean, onTap: \(\) -> Unit\) \{.*?\n\}\n\n@Composable\nprivate fun GifViewer', re.S)
video_new = '''@Composable
private fun VideoPlayer(item: MediaItem, isActive: Boolean, onTap: () -> Unit) {
    val context = LocalContext.current
    val source = remember(item.uri, item.localPath) { if (item.hidden && item.localPath != null) android.net.Uri.fromFile(File(item.localPath)) else item.uri }
    val player = remember(source) { ExoPlayer.Builder(context).build().apply { setMediaItem(ExoMediaItem.fromUri(source)); repeatMode = Player.REPEAT_MODE_OFF; prepare() } }
    var playing by remember(player) { mutableStateOf(false) }
    var position by remember(player) { mutableLongStateOf(0L) }
    var duration by remember(player) { mutableLongStateOf(item.durationMs.coerceAtLeast(0L)) }
    LaunchedEffect(isActive, player) {
        if (!isActive) player.pause()
        while (isActive) { playing = player.isPlaying; position = player.currentPosition.coerceAtLeast(0L); if (player.duration > 0) duration = player.duration; delay(250) }
    }
    DisposableEffect(player) { onDispose { player.release() } }
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(modifier = Modifier.fillMaxSize(), factory = { ctx -> PlayerView(ctx).apply { this.player = player; useController = false; isClickable = false; resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT; setShowBuffering(PlayerView.SHOW_BUFFERING_WHEN_PLAYING) } }, update = { it.player = player })
        Box(Modifier.fillMaxSize().pointerInput(item.id) { detectTapGestures(onTap = { onTap() }) })
        Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(Color.Black.copy(alpha = 0.62f)).padding(horizontal = 14.dp, vertical = 8.dp)) {
            val max = duration.coerceAtLeast(1L).toFloat()
            Slider(value = position.coerceAtMost(duration.coerceAtLeast(1L)).toFloat(), onValueChange = { position = it.toLong() }, onValueChangeFinished = { player.seekTo(position) }, valueRange = 0f..max)
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                Text("${formatVideoTime(position)} / ${formatVideoTime(duration)}", color = Color.White, fontSize = 12.sp)
                IconButton(onClick = { if (player.isPlaying) player.pause() else player.play(); playing = player.isPlaying }) { Icon(if (playing) Icons.Filled.Pause else Icons.Filled.PlayArrow, if (playing) "Pausa" else "Riproduci", tint = Color.White) }
            }
        }
    }
}

private fun formatVideoTime(ms: Long): String { val s = ms.coerceAtLeast(0L) / 1000L; return "%d:%02d".format(s / 60, s % 60) }

@Composable
private fun GifViewer'''
s, n = video_re.subn(video_new, s)
if n != 1: raise SystemExit(f'VideoPlayer replace failed: {n}')
p.write_text(s)

p = Path('app/build.gradle.kts')
s = p.read_text().replace('versionCode = 5', 'versionCode = 6').replace('versionName = "0.5.0"', 'versionName = "0.6.0"')
p.write_text(s)
