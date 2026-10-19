import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/screen_utils.dart';
import '../data/models/registration.dart';
import 'app_widgets.dart';
import 'image_picker_field.dart';
import '../providers/request_provider.dart';

/// Numbered card that groups one step of a form.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final int step;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 13.r,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      '$step',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                SizedBox(height: 4.h),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12.5.sp, color: AppColors.neutral),
                ),
              ],
              SizedBox(height: 14.h),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient banner at the top of a form.
class FormHeader extends StatelessWidget {
  const FormHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF134E4A)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.sp,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice in a row of big tappable options (meal, day, ...).
class OptionTile<T> extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final T value;
  final T groupValue;
  final String label;
  final IconData icon;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final on = value == groupValue;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onSelected(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: on ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: on ? AppColors.primary : const Color(0xFFCBD5E1),
              width: on ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: on ? AppColors.primary : AppColors.neutral,
                size: 22.sp,
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: on ? AppColors.primary : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shelter photo, or a generated cover when no photo exists.
class ShelterCover extends StatelessWidget {
  const ShelterCover({super.key, required this.shelter, this.height = 110});

  final Registration shelter;
  final double height;

  /// Shown when a shelter has no photo of its own (network, gradient while
  /// loading or offline).
  static const _stockPhotos = [
    'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?auto=format&fit=crop&w=900&q=70',
    'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=900&q=70',
    'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=900&q=70',
    'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=900&q=70',
    'https://images.unsplash.com/photo-1582213782179-e0d53f98f2ca?auto=format&fit=crop&w=900&q=70',
  ];

  static const _palettes = [
    [Color(0xFF0F766E), Color(0xFF134E4A)],
    [Color(0xFF0E7490), Color(0xFF164E63)],
    [Color(0xFFB45309), Color(0xFF78350F)],
    [Color(0xFF4D7C0F), Color(0xFF365314)],
    [Color(0xFF6D28D9), Color(0xFF4C1D95)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[shelter.id.hashCode.abs() % _palettes.length];
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -14,
            child: Icon(
              Icons.home_work_rounded,
              size: height * 1.1,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Center(
            child: Icon(
              Icons.home_rounded,
              size: height * 0.42,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
    final own = shelter.imageUrl;
    final url = (own == null || own.isEmpty)
        ? _stockPhotos[shelter.id.hashCode.abs() % _stockPhotos.length]
        : own;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          fallback,
          Image(
            image: appImageProvider(url),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
              opacity: sync || frame != null ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: child,
            ),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Pick-a-shelter field. Shows the chosen shelter in one compact row; tapping
/// opens a searchable sheet (search, "free beds" and city filters) so people
/// can explore many shelters without a long list of cards. Use inside a
/// [FormField] via [ShelterPickerField].
class ShelterPicker extends StatelessWidget {
  const ShelterPicker({
    super.key,
    required this.shelters,
    required this.selectedId,
    required this.onChanged,
    this.requireBeds = false,
  });

  final List<Registration> shelters;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  /// Full shelters are shown but cannot be chosen (bed requests).
  final bool requireBeds;

  Future<void> _open(BuildContext context) async {
    final requests = context.read<RequestProvider>();
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _ShelterSheet(
        shelters: shelters,
        selectedId: selectedId,
        requireBeds: requireBeds,
        enrolledAt: requests.enrolledAt,
      ),
    );
    if (id != null) onChanged(id);
  }

  @override
  Widget build(BuildContext context) {
    if (shelters.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.home_work_outlined, color: AppColors.neutral),
            SizedBox(width: 10.w),
            const Expanded(
              child: Text(
                'No approved shelters yet. Please check back soon.',
                style: TextStyle(color: AppColors.neutral),
              ),
            ),
          ],
        ),
      );
    }
    Registration? sel;
    for (final s in shelters) {
      if (s.id == selectedId) sel = s;
    }
    final enrolled = sel == null
        ? 0
        : context.watch<RequestProvider>().enrolledAt(sel.id);
    final open = shelters.where((s) => s.availableBeds > 0).length;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(context),
        child: Ink(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sel != null ? AppColors.primary : const Color(0xFFCBD5E1),
              width: sel != null ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              if (sel != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 60.r,
                    height: 60.r,
                    child: ShelterCover(shelter: sel, height: 60.r),
                  ),
                )
              else
                Container(
                  width: 60.r,
                  height: 60.r,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 26.sp,
                  ),
                ),
              SizedBox(width: 12.w),
              Expanded(
                child: sel == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose a shelter',
                            style: TextStyle(
                              fontSize: 15.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${shelters.length} shelters · $open with free beds',
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: AppColors.neutral,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sel.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${sel.city} · ${sel.address}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: AppColors.neutral,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Wrap(
                            spacing: 6.w,
                            children: [
                              _bedsPill(sel),
                              _Pill(
                                Icons.groups_rounded,
                                '$enrolled enrolled',
                                AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              SizedBox(width: 8.w),
              Text(
                sel == null ? 'Browse' : 'Change',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _bedsPill(Registration s) {
  final beds = s.availableBeds;
  final color = beds == 0
      ? AppColors.rejected
      : (s.totalBeds > 0 && beds / s.totalBeds < 0.25
            ? AppColors.pending
            : AppColors.approved);
  return _Pill(Icons.bed_rounded, beds == 0 ? 'Full' : '$beds free', color);
}

class _ShelterSheet extends StatefulWidget {
  const _ShelterSheet({
    required this.shelters,
    required this.selectedId,
    required this.requireBeds,
    required this.enrolledAt,
  });

  final List<Registration> shelters;
  final String? selectedId;
  final bool requireBeds;
  final int Function(String shelterId) enrolledAt;

  @override
  State<_ShelterSheet> createState() => _ShelterSheetState();
}

class _ShelterSheetState extends State<_ShelterSheet> {
  final _search = TextEditingController();
  bool _freeOnly = false;
  String? _city;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cities = {for (final s in widget.shelters) s.city}.toList()..sort();
    final q = _search.text.trim().toLowerCase();
    final list = widget.shelters.where((s) {
      if (_freeOnly && s.availableBeds < 1) return false;
      if (_city != null && s.city != _city) return false;
      if (q.isEmpty) return true;
      return '${s.displayName} ${s.city} ${s.address}'.toLowerCase().contains(
        q,
      );
    }).toList()..sort((a, b) => b.availableBeds.compareTo(a.availableBeds));

    Widget chip(String label, bool on, VoidCallback tap, {IconData? icon}) =>
        Padding(
          padding: EdgeInsets.only(right: 8.w),
          child: ChoiceChip(
            avatar: icon == null ? null : Icon(icon, size: 16.sp),
            label: Text(label),
            selected: on,
            onSelected: (_) => tap(),
          ),
        );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              'Choose a shelter',
              style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w900),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name, city or area',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
                isDense: true,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                chip(
                  'Free beds',
                  _freeOnly,
                  () => setState(() => _freeOnly = !_freeOnly),
                  icon: Icons.bed_rounded,
                ),
                chip('All cities', _city == null, () {
                  setState(() => _city = null);
                }),
                for (final c in cities)
                  chip(c, _city == c, () => setState(() => _city = c)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
            child: Text(
              '${list.length} shelter${list.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral,
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'No shelters match your search.',
                      style: TextStyle(color: AppColors.neutral),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 20.h),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10.h),
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return _ShelterRow(
                        shelter: s,
                        enrolled: widget.enrolledAt(s.id),
                        selected: s.id == widget.selectedId,
                        disabled: widget.requireBeds && s.availableBeds < 1,
                        onTap: () => Navigator.pop(context, s.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShelterRow extends StatelessWidget {
  const _ShelterRow({
    required this.shelter,
    required this.enrolled,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final Registration shelter;
  final int enrolled;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = shelter;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onTap,
        child: Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68.r,
                  height: 68.r,
                  child: ShelterCover(shelter: s, height: 68.r),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${s.city} · ${s.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.neutral,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 6.w,
                      children: [
                        _bedsPill(s),
                        _Pill(
                          Icons.groups_rounded,
                          '$enrolled enrolled',
                          AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 5.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// [ShelterPicker] wired into a [Form] so "choose a shelter" validates.
class ShelterPickerField extends FormField<String> {
  ShelterPickerField({
    super.key,
    required List<Registration> shelters,
    required String? value,
    required ValueChanged<String> onChanged,
    bool requireBeds = false,
  }) : super(
         initialValue: value,
         validator: (v) => v == null ? 'Please choose a shelter' : null,
         builder: (state) {
           // Keep the form field in sync with the parent's selection.
           if (state.value != value) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (state.mounted) state.didChange(value);
             });
           }
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               ShelterPicker(
                 shelters: shelters,
                 selectedId: value,
                 requireBeds: requireBeds,
                 onChanged: (id) {
                   state.didChange(id);
                   onChanged(id);
                 },
               ),
               if (state.hasError)
                 Padding(
                   padding: EdgeInsets.only(left: 4.w),
                   child: Text(
                     state.errorText!,
                     style: TextStyle(
                       color: AppColors.rejected,
                       fontSize: 12.5.sp,
                     ),
                   ),
                 ),
             ],
           );
         },
       );
}

/// Sticky bottom bar: live summary of the choice + the submit button.
class SubmitBar extends StatelessWidget {
  const SubmitBar({
    super.key,
    required this.summary,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String summary;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ScreenUtils.maxContentWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral,
                ),
              ),
              SizedBox(height: 8.h),
              AppButton(
                label: label,
                icon: Icons.send_rounded,
                loading: loading,
                onPressed: onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of the next [days] days; pick one by tapping.
/// [offset] 0 = today.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.offset,
    required this.onChanged,
    this.days = 7,
  });

  final int offset;
  final ValueChanged<int> onChanged;
  final int days;

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: 84.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days,
        separatorBuilder: (_, _) => SizedBox(width: 10.w),
        itemBuilder: (_, i) {
          final d = now.add(Duration(days: i));
          final on = i == offset;
          final fg = on ? Colors.white : const Color(0xFF334155);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 66.w,
              decoration: BoxDecoration(
                color: on ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: on ? AppColors.primary : const Color(0xFFCBD5E1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'Today' : (i == 1 ? 'Tmrw' : _wd[d.weekday - 1]),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white70 : AppColors.neutral,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  Text(
                    _mo[d.month - 1],
                    style: TextStyle(fontSize: 11.5.sp, color: fg),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
