import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lens_craft/core/theme/app_theme.dart';
import 'package:lens_craft/core/services/document_service.dart';
import 'package:lens_craft/features/scan/screens/camera_screen.dart';
import 'package:lens_craft/models/scan_document.dart';
import 'package:lens_craft/features/editor/screens/editor_screen.dart';
import 'package:camera/camera.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LensCraft'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: DocumentService.box!.listenable(),
        builder: (context, Box<ScanDocument> box, _) {
          final documents = box.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first

          if (documents.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return _buildDocumentCard(context, doc);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CameraScreen()),
          );
          // Refresh if a document was saved
          if (result == true) {
            setState(() {});
          }
        },
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, ScanDocument doc) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(doc.thumbnailPath!),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(Icons.document_scanner_outlined, size: 40),
        title: Text(
          doc.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'} • ${dateFormat.format(doc.createdAt)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _showDeleteDialog(context, doc),
        ),
        onTap: () {
          // Open document in editor
          final imageFiles = doc.imagePaths
              .where((path) => File(path).existsSync())
              .map((path) => XFile(path))
              .toList();
          
          if (imageFiles.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditorScreen(images: imageFiles),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, ScanDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${doc.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DocumentService.deleteDocument(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No scans yet',
            style: AppTheme.textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to start scanning',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
