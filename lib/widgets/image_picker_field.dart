import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/screen_utils.dart';

/// Picked photos are stored inline as `data:image/jpeg;base64,...` so they
/// persist with the record; older records may still hold a web link.
ImageProvider appImageProvider(String url) {
  if (url.startsWith('data:')) {
    return MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1)));
  }
  return NetworkImage(url);
}

/// Photo shown from [url] (picked photo or link); [fallback] on any failure.
Widget appImage(String url, {required Widget fallback, BoxFit? fit}) {
  try {
    return Image(
      image: appImageProvider(url),
      fit: fit ?? BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  } catch (_) {
    return fallback;
  }
}

/// Choose a photo from the gallery. The value (empty = none) lives in
/// [controller] so forms can read it like any other field.
class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    super.key,
    required this.controller,
    this.label = 'Photo',
    this.round = false,
  });

  final TextEditingController controller;
  final String label;
  final bool round;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      widget.controller.text = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the gallery. Check photo access.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, v, _) {
        final has = v.text.trim().isNotEmpty;
        final size = 84.r;
        final placeholder = Container(
          color: AppColors.primary.withValues(alpha: 0.08),
          child: const Icon(
            Icons.add_a_photo_outlined,
            color: AppColors.primary,
          ),
        );
        final preview = SizedBox(
          width: size,
          height: size,
          child: has
              ? appImage(v.text.trim(), fallback: placeholder)
              : placeholder,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Row(
            children: [
              GestureDetector(
                onTap: _busy ? null : _pick,
                child: widget.round
                    ? ClipOval(child: preview)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: preview,
                      ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pick,
                          icon: _busy
                              ? SizedBox(
                                  width: 16.r,
                                  height: 16.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_library_rounded),
                          label: Text(has ? 'Change' : 'Choose from gallery'),
                        ),
                        if (has)
                          TextButton(
                            onPressed: () => widget.controller.clear(),
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
