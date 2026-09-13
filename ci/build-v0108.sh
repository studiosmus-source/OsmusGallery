#!/usr/bin/env bash
set -euo pipefail
cat ci/v09_exact_00.bin ci/v09_exact_01.bin ci/v09_exact_02.bin ci/v09_exact_03.bin > /tmp/OsmusGallery_v0.9.zip
rm -rf project
mkdir project
unzip -q /tmp/OsmusGallery_v0.9.zip "app/*" "build.gradle.kts" "settings.gradle.kts" "gradle.properties" "gradle/*" -d project
cp -a project/. .

sed -i 's/import androidx.compose.ui.input.pointer.calculatePan/import androidx.compose.foundation.gestures.calculatePan/' app/src/main/java/com/osmus/gallery/ui/ViewerScreen.kt
sed -i 's/import androidx.compose.ui.input.pointer.calculateZoom/import androidx.compose.foundation.gestures.calculateZoom/' app/src/main/java/com/osmus/gallery/ui/ViewerScreen.kt
sed -i '/vm.onHideFinished(success)/d' app/src/main/java/com/osmus/gallery/MainActivity.kt
sed -i 's/"Nascosti"/"VAULT"/g; s/Cassaforte/VAULT/g' app/src/main/java/com/osmus/gallery/ui/GridScreens.kt app/src/main/java/com/osmus/gallery/MainActivity.kt

python3 - <<'PY'
from pathlib import Path
import re

p = Path("app/src/main/java/com/osmus/gallery/ui/ViewerScreen.kt")
s = p.read_text()

additions = {
    "import android.os.Build\n": "import android.os.Build\nimport android.graphics.Bitmap\nimport android.view.TextureView\nimport android.view.ViewGroup\n",
    "import androidx.compose.foundation.background\n": "import androidx.compose.foundation.background\nimport androidx.compose.foundation.Image\nimport androidx.compose.foundation.shape.CircleShape\n",
    "import androidx.compose.foundation.gestures.detectTapGestures\n": "import androidx.compose.foundation.gestures.detectTapGestures\nimport androidx.compose.foundation.gestures.detectDragGestures\nimport androidx.compose.foundation.gestures.calculateCentroid\n",
    "import androidx.compose.foundation.layout.padding\n": "import androidx.compose.foundation.layout.padding\nimport androidx.compose.foundation.layout.size\nimport androidx.compose.foundation.layout.offset\n",
    "import androidx.compose.material3.Slider\n": "import androidx.compose.material3.Slider\nimport androidx.compose.material3.TextButton\n",
    "import androidx.compose.ui.graphics.Color\n": "import androidx.compose.ui.graphics.Color\nimport androidx.compose.ui.graphics.asImageBitmap\nimport androidx.compose.ui.graphics.TransformOrigin\nimport androidx.compose.ui.draw.clip\n",
    "import androidx.compose.ui.layout.ContentScale\n": "import androidx.compose.ui.layout.ContentScale\nimport androidx.compose.ui.layout.onSizeChanged\n",
    "import androidx.compose.ui.platform.LocalContext\n": "import androidx.compose.ui.platform.LocalContext\nimport androidx.compose.ui.platform.LocalDensity\n",
    "import androidx.compose.ui.unit.dp\n": "import androidx.compose.ui.unit.dp\nimport androidx.compose.ui.unit.IntOffset\n",
    "import java.util.Locale\n": "import java.util.Locale\nimport kotlin.math.roundToInt\n",
}
for a,b in additions.items():
    s = s.replace(a,b,1)

