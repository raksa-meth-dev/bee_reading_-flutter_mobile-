import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/theme/app_theme.dart';

/// Displays the eBook import bottom sheet modal with device picker and cloud options.
void showImportBookModal(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.file_upload_outlined,
                      color: AppTheme.primaryDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Import eBook',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Supports EPUB, PDF, and MOBI files',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_open_rounded, color: AppTheme.textDark),
                ),
                title: const Text(
                  'Choose from Device',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                subtitle: const Text(
                  'Pick eBook files (.epub, .pdf, .mobi) from phone storage',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheetContext);
                  try {
                    final imported = await ref.read(booksProvider.notifier).pickAndImportBook();
                    if (imported != null && context.mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Imported "${imported.title}" into library!')),
                            ],
                          ),
                          backgroundColor: const Color(0xFF2E7D32),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Could not open file picker: $e\nPlease restart the app if newly updated.'),
                          backgroundColor: Colors.red.shade700,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_upload_outlined, color: AppTheme.textDark),
                ),
                title: const Text(
                  'Import from Cloud Drive',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                subtitle: const Text(
                  'Google Drive, iCloud, Dropbox',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connecting to Cloud Drive...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
