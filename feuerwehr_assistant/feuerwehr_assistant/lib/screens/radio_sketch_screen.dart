import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RadioSketchScreen extends StatefulWidget {
  const RadioSketchScreen({super.key});

  @override
  State<RadioSketchScreen> createState() => _RadioSketchScreenState();
}

class _RadioSketchScreenState extends State<RadioSketchScreen> {
  final List<TextEditingController> _abkuerzungControllers = List.generate(7, (_) => TextEditingController());
  final List<TextEditingController> _bezeichnungControllers = List.generate(7, (_) => TextEditingController());
  final List<TextEditingController> _kurzwehlControllers = List.generate(7, (_) => TextEditingController());

  final List<TextEditingController> _abschnittLeiterControllers = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _abschnittDmoControllers = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _abschnittTmoControllers = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _abschnittRufnameControllers = List.generate(4, (_) => TextEditingController());
  final List<List<TextEditingController>> _abschnittEinheitenControllers = List.generate(4, (_) => List.generate(7, (_) => TextEditingController()));

  static const _romanNumerals = ['I', 'II', 'III', 'IV'];

  @override
  void initState() {
    super.initState();
    _abkuerzungControllers[0].text = '307 F²';
    _bezeichnungControllers[0].text = 'Betrieb';
    _kurzwehlControllers[0].text = '307';
    _abkuerzungControllers[1].text = '310 F²';
    _bezeichnungControllers[1].text = 'Erlösung';
    _kurzwehlControllers[1].text = '310';
    _abkuerzungControllers[2].text = '311 F² bis 308 F²';
    _bezeichnungControllers[2].text = 'Einsatzabschnitt';
    _kurzwehlControllers[2].text = '311 bis 326';
    _abkuerzungControllers[3].text = 'PW_PAN';
    _bezeichnungControllers[3].text = 'PW UK Retail-Im';
    _kurzwehlControllers[3].text = '3182';
    _abkuerzungControllers[4].text = 'SoG_1_PA';
    _bezeichnungControllers[4].text = 'Sondergruppe I bis 10';
    _kurzwehlControllers[4].text = '3101 bis 3110';
    _abkuerzungControllers[5].text = 'KATS_PAN';
    _bezeichnungControllers[5].text = 'KAT-Schutz UK Retail-Im';
    _kurzwehlControllers[5].text = '3186';
    _abkuerzungControllers[6].text = 'ZA_PAN';
    _bezeichnungControllers[6].text = 'Zusammenarbeit nichtpol';
    _kurzwehlControllers[6].text = '3181';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FF Schwarzenbach a.d.Saale - Funkskizze'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _generatePdf,
            tooltip: 'Als PDF drucken',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('FF Schwarzenbach a.d.Saale', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('II. S PA - Führungsunterstützung / FU', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),

            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Table(
                  border: TableBorder.all(),
                  columnWidths: const {
                    0: FixedColumnWidth(150),
                    1: FixedColumnWidth(250),
                    2: FixedColumnWidth(150),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.grey),
                      children: [
                        Padding(padding: EdgeInsets.all(8.0), child: Text('Abkürzung', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(8.0), child: Text('Bezeichnung', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(8.0), child: Text('Kurzwahl', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    ...List.generate(7, (i) => TableRow(
                      children: [
                        _buildCell(_abkuerzungControllers[i]),
                        _buildCell(_bezeichnungControllers[i]),
                        _buildCell(_kurzwehlControllers[i]),
                      ],
                    )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            ...List.generate(2, (row) => Row(
              children: List.generate(2, (col) {
                final index = row * 2 + col;
                return Expanded(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildAbschnitt(index),
                ));
              }),
            )),
            const SizedBox(height: 24),

            Center(
              child: ElevatedButton.icon(
                onPressed: _generatePdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Als PDF drucken'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
      ),
    );
  }

  Widget _buildAbschnitt(int index) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Abschnitt ${_romanNumerals[index]}:', style: const TextStyle(fontWeight: FontWeight.bold)),
            _buildLabeledField('Leiter:', _abschnittLeiterControllers[index]),
            _buildLabeledField('DMO / Gruppe:', _abschnittDmoControllers[index]),
            _buildLabeledField('TMO / Gruppe:', _abschnittTmoControllers[index]),
            _buildLabeledField('Rufname:', _abschnittRufnameControllers[index]),
            const SizedBox(height: 8),
            const Text('Unterstellte Einheiten:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...List.generate(7, (i) => Row(
              children: [
                SizedBox(width: 24, child: Text('${i + 1}.')),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _abschnittEinheitenControllers[index][i], decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Center(child: pw.Text('FF Schwarzenbach a.d.Saale', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('II. S PA - Führungsunterstützung / FU', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 16),

          pw.Table.fromTextArray(
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: ['Abkürzung', 'Bezeichnung', 'Kurzwahl'],
            data: List.generate(7, (i) => [
              _abkuerzungControllers[i].text,
              _bezeichnungControllers[i].text,
              _kurzwehlControllers[i].text,
            ]),
          ),

          pw.SizedBox(height: 20),
          ...List.generate(4, (i) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 16),
            child: _buildPdfAbschnitt(i),
          )),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              'Änderungen und Erklärungen an info@feuerwehr-schwarzenbach.de\nErsteller: 07KS - Rotals.htm; Stand: 09/2022',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildPdfAbschnitt(int index) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Abschnitt ${_romanNumerals[index]}:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildPdfRow('Leiter:', _abschnittLeiterControllers[index].text),
          _buildPdfRow('DMO / Gruppe:', _abschnittDmoControllers[index].text),
          _buildPdfRow('TMO / Gruppe:', _abschnittTmoControllers[index].text),
          _buildPdfRow('Rufname:', _abschnittRufnameControllers[index].text),
          pw.SizedBox(height: 8),
          pw.Text('Unterstellte Einheiten:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...List.generate(7, (i) => pw.Row(
            children: [
              pw.SizedBox(width: 24, child: pw.Text('${i + 1}.')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Text(_abschnittEinheitenControllers[index][i].text)),
            ],
          )),
        ],
      ),
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}