video = r'''@Composable
private fun VideoPlayer(
    item: MediaItem,
    isActive: Boolean,
    hasPrevious: Boolean,
    hasNext: Boolean,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onTap: () -> Unit,
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val sourceUri = remember(item.uri, item.localPath) {
        if (item.hidden && item.localPath != null) android.net.Uri.fromFile(File(item.localPath)) else item.uri
    }
    val player = remember(sourceUri) {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(ExoMediaItem.fromUri(sourceUri))
            repeatMode = if (item.name.startsWith("OsmusLoop_", ignoreCase = true)) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
            prepare()
        }
    }

    var textureView by remember { mutableStateOf<TextureView?>(null) }
    var ratioFrame by remember { mutableStateOf<AspectRatioFrameLayout?>(null) }
    var playing by remember(player) { mutableStateOf(false) }
    var position by remember(player) { mutableLongStateOf(0L) }
    var duration by remember(player) { mutableLongStateOf(item.durationMs.coerceAtLeast(0L)) }

    var lensEnabled by remember(item.id) { mutableStateOf(false) }
    var lensZoom by remember(item.id) { mutableFloatStateOf(4f) }
    var lensCenter by remember(item.id) { mutableStateOf(Offset.Zero) }
    var viewportSize by remember(item.id) { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
    var lensBitmap by remember(item.id) { mutableStateOf<androidx.compose.ui.graphics.ImageBitmap?>(null) }

    val lensDiameter = 190.dp
    val lensRadiusPx = with(density) { lensDiameter.toPx() / 2f }

    LaunchedEffect(isActive, player) {
        if (!isActive) player.pause()
        while (isActive) {
            playing = player.isPlaying
            position = player.currentPosition.coerceAtLeast(0L)
            if (player.duration > 0) duration = player.duration

            val vs = player.videoSize
            if (vs.width > 0 && vs.height > 0) {
                val ar = (vs.width * vs.pixelWidthHeightRatio) / vs.height.toFloat()
                ratioFrame?.setAspectRatio(ar)
            }
            delay(250)
        }
    }

    LaunchedEffect(lensEnabled, lensZoom, textureView, viewportSize) {
        while (lensEnabled) {
            val tv = textureView
            val vw = viewportSize.width
            val vh = viewportSize.height
            if (tv != null && tv.isAvailable && vw > 0 && vh > 0) {
                val src = tv.bitmap
                if (src != null && src.width > 1 && src.height > 1) {
                    val cxNorm = (lensCenter.x / vw.toFloat()).coerceIn(0f, 1f)
                    val cyNorm = (lensCenter.y / vh.toFloat()).coerceIn(0f, 1f)
                    val cropW = (src.width / lensZoom).roundToInt().coerceAtLeast(1)
                    val cropH = (src.height / lensZoom).roundToInt().coerceAtLeast(1)
                    val cx = (cxNorm * src.width).roundToInt()
                    val cy = (cyNorm * src.height).roundToInt()
                    val left = (cx - cropW / 2).coerceIn(0, (src.width - cropW).coerceAtLeast(0))
                    val top = (cy - cropH / 2).coerceIn(0, (src.height - cropH).coerceAtLeast(0))
                    lensBitmap = Bitmap.createBitmap(src, left, top, cropW, cropH).asImageBitmap()
                }
            }
            delay(100)
        }
    }

    DisposableEffect(player) {
        onDispose { player.release() }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .onSizeChanged {
                viewportSize = it
                if (lensCenter == Offset.Zero) lensCenter = Offset(it.width / 2f, it.height / 2f)
            }
    ) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                AspectRatioFrameLayout(ctx).apply {
                    resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
                    ratioFrame = this
                    val tv = TextureView(ctx)
                    addView(
                        tv,
                        ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT,
                        ),
                    )
                    textureView = tv
                    player.setVideoTextureView(tv)
                }
            },
            update = { frame ->
                ratioFrame = frame
                val tv = frame.getChildAt(0) as TextureView
                textureView = tv
                player.setVideoTextureView(tv)
            },
        )

        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(item.id) { detectTapGestures(onTap = { onTap() }) }
        )

        if (lensEnabled) {
            lensBitmap?.let { bmp ->
                Image(
                    bitmap = bmp,
                    contentDescription = "Lente video ${lensZoom.toInt()}x",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .offset {
                            IntOffset(
                                (lensCenter.x - lensRadiusPx).roundToInt(),
                                (lensCenter.y - lensRadiusPx).roundToInt(),
                            )
                        }
                        .size(lensDiameter)
                        .clip(CircleShape)
                        .background(Color.Black)
                        .pointerInput(item.id, lensZoom) {
                            detectDragGestures { change, drag ->
                                change.consume()
                                val maxX = viewportSize.width.toFloat()
                                val maxY = viewportSize.height.toFloat()
                                lensCenter = Offset(
                                    (lensCenter.x + drag.x).coerceIn(
                                        lensRadiusPx,
                                        (maxX - lensRadiusPx).coerceAtLeast(lensRadiusPx)
                                    ),
                                    (lensCenter.y + drag.y).coerceIn(
                                        lensRadiusPx,
                                        (maxY - lensRadiusPx).coerceAtLeast(lensRadiusPx)
                                    ),
                                )
                            }
                        },
                )
            }

        }

        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .background(Color.Black.copy(alpha = 0.62f))
                .padding(horizontal = 14.dp, vertical = 8.dp),
        ) {
            if (lensEnabled) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(bottom = 2.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    listOf(2f, 4f, 8f, 16f, 32f).forEach { z ->
                        TextButton(
                            onClick = { lensZoom = z },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text(
                                "${z.toInt()}×",
                                color = if (lensZoom == z) Color.White else Color.Gray,
                                fontWeight = if (lensZoom == z) FontWeight.Bold else FontWeight.Normal,
                            )
                        }
                    }
                }
            }
            val max = duration.coerceAtLeast(1L).toFloat()
            Slider(
                value = position.coerceAtMost(duration.coerceAtLeast(1L)).toFloat(),
                onValueChange = { position = it.toLong() },
                onValueChangeFinished = { player.seekTo(position) },
                valueRange = 0f..max,
            )
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("${formatTime(position)} / ${formatTime(duration)}", color = Color.White, fontSize = 12.sp)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = { lensEnabled = !lensEnabled }) {
                        Text(if (lensEnabled) "Lente ${lensZoom.toInt()}×" else "Lente", color = Color.White)
                    }
                    IconButton(onClick = onPrevious, enabled = hasPrevious) {
                        Icon(Icons.Filled.SkipPrevious, "Precedente", tint = if (hasPrevious) Color.White else Color.Gray)
                    }
                    IconButton(onClick = {
                        if (player.isPlaying) player.pause() else player.play()
                        playing = player.isPlaying
                    }) {
                        Icon(
                            if (playing) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                            if (playing) "Pausa" else "Riproduci",
                            tint = Color.White
                        )
                    }
                    IconButton(onClick = onNext, enabled = hasNext) {
                        Icon(Icons.Filled.SkipNext, "Successivo", tint = if (hasNext) Color.White else Color.Gray)
                    }
                }
            }
        }
    }
}
'''

