import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/screen_utils.dart';

/// One tile inside [AdminHeader]: a count over a label.
class HeaderTile {
  const HeaderTile(this.label, this.count, {this.color = Colors.white});

  final String label;
  final int count;
  final Color color;
}

/// Gradient header card for admin screens: icon, title, subtitle and an
/// optional row of count tiles that can act as filters.
class AdminHeader extends StatelessWidget {
  const AdminHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tiles = const [],
    this.selected,
    this.onSelected,
    this.margin,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<HeaderTile> tiles;

  /// Index of the highlighted tile; null = none highlighted.
  final int? selected;
  final ValueChanged<int>? onSelected;
  final EdgeInsets? margin;

  Widget _tileAt(int i) => _Tile(
    tile: tiles[i],
    selected: selected == i,
    onTap: onSelected == null ? null : () => onSelected!(i),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin ?? EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF134E4A)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tiles.isNotEmpty) ...[
            SizedBox(height: 14.h),
            if (tiles.length <= 4)
              Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) SizedBox(width: 8.w),
                    Expanded(child: _tileAt(i)),
                  ],
                ],
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++)
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: _tileAt(i),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.selected, this.onTap});

  final HeaderTile tile;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primary : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(minWidth: 76.w),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '${tile.count}',
              style: TextStyle(
                color: fg,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              tile.label,
              style: TextStyle(
                color: fg,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
