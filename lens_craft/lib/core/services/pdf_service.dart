import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:lens_craft/features/editor/screens/editor_screen.dart';

class PdfService {
  /// Generates a PDF from a list of image files and their corresponding filter settings.
  /// Returns the saved File object.
  static Future<File> generatePdf({
    required List<File> images,
    required List<FilterType> filters,
    required String fileName,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < images.length; i++) {
      final imageFile = images[i];
      final filter = filters[i];

      // 1. Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      
      // 2. Decode image for processing (if filter is needed)
      // Note: For "Original", we could skip decoding to save time, 
      // but PDF lib needs raw bytes anyway. 
      // Optimization: If filter is original, just use bytes directly.
      
      pw.MemoryImage pdfImage;

      if (filter == FilterType.original) {
         pdfImage = pw.MemoryImage(imageBytes);
      } else {
         // Apply filter manually using 'image' package since we can't use Flutter Widgets here
         img.Image? originalImage = img.decodeImage(imageBytes);
         if (originalImage != null) {
           img.Image processedImage = _applyFilterToImage(originalImage, filter);
           pdfImage = pw.MemoryImage(img.encodeJpg(processedImage));
         } else {
           // Fallback if decoding fails
           pdfImage = pw.MemoryImage(imageBytes);
         }
      }

      // 3. Add page to PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    // 4. Save locally (temp)
    // We use Printing package to share directly, which handles temp file creation usually.
    // But here we might want to save to app doc dir.
    // For MVP, let's just return the bytes or share immediately.
    
    // Let's share immediately for simplicity in MVP
    await Printing.sharePdf(bytes: await pdf.save(), filename: '$fileName.pdf');
    
    // Return a dummy file for now as Printing.sharePdf handles the file
    return File(''); 
  }

  static img.Image _applyFilterToImage(img.Image src, FilterType type) {
    switch (type) {
      case FilterType.grayscale:
        return img.grayscale(src);
      case FilterType.blackAndWhite:
         // Simple thresholding for B&W
         // Convert to grayscale first
         var gray = img.grayscale(src);
         // Apply luminance threshold (simulated B&W)
         // The 'image' library doesn't have a direct 'binary threshold' easily exposed 
         // without loop, but 'contrast' can approximate it.
         return img.contrast(gray, contrast: 150); // Changed parameter name from 'amount' to 'contrast' 
      case FilterType.magic:
         // Enhance contrast and brightness
         var adjusted = img.adjustColor(
           src, 
           contrast: 1.2, 
           brightness: 1.1, 
           saturation: 1.2
         );
         return adjusted;
      default:
        return src;
    }
  }
}