s = re.sub(
    r'@Composable\nprivate fun VideoPlayer\(.*?\n\}\n\n@Composable\nprivate fun ZoomableImage',
    video + '\n@Composable\nprivate fun ZoomableImage',
    s,
    count=1,
    flags=re.S,
)

s = s.replace(
    '    var offset by remember(item.id) { mutableStateOf(Offset.Zero) }\n',
    '    var offset by remember(item.id) { mutableStateOf(Offset.Zero) }\n'
    '    var imageViewport by remember(item.id) { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }\n',
    1,
)

s = s.replace(
    '            .fillMaxSize()\n            .pointerInput(item.id) {\n                detectTapGestures(',
    '            .fillMaxSize()\n            .onSizeChanged { imageViewport = it }\n'
    '            .pointerInput(item.id) {\n                detectTapGestures(',
    1,
)

s = s.replace(
    '''                        } else {
                  scale = 4f
              }''',
    '''                        } else {
                  scale = 4f
                  val c = Offset(imageViewport.width / 2f, imageViewport.height / 2f)
                  offset = c - c * scale
              }''',
    1,
)

new = '''            .pointerInput(item.id) {
      awaitEachGesture {
          awaitFirstDown(requireUnconsumed = false)
          do {
              val event = awaitPointerEvent(PointerEventPass.Main)
              val pressedCount = event.changes.count { it.pressed }
              if (pressedCount > 0 && (pressedCount >= 2 || scale > 1f)) {
                  val zoom = if (pressedCount >= 2) event.calculateZoom() else 1f
                  val pan = event.calculatePan()
                  val centroid = event.calculateCentroid(useCurrent = true)
                  val oldScale = scale
                  val newScale = (oldScale * zoom).coerceIn(1f, 32f)
                  val factor = if (oldScale > 0f) newScale / oldScale else 1f
                  val rawOffset = if (newScale > 1f) {
                      centroid - (centroid - offset) * factor + (pan * factor)
                  } else Offset.Zero
                  val minX = -imageViewport.width.toFloat() * (newScale - 1f)
                  val minY = -imageViewport.height.toFloat() * (newScale - 1f)
                  offset = if (newScale > 1f) {
                      Offset(
                          rawOffset.x.coerceIn(minX, 0f),
                          rawOffset.y.coerceIn(minY, 0f),
                      )
                  } else Offset.Zero
                  scale = newScale
                  event.changes.forEach { if (it.pressed) it.consume() }
              }
          } while (event.changes.any { it.pressed })
          if (scale <= 1.12f) {
              scale = 1f
              offset = Offset.Zero
          }
      }
  }'''

