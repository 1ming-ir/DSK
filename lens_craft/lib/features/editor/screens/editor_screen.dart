import 'dart:io';
import 'package:camera/camera.dart';
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lens_craft/core/theme/app_theme.dart';
import 'package:lens_craft/core/services/pdf_service.dart';

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
  
  // Store filter state per page
  late List<FilterType> _pageFilters;

  // PdfService logic integrated directly
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
      final files = widget.images.map((x) => File(x.path)).toList();
      
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
                                    File(widget.images[_currentPage].path),
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
          '${_currentPage + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
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
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Hero(
                      tag: widget.images[index].path,
                      child: FilterUtils.applyFilter(
                        Image.file(
                          File(widget.images[index].path),
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
                _buildToolIcon(Icons.crop, 'Crop', () {}),
                _buildToolIcon(Icons.filter_b_and_w, 'Filter', _showFilterBottomSheet),
                _buildToolIcon(Icons.rotate_right, 'Rotate', () {}),
                _buildToolIcon(Icons.delete_outline, 'Delete', () {}),
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
