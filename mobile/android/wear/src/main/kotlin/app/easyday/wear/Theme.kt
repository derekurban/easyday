package app.easyday.wear

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.MaterialTheme

/// The phone app's dark theme on the wrist (lib/ui/theme.dart): true black, near-black fills, ink for everything, and
/// the sun on the one button. Heavy Albert Sans for titles and numbers, Wix Madefor Text for the rest.
object Ink {
    val bg = Color(0xFF000000)
    val sunk = Color(0xFF1E1D20)
    val ahead = Color(0xFF3B393E)
    val ink = Color(0xFFFFFFFF)
    val ink2 = Color(0xFFA09CA3)
    val ink3 = Color(0xFF8C8890)
    val sun = Color(0xFFFDB582)    // the middle of the sun's gradient
    val onSun = Color(0xFF3A1A0C)
    val art = Color(0xFFF29450)    // the heart
    val warning = Color(0xFFC38B46)
}

object Fonts {
    val albert = FontFamily(Font(R.font.albert_sans_bold, FontWeight.Bold))
    val wix = FontFamily(Font(R.font.wix_regular, FontWeight.Normal), Font(R.font.wix_semibold, FontWeight.SemiBold))
}

object Type {
    val title = TextStyle(fontFamily = Fonts.albert, fontWeight = FontWeight.Bold, fontSize = 17.sp, lineHeight = 20.sp)
    val liftTitle = TextStyle(fontFamily = Fonts.albert, fontWeight = FontWeight.Bold, fontSize = 15.sp, lineHeight = 17.sp)
    val dial = TextStyle(fontFamily = Fonts.albert, fontWeight = FontWeight.Bold, fontSize = 40.sp, lineHeight = 42.sp, textAlign = TextAlign.Center)
    val dialSide = TextStyle(fontFamily = Fonts.albert, fontWeight = FontWeight.Bold, fontSize = 18.sp, lineHeight = 20.sp, textAlign = TextAlign.Center)
    val number = TextStyle(fontFamily = Fonts.albert, fontWeight = FontWeight.Bold, fontSize = 22.sp, lineHeight = 24.sp)
    val body = TextStyle(fontFamily = Fonts.wix, fontSize = 15.sp, lineHeight = 19.sp)
    val label = TextStyle(fontFamily = Fonts.wix, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, lineHeight = 17.sp)
    val button = TextStyle(fontFamily = Fonts.wix, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, lineHeight = 16.sp)
    val buttonLong = TextStyle(fontFamily = Fonts.wix, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, lineHeight = 14.sp)
    val small = TextStyle(fontFamily = Fonts.wix, fontSize = 12.sp, lineHeight = 15.sp)
}

@Composable
fun EasydayTheme(content: @Composable () -> Unit) = MaterialTheme(content = content)