z0 = s.index("private fun ZoomableImage")
p0 = s.index("            .pointerInput(item.id, scale) {", z0)
p1 = s.index("\n    ) {", p0)
s = s[:p0] + new + s[p1:]

s = s.replace(
    '                        translationY = offset.y,\n                    ),',
    '                        translationY = offset.y,\n'
    '                        transformOrigin = TransformOrigin(0f, 0f),\n'
    '                    ),',
)

p.write_text(s)


gp = Path("app/src/main/java/com/osmus/gallery/ui/GridScreens.kt")
gs = gp.read_text()

albums_fn = r'''@Composable
fun AlbumsScreen(
    albums: List<Album>,
    columns: Int,
    onOpenAlbum: (Long) -> Unit,
    onOpenAll: () -> Unit,
    onOpenDuplicates: () -> Unit,
    onOpenTools: () -> Unit,
    onOpenHidden: () -> Unit,
    onHideAlbum: (Album) -> Unit,
    onMoveAlbum: (Album) -> Unit,
    totalCount: Int,
    hiddenCount: Int,
) {
    var albumSortMenu by remember { mutableStateOf(false) }
    var albumSort by remember { mutableStateOf("recenti") }

    val shownAlbums = when (albumSort) {
        "nome_az" -> albums.sortedBy { it.name.lowercase() }
        "nome_za" -> albums.sortedByDescending { it.name.lowercase() }
        "vecchie" -> albums.sortedBy { it.newest }
        "piu" -> albums.sortedByDescending { it.count }
        "meno" -> albums.sortedBy { it.count }
        else -> albums.sortedByDescending { it.newest }
    }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text("Galleria", fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Text(
                    "$totalCount elementi in \${albums.size} cartelle",
                    color = Color(0xFF9A9A97), fontSize = 13.sp,
                )
            }
            Box {
                IconButton(onClick = { albumSortMenu = true }) {
                    Icon(Icons.Filled.Sort, contentDescription = "Ordina cartelle")
                }
                DropdownMenu(expanded = albumSortMenu, onDismissRequest = { albumSortMenu = false }) {
                    listOf(
                        "recenti" to "Più recenti",
                        "vecchie" to "Meno recenti",
                        "nome_az" to "Nome A→Z",
                        "nome_za" to "Nome Z→A",
                        "piu" to "Più elementi",
                        "meno" to "Meno elementi",
                    ).forEach { (key, label) ->
                        DropdownMenuItem(
                            text = {
                                Text(
                                    label,
                                    fontWeight = if (albumSort == key) FontWeight.Bold else FontWeight.Normal,
                                )
                            },
                            onClick = {
                                albumSort = key
                                albumSortMenu = false
                            },
                        )
                    }
                }
            }
            IconButton(onClick = onOpenTools) {
                Icon(Icons.Filled.MovieCreation, contentDescription = "Crea clip animata")
            }
            IconButton(onClick = onOpenDuplicates) {
                Icon(Icons.Filled.ContentCopy, contentDescription = "Cerca duplicati")
            }
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(columns.coerceIn(2, 4)),
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                AlbumTile(
                    title = "Tutti gli elementi", count = totalCount,
                    cover = shownAlbums.firstOrNull()?.cover, onClick = onOpenAll,
                )
            }
            item {
                AlbumTile(
                    title = "VAULT", count = hiddenCount,
                    cover = null, onClick = onOpenHidden,
                    badgeIcon = { Icon(Icons.Filled.VisibilityOff, "VAULT", tint = Color.White) },
                )
            }
            items(shownAlbums, key = { it.bucketId }) { album ->
                AlbumTile(
                    title = album.name,
                    count = album.count,
                    cover = album.cover,
                    onClick = { onOpenAlbum(album.bucketId) },
                    menuItems = listOf(
                        "Sposta cartella…" to { onMoveAlbum(album) },
                        "Nascondi cartella" to { onHideAlbum(album) },
                    ),
                )
            }
        }
    }
}
'''

