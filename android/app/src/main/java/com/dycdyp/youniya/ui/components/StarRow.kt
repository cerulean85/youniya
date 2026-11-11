package com.dycdyp.youniya.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.dycdyp.youniya.R
import com.dycdyp.youniya.data.Mood
import com.dycdyp.youniya.data.StarItem
import com.dycdyp.youniya.ui.design.cosmos
import com.dycdyp.youniya.ui.theme.Radius
import com.dycdyp.youniya.ui.theme.Space
import com.dycdyp.youniya.ui.theme.YColor
import com.dycdyp.youniya.ui.theme.YText
import com.dycdyp.youniya.ui.theme.sky

/**
 * Figma `Star Row`: Floated stars show a starlight badge, kept stars a label.
 * 78dp tall.
 */
@Composable
fun StarRow(star: StarItem, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(Radius.lg)
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 78.dp)
            .cosmos(star.id, shape)
            .background(YColor.bgSurface, shape)
            .border(1.dp, YColor.borderDefault, shape)
            .padding(Space.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Image(
            painter = painterResource(if (star.isFloated) R.drawable.star_shape_floated else R.drawable.star_shape_kept),
            contentDescription = null,
            modifier = Modifier.size(18.dp),
        )

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(Space.xs),
        ) {
            Text(
                text = star.title,
                style = YText.bodyM,
                color = YColor.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = star.dateText,
                style = YText.caption,
                color = YColor.textTertiary,
                maxLines = 1,
            )
        }

        if (star.isFloated) {
            StarlightBadge(value = star.starlight)
        } else {
            Text(
                text = "별빛 없는 별",
                style = YText.labelS,
                color = YColor.textSecondary,
            )
        }
    }
}

/**
 * Figma `Starlight Badge` (Standard tier). Shows "—" before analysis.
 */
@Composable
fun StarlightBadge(value: Int?, modifier: Modifier = Modifier) {
    val a = sky()
    Row(
        modifier
            .background(a.tintPrimary, CircleShape)
            .border(1.dp, a.brandPrimary, CircleShape)
            .padding(horizontal = Space.md, vertical = Space.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.xs),
    ) {
        Image(
            painter = painterResource(R.drawable.star_shape_badge),
            contentDescription = null,
            modifier = Modifier.size(14.dp),
        )
        Text(
            text = value?.toString() ?: "—",
            style = YText.labelM,
            color = YColor.textPrimary,
        )
        Text(
            text = "별빛",
            style = YText.caption,
            color = YColor.textSecondary,
        )
    }
}

/** Figma `Chip`: emotion tone tag. Selected chips take the tone's tint and border. */
@Composable
fun MoodTag(mood: Mood, isSelected: Boolean = true, modifier: Modifier = Modifier) {
    Row(
        modifier
            .background(if (isSelected) mood.tint else YColor.bgSurface, CircleShape)
            .border(1.dp, if (isSelected) mood.color else YColor.borderDefault, CircleShape)
            .padding(horizontal = Space.md, vertical = Space.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
    ) {
        Box(
            Modifier
                .size(8.dp)
                .background(mood.color, CircleShape)
        )
        Text(
            text = mood.label,
            style = YText.labelS,
            color = if (isSelected) YColor.textPrimary else YColor.textSecondary,
        )
    }
}

/** Tappable `MoodTag` for picking a mood. */
@Composable
fun MoodChip(mood: Mood, isSelected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .noRippleClick(onClick)
            .semantics {
                contentDescription = mood.label
                selected = isSelected
            }
    ) {
        MoodTag(mood = mood, isSelected = isSelected)
    }
}
