import 'dart:io';
import 'package:flutter/material.dart';

class ImageUploadWidget extends StatelessWidget {
  final String label;
  final File? selectedImage;
  final VoidCallback onPickImage;
  final VoidCallback? onRemoveImage;
  final bool isLoading;
  final String? errorMessage;

  const ImageUploadWidget({
    super.key,
    required this.label,
    this.selectedImage,
    required this.onPickImage,
    this.onRemoveImage,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[700]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Image preview
              if (selectedImage != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: Image.file(
                    selectedImage!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, size: 48, color: Colors.grey),
                  ),
                ),
              // Action buttons
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : onPickImage,
                            icon: const Icon(Icons.upload),
                            label: const Text('Pick Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                          ),
                        ),
                        if (selectedImage != null && onRemoveImage != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : onRemoveImage,
                              icon: const Icon(Icons.delete),
                              label: const Text('Remove'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Uploading to Cloudinary...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Error message
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
