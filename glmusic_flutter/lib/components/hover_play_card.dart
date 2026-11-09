import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/theme_provider.dart';

class HoverPlayCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String imageUrl;
  final int? playCount;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const HoverPlayCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.playCount,
    required this.onTap,
    required this.onPlay,
  });

  @override
  State<HoverPlayCard> createState() => _HoverPlayCardState();
}

class _HoverPlayCardState extends State<HoverPlayCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Container with Hover Scale
            Expanded(
              child: AnimatedScale(
                scale: _isHovering ? 1.03 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Artwork
                      widget.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(color: Colors.white12),
                            )
                          : Container(color: Colors.white12),

                      // Play Count Badge
                      if (widget.playCount != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  _formatPlayCount(widget.playCount!),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Hover Floating Play Button (Apple Music style)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        right: 10,
                        bottom: _isHovering ? 10 : -40,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _isHovering ? 1.0 : 0.0,
                          child: GestureDetector(
                            onTap: widget.onPlay,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.primaryColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: theme.primaryColor.withValues(alpha: 0.4),
                                    blurRadius: 14,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Title
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _isHovering ? theme.primaryColor : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),

            // Optional Subtitle
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPlayCount(int count) {
    if (count > 100000000) {
      return '${(count / 100000000).toStringAsFixed(1)}亿';
    }
    if (count > 10000) {
      return '${(count / 10000).toStringAsFixed(0)}万';
    }
    return count.toString();
  }
}
