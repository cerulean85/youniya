package com.dycdyp.youniya.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText

/**
 * Figma `Bottom Sheet` (Actions=3) content (iOS ActionSheetContent):
 * title, message, and up to three action buttons.
 */
@Composable
fun ActionSheetContent(
    title: String,
    message: String,
    primaryText: String,
    onPrimary: () -> Unit,
    secondaryText: String,
    onSecondary: () -> Unit,
    ghostText: String? = null,
    onGhost: (() -> Unit)? = null,
    destructive: Boolean = false,
    secondaryIsGhost: Boolean = false,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = Space.xl, end = Space.xl, top = Space.md, bottom = Space.xl),
        verticalArrangement = Arrangement.spacedBy(Space.lg),
    ) {
        SheetGrabber()

        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Text(title, style = YText.h3, color = YColor.textPrimary)
            Text(message, style = YText.bodyM, color = YColor.textSecondary)
        }

        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            if (destructive) {
                DangerButton(text = primaryText, onClick = onPrimary)
            } else {
                PrimaryButton(text = primaryText, onClick = onPrimary)
            }

            if (secondaryIsGhost) {
                GhostButton(text = secondaryText, onClick = onSecondary)
            } else {
                SecondaryButton(text = secondaryText, onClick = onSecondary)
            }

            if (ghostText != null && onGhost != null) {
                GhostButton(text = ghostText, onClick = onGhost)
            }
        }
    }
}