a0 = gs.index("@Composable\nfun AlbumsScreen(")
a1 = gs.index("\n@Composable\nfun HiddenAlbumsScreen(", a0)
gs = gs[:a0] + albums_fn + gs[a1:]

album_tile_fn = r'''@Composable
private fun AlbumTile(
    title: String,
    count: Int,
    cover: android.net.Uri?,
    onClick: () -> Unit,
    menuItems: List<Pair<String, () -> Unit>> = emptyList(),
    badgeIcon: (@Composable () -> Unit)? = null,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Column(
        Modifier
            .padding(3.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFF18191B))
            .combinedClickable(onClick = onClick)
            .padding(bottom = 9.dp)
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(1.08f)
                .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
                .background(Color(0xFF242528))
        ) {
            if (cover != null) {
                AsyncImage(
                    model = cover,
                    contentDescription = title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            }
            if (badgeIcon != null) {
                Box(
                    Modifier
                        .align(Alignment.Center)
                        .clip(RoundedCornerShape(999.dp))
                        .background(Color.Black.copy(alpha = 0.45f))
                        .padding(12.dp)
                ) { badgeIcon() }
            }
            if (menuItems.isNotEmpty()) {
                Box(Modifier.align(Alignment.TopEnd)) {
                    IconButton(onClick = { menuOpen = true }) {
                        Icon(Icons.Filled.MoreVert, "Menu", tint = Color.White)
                    }
                    DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                        menuItems.forEach { (label, action) ->
                            DropdownMenuItem(text = { Text(label) }, onClick = {
                                menuOpen = false
                                action()
                            })
                        }
                    }
                }
            }
        }
        Text(
            title,
            maxLines = 1,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 10.dp, end = 10.dp, top = 9.dp),
        )
        Text(
            if (count == 1) "1 elemento" else "$count elementi",
            fontSize = 11.sp,
            color = Color(0xFF9A9A97),
            modifier = Modifier.padding(start = 10.dp, end = 10.dp, top = 2.dp),
        )
    }
}
'''

t0 = gs.index("@Composable\nprivate fun AlbumTile(")
t1 = gs.index("\n@Composable\nfun PhotoGridScreen(", t0)
gs = gs[:t0] + album_tile_fn + gs[t1:]
gp.write_text(gs)


# v0.10.8: physical move support, looping video/back behavior, and ghost-row filtering.
gp = Path("app/src/main/java/com/osmus/gallery/ui/GridScreens.kt")
gs = gp.read_text()

# Add physical-move action to the media grid after the v0.10.7 UI has been generated.
gs = gs.replace(
    '''    onToggleSelect: (Long) -> Unit,
    onHideSelected: () -> Unit = {},''',
    '''    onToggleSelect: (Long) -> Unit,
    onMoveSelected: () -> Unit = {},
    onHideSelected: () -> Unit = {},''',
    1,
)
gs = gs.replace(
    '''            if (selection.isNotEmpty()) {
                IconButton(onClick = if (hiddenMode) onRestoreSelected else onHideSelected) {''',
    '''            if (selection.isNotEmpty()) {
                if (!hiddenMode) {
                    IconButton(onClick = onMoveSelected) {
                        Icon(Icons.Filled.DriveFileMove, contentDescription = "Sposta")
                    }
                }
                IconButton(onClick = if (hiddenMode) onRestoreSelected else onHideSelected) {''',
    1,
)
if "onMoveSelected: () -> Unit = {}" not in gs:
    raise SystemExit("PhotoGridScreen move hook was not applied")

