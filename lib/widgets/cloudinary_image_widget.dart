import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CloudinaryImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CloudinaryImageWidget({
    super.key,
    required this.imageUrl,
    required this.label,
    this.width = double.infinity,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // If no URL, show placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'No $label',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Display image from Cloudinary URL
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
            placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[800],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
              ),
            ),
      ),
    );
  }
}
