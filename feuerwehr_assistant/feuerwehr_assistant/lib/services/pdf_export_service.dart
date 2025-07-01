import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:latlong2/latlong.dart';

class PdfExportService {
  Future<Uint8List?> captureMapAsImage(GlobalKey mapKey) async {
    try {
      final RenderRepaintBoundary boundary =
          mapKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing image: $e');
      return null;
    }
  }

  pw.Document createMapPDF(
    Uint8List imageBytes,
    MapController mapController,
    bool isOfflineMode,
    bool showHydrants,
    int hydrantCount,
    int tacticalMarkerCount,
  ) {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    final camera = mapController.camera;
    final center = camera.center;
    final zoom = camera.zoom;
    final timestamp = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(timestamp),
              pw.SizedBox(height: 20),
              _buildMapImage(image),
              pw.SizedBox(height: 20),
              _buildMapInfo(
                center,
                zoom,
                isOfflineMode,
                showHydrants,
                hydrantCount,
                tacticalMarkerCount,
              ),
              if (showHydrants || tacticalMarkerCount > 0)
                _buildLegend(showHydrants, tacticalMarkerCount),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(DateTime timestamp) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Feuerwehr Lagekarte',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Erstellt am: ${timestamp.day}.${timestamp.month}.${timestamp.year} um ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} Uhr',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMapImage(pw.MemoryImage image) {
    return pw.Expanded(
      child: pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey),
        ),
        child: pw.Image(image, fit: pw.BoxFit.contain),
      ),
    );
  }

  pw.Widget _buildMapInfo(
    LatLng center,
    double zoom,
    bool isOfflineMode,
    bool showHydrants,
    int hydrantCount,
    int tacticalMarkerCount,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Karteninformationen:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Zentrum: ${center.latitude.toStringAsFixed(6)}, ${center.longitude.toStringAsFixed(6)}',
          ),
          pw.Text('Zoom-Level: ${zoom.toStringAsFixed(1)}'),
          pw.Text(
            'Modus: ${isOfflineMode ? "Offline (Deutschland)" : "Online"}',
          ),
          if (showHydrants) pw.Text('Hydranten: $hydrantCount angezeigt'),
          if (tacticalMarkerCount > 0)
            pw.Text('Taktische Marker: $tacticalMarkerCount'),
        ],
      ),
    );
  }

  pw.Widget _buildLegend(bool showHydrants, int tacticalMarkerCount) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Legende:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          if (showHydrants)
            pw.Row(
              children: [
                pw.Container(
                  width: 10,
                  height: 10,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.red,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 5),
                pw.Text('Hydranten'),
              ],
            ),
          if (tacticalMarkerCount > 0) ...[
            pw.SizedBox(height: 3),
            pw.Text('🚗 Fahrzeuge (blau)'),
            pw.SizedBox(height: 3),
            pw.Text('⚠️ Gefahrenstellen (rot)'),
          ],
        ],
      ),
    );
  }

  Future<void> showExportDialog(BuildContext context, pw.Document pdf) async {
    final action = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Karte exportieren'),
            content: const Text('Wie möchten Sie die Karte exportieren?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('cancel'),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('share'),
                child: const Text('Teilen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop('print'),
                child: const Text('Drucken'),
              ),
            ],
          ),
    );

    if (action == 'print') {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Feuerwehr_Lagekarte_${DateTime.now().millisecondsSinceEpoch}',
      );
    } else if (action == 'share') {
      final bytes = await pdf.save();
      final fileName =
          'Feuerwehr_Lagekarte_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await Share.shareXFiles([
        XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
      ], text: 'Feuerwehr Lagekarte');
    }
  }

  Future<void> captureAndPrintMap(GlobalKey mapKey) async {
    try {
      // Screenshot aufnehmen
      RenderRepaintBoundary boundary =
          mapKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // PDF erstellen
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pw.MemoryImage(pngBytes)));
          },
        ),
      );

      // Drucken/Teilen
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      rethrow;
    }
  }
}