if "import androidx.compose.material.icons.filled.DriveFileMove\n" not in gs:
    gs = gs.replace(
        "import androidx.compose.material.icons.filled.ContentCopy\n",
        "import androidx.compose.material.icons.filled.ContentCopy\nimport androidx.compose.material.icons.filled.DriveFileMove\n",
        1,
    )
gp.write_text(gs)

rp = Path("app/src/main/java/com/osmus/gallery/data/MediaRepository.kt")
rs = rp.read_text()

rs = rs.replace(
    '''        val cursor: Cursor = resolver.query(
            base, projection, null, null,
            "${MediaStore.MediaColumns.DATE_MODIFIED} DESC"
        ) ?: return out''',
    '''        val selectionParts = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add("${MediaStore.MediaColumns.IS_PENDING}=0")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                add("${MediaStore.MediaColumns.IS_TRASHED}=0")
            }
        }
        val selection = selectionParts.takeIf { it.isNotEmpty() }?.joinToString(" AND ")
        val cursor: Cursor = resolver.query(
            base, projection, selection, null,
            "${MediaStore.MediaColumns.DATE_MODIFIED} DESC"
        ) ?: return out''',
    1,
)
rs = rs.replace(
    '''            while (c.moveToNext()) {
                val id = c.getLong(iId)
                out += MediaItem(''',
    '''            while (c.moveToNext()) {
                val rowSize = c.getLong(iSize)
                if (rowSize <= 0L) continue
                val id = c.getLong(iId)
                out += MediaItem(''',
    1,
)
rs = rs.replace("                    size = c.getLong(iSize),", "                    size = rowSize,", 1)

move_methods = r'''
    fun requestWrite(uris: List<Uri>): IntentSender? {
        if (uris.isEmpty()) return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            MediaStore.createWriteRequest(resolver, uris).intentSender
        } else null
    }

    suspend fun moveItems(items: List<MediaItem>, targetRelativePath: String): Int =
        withContext(Dispatchers.IO) {
            if (items.isEmpty()) return@withContext 0
            val target = targetRelativePath.trim('/').let { if (it.isBlank()) "DCIM/" else "$it/" }
            items.count { item ->
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, target)
                }
                runCatching { resolver.update(item.uri, values, null, null) > 0 }.getOrDefault(false)
            }
        }

'''
marker = "    /** Sposta nel cestino di sistema (recuperabile 30 giorni) su API 30+. */"
if move_methods.strip() not in rs:
    rs = rs.replace(marker, move_methods + marker, 1)
rp.write_text(rs)

vp = Path("app/src/main/java/com/osmus/gallery/ui/GalleryViewModel.kt")
vs = vp.read_text()
vm_methods = r'''
    fun writeRequest(uris: List<Uri>) = repo.requestWrite(uris)

    fun moveItems(items: List<MediaItem>, targetRelativePath: String) {
        viewModelScope.launch {
            repo.moveItems(items, targetRelativePath)
            clearSelection()
            reload()
        }
    }

'''
marker = "    fun trashRequest(uris: List<Uri>) = repo.requestTrash(uris)"
if vm_methods.strip() not in vs:
    vs = vs.replace(marker, vm_methods + marker, 1)
vp.write_text(vs)

mp = Path("app/src/main/java/com/osmus/gallery/MainActivity.kt")
ms = mp.read_text()
ms = ms.replace(
    "import android.os.Bundle\n",
    "import android.os.Bundle\nimport android.provider.DocumentsContract\nimport android.widget.Toast\n",
    1,
)

