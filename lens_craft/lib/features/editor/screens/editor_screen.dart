import 'dart:io';
import 'package:camera/camera.dart';
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:lens_craft/core/theme/app_theme.dart';
import 'package:lens_craft/core/services/pdf_service.dart';
import 'package:lens_craft/core/services/document_service.dart';
import 'package:lens_craft/models/scan_document.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

// 1. Define available filters
enum FilterType {
  original,
  blackAndWhite,
  grayscale,
  magic, // We'll use a high-contrast preset for this
}

// 2. Filter Logic Helper
class FilterUtils {
  static ColorFilterGenerator getFilter(FilterType type) {
    switch (type) {
      case FilterType.blackAndWhite:
        // Custom matrix for high contrast B&W (Binary-like)
        return ColorFilterGenerator(
          name: "B&W",
          filters: [
            [
              1.5, 1.5, 1.5, 0, -255,
              1.5, 1.5, 1.5, 0, -255,
              1.5, 1.5, 1.5, 0, -255,
              0, 0, 0, 1, 0,
            ]
          ],
        );
      case FilterType.grayscale:
        return PresetFilters.none; // Placeholder, PresetFilters doesn't have grayscale directly, using manual matrix below
      case FilterType.magic:
        // "Magic" enhances text visibility (lighten background, darken text)
        return PresetFilters.clarendon; // Placeholder for now
      case FilterType.original:
      default:
        return PresetFilters.none;
    }
  }

  static Widget applyFilter(Widget child, FilterType type) {
    if (type == FilterType.original) return child;
    
    if (type == FilterType.grayscale) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      );
    }

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(getFilter(type).matrix),
      child: child,
    );
  }
}

class EditorScreen extends ConsumerStatefulWidget {
  final List<XFile> images;

  const EditorScreen({super.key, required this.images});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  
  // Use XFile list but allow it to be modified (replaced by cropped versions)
  late List<XFile> _editableImages;
  
  // Store filter state per page
  late List<FilterType> _pageFilters;

  // PdfService logic integrated directly
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Create a mutable copy of the list
    _editableImages = List.from(widget.images);
    // Initialize all pages with 'original' filter
    _pageFilters = List.filled(widget.images.length, FilterType.original);
  }

  Future<void> _saveAndSharePdf() async {
    if (_isExporting) return;
    
    setState(() {
      _isExporting = true;
    });

    try {
      // Convert XFile to File
      final files = _editableImages.map((x) => File(x.path)).toList();
      
      // Generate PDF
      await PdfService.generatePdf(
        images: files, 
        filters: _pageFilters,
        fileName: 'Scan_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrentPage() async {
    if (_editableImages.length <= 1) {
      // Can't delete the last page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete the last page')),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Page'),
        content: const Text('Are you sure you want to delete this page?'),
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

    if (confirmed == true && mounted) {
      setState(() {
        _editableImages.removeAt(_currentPage);
        _pageFilters.removeAt(_currentPage);
        
        // Adjust current page if needed
        if (_currentPage >= _editableImages.length) {
          _currentPage = _editableImages.length - 1;
        }
        
        // Update PageController
        if (_editableImages.isNotEmpty) {
          _pageController.jumpToPage(_currentPage);
        }
      });

      // If no pages left, go back
      if (_editableImages.isEmpty) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _saveDocument() async {
    if (_editableImages.isEmpty) return;

    try {
      final docsDir = await DocumentService.getDocumentsDirectory();
      final now = DateTime.now();
      final docId = const Uuid().v4();
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(now);
      final docTitle = 'Scan_$timestamp';

      // Copy images to app documents directory
      final savedImagePaths = <String>[];
      for (int i = 0; i < _editableImages.length; i++) {
        final sourceFile = File(_editableImages[i].path);
        final fileName = '${docId}_page_$i.jpg';
        final destPath = path.join(docsDir, fileName);
        final destFile = await sourceFile.copy(destPath);
        savedImagePaths.add(destFile.path);
      }

      // Create thumbnail from first page
      final thumbnailPath = savedImagePaths.isNotEmpty 
          ? path.join(docsDir, '${docId}_thumb.jpg')
          : null;
      if (thumbnailPath != null && savedImagePaths.isNotEmpty) {
        final thumbSource = File(savedImagePaths[0]);
        await thumbSource.copy(thumbnailPath);
      }

      // Create document
      final document = ScanDocument(
        id: docId,
        title: docTitle,
        createdAt: now,
        updatedAt: now,
        pageCount: _editableImages.length,
        thumbnailPath: thumbnailPath,
        imagePaths: savedImagePaths,
        filterTypes: _pageFilters.map((f) => f.name).toList(),
      );

      await DocumentService.saveDocument(document);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document saved successfully!')),
        );
        Navigator.of(context).pop(true); // Return true to indicate save success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _cropCurrentImage() async {
    try {
      final currentImagePath = _editableImages[_currentPage].path;
      debugPrint('Starting crop for: $currentImagePath');
      
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: currentImagePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop',
            hidesNavigationBar: false,
            aspectRatioPickerButtonHidden: false,
          ),
        ],
      );

      if (croppedFile != null) {
        debugPrint('Crop successful: ${croppedFile.path}');
        setState(() {
          // Update the list with the new cropped image
          _editableImages[_currentPage] = XFile(croppedFile.path);
        });
      } else {
        debugPrint('Crop cancelled by user');
      }
    } catch (e) {
      debugPrint('Crop error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crop failed: $e')),
        );
      }
    }
  }

  void _applyFilterToCurrentPage(FilterType type) {
    setState(() {
      _pageFilters[_currentPage] = type;
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          height: 160,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Apply Filter",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: FilterType.values.map((filter) {
                    return GestureDetector(
                      onTap: () {
                        _applyFilterToCurrentPage(filter);
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _pageFilters[_currentPage] == filter
                                      ? AppTheme.primaryColor
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              // Small preview of the filter
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: FilterUtils.applyFilter(
                                  Image.file(
                                    File(_editableImages[_currentPage].path),
                                    fit: BoxFit.cover,
                                  ),
                                  filter,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              filter.name.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Dark background for editing
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_editableImages.isEmpty ? 0 : _currentPage + 1} / ${_editableImages.length}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Ask user if they want to save before leaving
            final shouldSave = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Save Document?'),
                content: const Text('Do you want to save this document before leaving?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Discard'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );

            if (shouldSave == true) {
              await _saveDocument();
            } else {
              if (mounted) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _saveDocument,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: _isExporting ? null : _saveAndSharePdf,
            child: _isExporting 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
                )
              : const Text(
                  'Save PDF',
                  style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold),
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _editableImages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                // Use a key to force rebuild if path changes (e.g. after crop)
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Hero(
                      tag: _editableImages[index].path,
                      child: FilterUtils.applyFilter(
                        Image.file(
                          File(_editableImages[index].path),
                          key: ValueKey(_editableImages[index].path), 
                          fit: BoxFit.contain,
                        ),
                        _pageFilters[index],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Editor Toolbar
          Container(
            height: 100,
            padding: const EdgeInsets.only(bottom: 20),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolIcon(Icons.crop, 'Crop', _cropCurrentImage),
                _buildToolIcon(Icons.filter_b_and_w, 'Filter', _showFilterBottomSheet),
                _buildToolIcon(Icons.rotate_right, 'Rotate', () {
                   // Rotate is usually handled by Cropper, but we can add simple rotation later if needed
                   // Or just reopen crop tool for rotation.
                   _cropCurrentImage(); // Re-use crop tool for rotation for MVP
                }),
                _buildToolIcon(Icons.delete_outline, 'Delete', _deleteCurrentPage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