state_anchor = "    var uninstallGuardEnabled by remember { mutableStateOf(devicePolicyManager.isAdminActive(adminComponent)) }\n"
state_insert = r'''    var pendingMoveItems by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var pendingMoveFolderName by remember { mutableStateOf<String?>(null) }
    var pendingMoveTarget by remember { mutableStateOf<String?>(null) }
'''
if state_insert.strip() not in ms:
    ms = ms.replace(state_anchor, state_anchor + state_insert, 1)

launcher_anchor = '''    val trashLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { vm.onDeletionFinished() }
'''
move_launchers = r'''
    val moveWriteLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { result ->
        val target = pendingMoveTarget
        val items = pendingMoveItems
        if (result.resultCode == Activity.RESULT_OK && target != null && items.isNotEmpty()) {
            vm.moveItems(items, target)
        }
        pendingMoveItems = emptyList()
        pendingMoveFolderName = null
        pendingMoveTarget = null
    }

    val moveTreeLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri ->
        if (uri == null) {
            pendingMoveItems = emptyList()
            pendingMoveFolderName = null
            pendingMoveTarget = null
        } else {
            val docId = runCatching { DocumentsContract.getTreeDocumentId(uri) }.getOrNull()
            val relative = when {
                docId == null -> null
                docId == "primary:" -> "DCIM/"
                docId.startsWith("primary:") -> docId.substringAfter("primary:").trim('/').let {
                    if (it.isBlank()) "DCIM/" else "$it/"
                }
                else -> null
            }

            if (relative == null) {
                Toast.makeText(
                    context,
                    "Per ora lo spostamento supporta la memoria interna del telefono.",
                    Toast.LENGTH_LONG,
                ).show()
                pendingMoveItems = emptyList()
                pendingMoveFolderName = null
                pendingMoveTarget = null
            } else {
                val target = pendingMoveFolderName?.let { "$relative${it.trim('/')}/" } ?: relative
                pendingMoveTarget = target
                val sender = vm.writeRequest(pendingMoveItems.map { it.uri })
                if (sender != null) {
                    moveWriteLauncher.launch(IntentSenderRequest.Builder(sender).build())
                } else {
                    vm.moveItems(pendingMoveItems, target)
                    pendingMoveItems = emptyList()
                    pendingMoveFolderName = null
                    pendingMoveTarget = null
                }
            }
        }
    }

    fun moveFiles(items: List<MediaItem>) {
        if (items.isEmpty()) return
        pendingMoveItems = items
        pendingMoveFolderName = null
        pendingMoveTarget = null
        moveTreeLauncher.launch(null)
    }

    fun moveAlbum(album: com.osmus.gallery.data.Album) {
        val items = vm.itemsOf(album.bucketId)
        if (items.isEmpty()) {
            vm.reload()
            Toast.makeText(context, "La cartella è vuota e verrà rimossa dall'elenco.", Toast.LENGTH_SHORT).show()
            return
        }
        pendingMoveItems = items
        pendingMoveFolderName = album.name
        pendingMoveTarget = null
        moveTreeLauncher.launch(null)
    }
'''
if move_launchers.strip() not in ms:
    ms = ms.replace(launcher_anchor, launcher_anchor + move_launchers, 1)

ms = ms.replace(
    '''                    onHideAlbum = { album ->
                        vm.hideAlbum(album.bucketId)
                        if (!uninstallGuardEnabled) enableUninstallGuard()
                    },
                )''',
    '''                    onHideAlbum = { album ->
                        vm.hideAlbum(album.bucketId)
                        if (!uninstallGuardEnabled) enableUninstallGuard()
                    },
                    onMoveAlbum = ::moveAlbum,
                )''',
    1,
)
ms = ms.replace(
    '''                    onToggleSelect = vm::toggleSelection,
                    onHideSelected = {
                        hide(vm.selectedVisibleItems(), MediaRepository.DEFAULT_HIDDEN_FOLDER)
                    },''',
    '''                    onToggleSelect = vm::toggleSelection,
                    onMoveSelected = { moveFiles(vm.selectedVisibleItems()) },
                    onHideSelected = {
                        hide(vm.selectedVisibleItems(), MediaRepository.DEFAULT_HIDDEN_FOLDER)
                    },''',
    1,
)
mp.write_text(ms)

wp = Path("app/src/main/java/com/osmus/gallery/ui/ViewerScreen.kt")
ws = wp.read_text()
if "import androidx.activity.compose.BackHandler\n" not in ws:
    ws = ws.replace("import android.os.Build\n", "import android.os.Build\nimport androidx.activity.compose.BackHandler\n", 1)

ws = ws.replace(
    '''    var chromeVisible by remember { mutableStateOf(true) }
    var detailsVisible by remember { mutableStateOf(false) }

    val current = items.getOrNull(pagerState.currentPage) ?: items.first()''',
    '''    var chromeVisible by remember { mutableStateOf(true) }
    var detailsVisible by remember { mutableStateOf(false) }
    var activeVideoPlaying by remember { mutableStateOf(false) }
    var pauseVideoRequest by remember { mutableLongStateOf(0L) }

    val current = items.getOrNull(pagerState.currentPage) ?: items.first()

    LaunchedEffect(current.id) {
        if (!current.isVideo) activeVideoPlaying = false
    }

    BackHandler(enabled = current.isVideo && activeVideoPlaying) {
        pauseVideoRequest++
    }''',
    1,
)

ws = ws.replace(
    '''                onNext = ::next,
                onTap = { chromeVisible = !chromeVisible },
            )''',
    '''                onNext = ::next,
                onTap = { chromeVisible = !chromeVisible },
                pauseRequest = pauseVideoRequest,
                onVideoPlayingChanged = { isPlaying ->
                    if (pagerState.currentPage == page) activeVideoPlaying = isPlaying
                },
            )''',
    1,
)

ws = ws.replace(
    '''    onNext: () -> Unit,
    onTap: () -> Unit,
) {
    when {''',
    '''    onNext: () -> Unit,
    onTap: () -> Unit,
    pauseRequest: Long,
    onVideoPlayingChanged: (Boolean) -> Unit,
) {
    when {''',
    1,
)
ws = ws.replace(
    '''            onNext = onNext,
            onTap = onTap,
        )''',
    '''            onNext = onNext,
            onTap = onTap,
            pauseRequest = pauseRequest,
            onPlayingChanged = onVideoPlayingChanged,
        )''',
    1,
)

ws = ws.replace(
    '''    onNext: () -> Unit,
    onTap: () -> Unit,
) {
    val context = LocalContext.current''',
    '''    onNext: () -> Unit,
    onTap: () -> Unit,
    pauseRequest: Long,
    onPlayingChanged: (Boolean) -> Unit,
) {
    val context = LocalContext.current''',
    1,
)
ws = ws.replace(
    '''            repeatMode = if (item.name.startsWith("OsmusLoop_", ignoreCase = true)) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
            prepare()''',
    '''            repeatMode = Player.REPEAT_MODE_ONE
            prepare()''',
    1,
)
ws = ws.replace(
    '''    LaunchedEffect(isActive, player) {
        if (!isActive) player.pause()
        while (isActive) {
            playing = player.isPlaying
            position = player.currentPosition.coerceAtLeast(0L)''',
    '''    LaunchedEffect(isActive, player) {
        if (isActive) player.play() else player.pause()
        while (isActive) {
            playing = player.isPlaying
            onPlayingChanged(playing)
            position = player.currentPosition.coerceAtLeast(0L)''',
    1,
)
ws = ws.replace(
    '''    DisposableEffect(player) {
        onDispose { player.release() }
    }''',
    '''    LaunchedEffect(pauseRequest) {
        if (pauseRequest > 0L && isActive) {
            player.pause()
            playing = false
            onPlayingChanged(false)
        }
    }

    DisposableEffect(player) {
        onDispose {
            onPlayingChanged(false)
            player.release()
        }
    }''',
    1,
)
wp.write_text(ws)

g = Path("app/build.gradle.kts")
t = g.read_text()
t = re.sub(r'versionCode\s*=\s*\d+', 'versionCode = 12', t)
t = re.sub(r'versionName\s*=\s*"[^"]+"', 'versionName = "0.10.8"', t)
g.write_text(t)
PY


# retrigger fixed v0.10.8
